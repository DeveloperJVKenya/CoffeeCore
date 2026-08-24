import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../../services/ai_error_helper.dart';
import '../pests/coffee_pest_management_page.dart' show kPestDetails;
import '../diseases/coffee_disease_management_page.dart' show kDiseaseDetails;
import 'nutrient_deficiency_details.dart' show kNutrientDeficiencyDetails;

// ─────────────────────────────────────────────────────────────────────────────
// SYMPTOM CHECKER AI SERVICE
//
// Retrieval-Augmented Generation for the Symptom Checker:
//   • Retrieval — kPestDetails/kDiseaseDetails entries are ranked locally by
//     keyword overlap against the farmer's selected symptoms (classification
//     step) or handed in already-ranked by the caller's own cluster-weighted
//     scoring (specific-match step). No vector DB needed — the existing
//     static catalogs ARE the corpus, and simple local scoring IS the
//     retriever.
//   • Augmentation — only the top few ranked candidates' text is injected
//     into the prompt (not the whole catalog), keeping requests small.
//   • Generation — Gemini is instructed to choose only among the given
//     candidates (closed-book) and return structured JSON with a confidence
//     score and short reasoning, so answers stay grounded and farmer-facing
//     text stays honest about uncertainty.
//
// Capped at 2 calls per full checker session (one classification + one
// specific-match), both connectivity-gated and in-memory cached by symptom
// signature — see GeminiSoilAiService for the same caching convention.
// ─────────────────────────────────────────────────────────────────────────────

/// Result of the pest/disease/nutrient-deficiency classification step.
class PestOrDiseaseClassification {
  final String
      category; // 'pest' | 'disease' | 'nutrient_deficiency' | 'uncertain'
  final int confidence; // 0-100
  final String reasoning;

  const PestOrDiseaseClassification({
    required this.category,
    required this.confidence,
    required this.reasoning,
  });

  factory PestOrDiseaseClassification.fromJson(Map<String, dynamic> json) =>
      PestOrDiseaseClassification(
        category: (json['category'] as String? ?? 'uncertain').toLowerCase(),
        confidence: (json['confidence'] as num?)?.toInt() ?? 0,
        reasoning: json['reasoning'] as String? ?? '',
      );
}

/// Result of the specific pest/disease identification step.
class SpecificMatchResult {
  final String bestMatch;
  final int confidence;
  final String reasoning;
  final String? runnerUp;

  const SpecificMatchResult({
    required this.bestMatch,
    required this.confidence,
    required this.reasoning,
    this.runnerUp,
  });

  factory SpecificMatchResult.fromJson(Map<String, dynamic> json) =>
      SpecificMatchResult(
        bestMatch: json['best_match'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toInt() ?? 0,
        reasoning: json['reasoning'] as String? ?? '',
        runnerUp: (json['runner_up'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['runner_up'] as String?,
      );
}

/// A single retrieved catalog entry used to ground a prompt.
class SymptomCandidate {
  final String name;
  final String description;
  final String symptoms;

  const SymptomCandidate({
    required this.name,
    required this.description,
    required this.symptoms,
  });
}

class SymptomCheckerAiService {
  SymptomCheckerAiService._();

  static const String _model = 'gemini-2.5-flash';

  /// Non-technical message describing the most recent AI call failure —
  /// mirrors GeminiSoilAiService/GeminiPestAiService/GeminiDiseaseAiService.
  static String? lastErrorMessage;

  static final Map<String, PestOrDiseaseClassification> _classificationCache =
      {};
  static final Map<String, SpecificMatchResult> _matchCache = {};

  // ══════════════════════════════════════════════════════════════════════════
  // CONNECTIVITY GATE — same convention as coffee_soil_summary_page.dart
  // ══════════════════════════════════════════════════════════════════════════

  static Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('[SymptomCheckerAI] ⚠️ Connectivity check failed: $e');
      return false;
    }
  }

  static String _signature(Iterable<String> parts) =>
      (parts.map((p) => p.toLowerCase().trim()).toList()..sort()).join('|');

  // ══════════════════════════════════════════════════════════════════════════
  // LOCAL RETRIEVAL — keyword overlap over kPestDetails / kDiseaseDetails.
  // Used only to build RAG grounding context; does not replace the existing
  // cluster-weighted scoring in the analysis pages.
  // ══════════════════════════════════════════════════════════════════════════

  static List<SymptomCandidate> rankPestCandidates(
    List<String> selectedSymptoms, {
    int topK = 3,
  }) =>
      _rank(selectedSymptoms, kPestDetails, topK);

  static List<SymptomCandidate> rankDiseaseCandidates(
    List<String> selectedSymptoms, {
    int topK = 3,
  }) =>
      _rank(selectedSymptoms, kDiseaseDetails, topK);

  /// Deliberately no equivalent `identifySpecificMatch` caller for nutrients
  /// — see the module doc comment in nutrient_deficiency_details.dart. Two
  /// deficiencies can look nearly identical from visual symptoms alone, so
  /// the result page shows the top-ranked candidates rather than forcing a
  /// single best match the way pests/diseases do.
  static List<SymptomCandidate> rankNutrientCandidates(
    List<String> selectedSymptoms, {
    int topK = 2,
  }) =>
      _rank(selectedSymptoms, kNutrientDeficiencyDetails, topK);

  static List<SymptomCandidate> _rank(
    List<String> selectedSymptoms,
    Map<String, Map<String, dynamic>> catalog,
    int topK,
  ) {
    final queryWords = selectedSymptoms
        .join(' ')
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.length > 3)
        .toSet();
    if (queryWords.isEmpty) return const [];

    final scored = <MapEntry<String, int>>[];
    catalog.forEach((name, details) {
      final text =
          '${details['description'] ?? ''} ${details['symptoms'] ?? ''}'
              .toLowerCase();
      final overlap = queryWords.where((w) => text.contains(w)).length;
      if (overlap > 0) scored.add(MapEntry(name, overlap));
    });
    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(topK).map((e) {
      final d = catalog[e.key]!;
      return SymptomCandidate(
        name: e.key,
        description: d['description'] as String? ?? '',
        symptoms: d['symptoms'] as String? ?? '',
      );
    }).toList();
  }

  /// Converts already locally-scored candidate names (from the analysis
  /// pages' own cluster-weighted algorithm) into grounding context.
  static List<SymptomCandidate> candidatesFromNames(
    List<String> names, {
    required bool isPest,
  }) {
    final catalog = isPest ? kPestDetails : kDiseaseDetails;
    return names
        .where((n) => catalog.containsKey(n))
        .map((n) => SymptomCandidate(
              name: n,
              description: catalog[n]!['description'] as String? ?? '',
              symptoms: catalog[n]!['symptoms'] as String? ?? '',
            ))
        .toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ① PEST-VS-DISEASE CLASSIFICATION — the sequential "first distinguishment"
  // ══════════════════════════════════════════════════════════════════════════

  static Future<PestOrDiseaseClassification?> classifyPestOrDisease({
    required List<String> selectedSymptoms,
  }) async {
    if (selectedSymptoms.isEmpty) return null;

    final pestCandidates = rankPestCandidates(selectedSymptoms);
    final diseaseCandidates = rankDiseaseCandidates(selectedSymptoms);
    final nutrientCandidates = rankNutrientCandidates(selectedSymptoms);
    if (pestCandidates.isEmpty &&
        diseaseCandidates.isEmpty &&
        nutrientCandidates.isEmpty) {
      debugPrint('[SymptomCheckerAI] ⚠️ No local candidates to ground '
          'classification — skipping AI call.');
      return null;
    }

    final sig = _signature(selectedSymptoms);
    if (_classificationCache.containsKey(sig)) {
      debugPrint('[SymptomCheckerAI] ✅ Cache hit — classification');
      return _classificationCache[sig];
    }

    if (!await _isOnline()) {
      debugPrint(
          '[SymptomCheckerAI] 📴 Offline — skipping classification call.');
      return null;
    }

    debugPrint('[SymptomCheckerAI] 🤖 Calling Gemini — symptom '
        'classification (${selectedSymptoms.length} symptoms, '
        '${pestCandidates.length} pest / ${diseaseCandidates.length} '
        'disease / ${nutrientCandidates.length} nutrient candidates '
        'retrieved)');

    lastErrorMessage = null;
    try {
      final model = FirebaseAI.vertexAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 800,
        ),
      );

      final response = await model.generateContent([
        Content.text(_buildClassificationPrompt(selectedSymptoms,
            pestCandidates, diseaseCandidates, nutrientCandidates)),
      ]);
      final rawText = response.text ?? '';
      if (rawText.isEmpty) {
        debugPrint('[SymptomCheckerAI] ❌ Empty classification response.');
        return null;
      }

      final parsed =
          _parseJsonResponse(rawText, context: 'classifyPestOrDisease');
      if (parsed == null) return null;

      final result = PestOrDiseaseClassification.fromJson(parsed);
      _classificationCache[sig] = result;
      debugPrint('[SymptomCheckerAI] ✅ Classification: ${result.category} '
          '(${result.confidence}%) — ${result.reasoning}');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('[SymptomCheckerAI] ❌ Firebase error in '
          'classifyPestOrDisease: code=${e.code} message="${e.message}"');
      lastErrorMessage = humanizeAiError(e);
      return null;
    } catch (e, stack) {
      debugPrint('[SymptomCheckerAI] ❌ Unexpected error in '
          'classifyPestOrDisease: $e');
      debugPrint('[SymptomCheckerAI]    Stack: $stack');
      lastErrorMessage = humanizeAiError(e);
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ② SPECIFIC PEST/DISEASE IDENTIFICATION — grounded on locally-ranked
  //    candidates from the caller's own cluster-weighted scoring.
  // ══════════════════════════════════════════════════════════════════════════

  static Future<SpecificMatchResult?> identifySpecificMatch({
    required bool isPest,
    required List<String> selectedSymptoms,
    required List<SymptomCandidate> candidates,
  }) async {
    // Nothing to disambiguate — skip the call entirely (frequency control).
    if (candidates.length < 2) return null;

    final sig = '${isPest ? 'pest' : 'disease'}_'
        '${_signature([
          ...selectedSymptoms,
          ...candidates.map((c) => c.name)
        ])}';
    if (_matchCache.containsKey(sig)) {
      debugPrint('[SymptomCheckerAI] ✅ Cache hit — specific match');
      return _matchCache[sig];
    }

    if (!await _isOnline()) {
      debugPrint(
          '[SymptomCheckerAI] 📴 Offline — skipping specific-match call.');
      return null;
    }

    debugPrint('[SymptomCheckerAI] 🤖 Calling Gemini — specific '
        '${isPest ? "pest" : "disease"} match (${candidates.length} '
        'candidates: ${candidates.map((c) => c.name).join(", ")})');

    lastErrorMessage = null;
    try {
      final model = FirebaseAI.vertexAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 1024,
        ),
      );

      final response = await model.generateContent([
        Content.text(_buildMatchPrompt(isPest, selectedSymptoms, candidates)),
      ]);
      final rawText = response.text ?? '';
      if (rawText.isEmpty) {
        debugPrint('[SymptomCheckerAI] ❌ Empty specific-match response.');
        return null;
      }

      final parsed =
          _parseJsonResponse(rawText, context: 'identifySpecificMatch');
      if (parsed == null) return null;

      final result = SpecificMatchResult.fromJson(parsed);

      // Closed-book guard: discard if Gemini named something outside the
      // retrieved candidate set (prevents hallucinated pest/disease names).
      if (!candidates.any((c) => c.name == result.bestMatch)) {
        debugPrint('[SymptomCheckerAI] ⚠️ AI returned "${result.bestMatch}" '
            'which is outside the candidate list — discarding result.');
        return null;
      }

      _matchCache[sig] = result;
      debugPrint('[SymptomCheckerAI] ✅ Specific match: ${result.bestMatch} '
          '(${result.confidence}%) — ${result.reasoning}');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('[SymptomCheckerAI] ❌ Firebase error in '
          'identifySpecificMatch: code=${e.code} message="${e.message}"');
      lastErrorMessage = humanizeAiError(e);
      return null;
    } catch (e, stack) {
      debugPrint(
          '[SymptomCheckerAI] ❌ Unexpected error in identifySpecificMatch: $e');
      debugPrint('[SymptomCheckerAI]    Stack: $stack');
      lastErrorMessage = humanizeAiError(e);
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROMPT BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  static String _candidateBlock(List<SymptomCandidate> candidates) {
    final buffer = StringBuffer();
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      buffer.writeln('${i + 1}. ${c.name}');
      buffer.writeln('   Description: ${c.description}');
      buffer.writeln('   Known symptoms: ${c.symptoms}');
    }
    return buffer.toString();
  }

  static String _buildClassificationPrompt(
    List<String> selectedSymptoms,
    List<SymptomCandidate> pestCandidates,
    List<SymptomCandidate> diseaseCandidates,
    List<SymptomCandidate> nutrientCandidates,
  ) {
    return '''
You are an expert coffee crop-health diagnostician for East African smallholder farms (Kenya, Uganda, Tanzania, Ethiopia).

A farmer observed these symptoms on their coffee plant:
${selectedSymptoms.map((s) => '- $s').join('\n')}

Candidate PESTS (insect/animal damage) that share some of these symptoms, retrieved from the farm knowledge base:
${pestCandidates.isEmpty ? '(none closely matched)' : _candidateBlock(pestCandidates)}

Candidate DISEASES (fungal/bacterial/viral) that share some of these symptoms:
${diseaseCandidates.isEmpty ? '(none closely matched)' : _candidateBlock(diseaseCandidates)}

Candidate NUTRIENT DEFICIENCIES that share some of these symptoms:
${nutrientCandidates.isEmpty ? '(none closely matched)' : _candidateBlock(nutrientCandidates)}

Task: decide whether these symptoms, taken together, more likely point to a PEST problem, a DISEASE problem, a NUTRIENT DEFICIENCY — or whether it is genuinely ambiguous given the overlap. Base your reasoning on real agronomic patterns: clean entry holes/frass/visible insects point to pests; lesions/mold/wilting-with-no-insect-signs point to disease; symmetric, gradual, whole-plant discoloration patterns (especially confined to older OR only younger leaves, without lesions or insect signs) point to a nutrient deficiency.

Return ONLY valid JSON. Start with { and end with }. No markdown, no code fences.
{
  "category": "<pest|disease|nutrient_deficiency|uncertain>",
  "confidence": <integer 0-100>,
  "reasoning": "<1-2 sentence practical explanation a smallholder farmer can understand, no jargon>"
}
''';
  }

  static String _buildMatchPrompt(
    bool isPest,
    List<String> selectedSymptoms,
    List<SymptomCandidate> candidates,
  ) {
    final kind = isPest ? 'pest' : 'disease';
    return '''
You are an expert coffee crop-health diagnostician for East African smallholder farms.

A farmer observed these symptoms on their coffee plant:
${selectedSymptoms.map((s) => '- $s').join('\n')}

Choose the SINGLE best-matching $kind from ONLY the candidates below — do not suggest anything outside this list, even if you believe another $kind fits better:
${_candidateBlock(candidates)}

Return ONLY valid JSON. Start with { and end with }. No markdown, no code fences.
{
  "best_match": "<exact name copied from the list above>",
  "confidence": <integer 0-100>,
  "reasoning": "<1-2 sentence explanation referencing the specific matching symptoms, for a farmer with no technical background>",
  "runner_up": "<second-best candidate name from the list if genuinely close, otherwise null>"
}
''';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JSON PARSER — same robust code-fence/truncation handling as the other
  // Gemini services in this project (GeminiSoilAiService, GeminiPestAiService,
  // GeminiDiseaseAiService).
  // ══════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic>? _parseJsonResponse(
    String rawText, {
    required String context,
  }) {
    try {
      String cleaned = rawText.trim();

      if (cleaned.contains('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      }

      if (cleaned.startsWith('"') && cleaned.length > 1) {
        final afterQuote = cleaned.substring(1).trimLeft();
        if (afterQuote.startsWith('{')) {
          cleaned = cleaned.substring(1);
          if (cleaned.endsWith('"')) {
            cleaned = cleaned.substring(0, cleaned.length - 1);
          }
          cleaned = cleaned.replaceAll(r'\"', '"').trim();
        }
      }

      final firstBrace = cleaned.indexOf('{');
      final lastBrace = cleaned.lastIndexOf('}');

      if (firstBrace == -1) {
        debugPrint('[SymptomCheckerAI] ❌ No opening "{" for $context.');
        return null;
      }

      if (lastBrace == -1 || lastBrace <= firstBrace) {
        debugPrint('[SymptomCheckerAI] ❌ No closing "}" for $context — '
            'likely truncated. Attempting partial recovery…');
        final partial = cleaned.substring(firstBrace);
        for (final candidate in ['$partial}', '$partial"}', '$partial"]}']) {
          try {
            return jsonDecode(candidate) as Map<String, dynamic>;
          } catch (_) {
            // Try next candidate.
          }
        }
        return null;
      }

      if (firstBrace > 0 || lastBrace < cleaned.length - 1) {
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }

      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[SymptomCheckerAI] ❌ JSON parse FAILED for $context: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  static void clearAllCaches() {
    _classificationCache.clear();
    _matchCache.clear();
    debugPrint('[SymptomCheckerAI] 🗑 All caches cleared.');
  }
}
