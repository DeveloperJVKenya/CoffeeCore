import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GEMINI DISEASE AI SERVICE
//
// ✅ Uses firebase_ai package (FirebaseAI.googleAI()) — mirrors GeminiPestAiService.
//    All prompts are tuned specifically for coffee diseases in East Africa.
//    Supports:
//      1. generateManagementDetails()  — full disease treatment plan (Paths A, B & Custom)
//      2. listDiseasesForStage()       — AI-assisted disease listing per growth stage (Path B)
// ─────────────────────────────────────────────────────────────────────────────

class GeminiDiseaseAiService {
  GeminiDiseaseAiService._();

  static const String _model = 'gemini-2.5-flash';

  // ── In-memory caches ───────────────────────────────────────────────────────
  static final Map<String, Map<String, dynamic>> _managementCache = {};
  static final Map<String, List<String>>         _stageListCache  = {};

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC — Generate enriched disease management details (Paths A, B & Custom)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> generateManagementDetails({
    required String diseaseName,
    required String stage,
  }) async {
    final cacheKey = '$diseaseName|$stage';

    if (_managementCache.containsKey(cacheKey)) {
      debugPrint('[GeminiDiseaseAI] ✅ Cache hit — management for "$diseaseName" '
          '(stage="$stage")');
      return _managementCache[cacheKey];
    }

    debugPrint('[GeminiDiseaseAI] 🤖 Calling Gemini API — '
        'disease management details for "$diseaseName" at "$stage"');

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.3,
          // 2048 tokens gives comfortable headroom for all seven disease fields.
          maxOutputTokens: 4096,
        ),
      );

      debugPrint('[GeminiDiseaseAI] 📤 Sending prompt for "$diseaseName"…');

      final response = await model.generateContent(
          [Content.text(_buildManagementPrompt(diseaseName, stage))]);
      final rawText = response.text ?? '';

      debugPrint('[GeminiDiseaseAI] 📥 Raw response received — '
          '${rawText.length} characters. '
          'First 80 chars: "${rawText.substring(0, rawText.length.clamp(0, 80)).replaceAll('\n', '↵')}"');

      if (rawText.isEmpty) {
        debugPrint('[GeminiDiseaseAI] ❌ Empty response from Gemini. '
            'Check Firebase AI quota or safety filters.');
        return null;
      }

      final parsed = _parseJsonResponse(rawText, context: 'management("$diseaseName")');
      if (parsed == null) return null;

      // ── Validate expected keys ──────────────────────────────────────────
      final missingKeys = <String>[];
      for (final key in [
        'description',
        'symptoms',
        'chemical_controls',
        'biological_controls',
        'cultural_controls',
        'possible_causes',
        'preventive_measures',
      ]) {
        if (!parsed.containsKey(key)) missingKeys.add(key);
      }
      if (missingKeys.isNotEmpty) {
        debugPrint('[GeminiDiseaseAI] ⚠️ Parsed JSON missing expected keys: '
            '$missingKeys — using what was returned.');
      }

      _managementCache[cacheKey] = parsed;
      debugPrint('[GeminiDiseaseAI] ✅ Management details cached for "$diseaseName" '
          '(${parsed.keys.length} top-level keys: ${parsed.keys.toList()})');
      return parsed;

    } on FirebaseException catch (e) {
      debugPrint('[GeminiDiseaseAI] ❌ Firebase error: code=${e.code} '
          'message="${e.message}".');
      return null;
    } catch (e, stack) {
      debugPrint('[GeminiDiseaseAI] ❌ Unexpected error generating management: $e');
      debugPrint('[GeminiDiseaseAI]    Stack trace: $stack');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC — List possible diseases for a growth stage (Path B assist)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>?> listDiseasesForStage({
    required String stage,
  }) async {
    if (_stageListCache.containsKey(stage)) {
      debugPrint('[GeminiDiseaseAI] ✅ Cache hit — disease list for "$stage" '
          '(${_stageListCache[stage]!.length} diseases)');
      return _stageListCache[stage];
    }

    debugPrint('[GeminiDiseaseAI] 🤖 Calling Gemini API — disease list for stage "$stage"');

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.2,
          maxOutputTokens: 512,
        ),
      );

      debugPrint('[GeminiDiseaseAI] 📤 Sending stage-list prompt for "$stage"…');

      final response = await model.generateContent(
          [Content.text(_buildStageListPrompt(stage))]);
      final rawText = response.text ?? '';

      debugPrint('[GeminiDiseaseAI] 📥 Stage-list response: '
          '${rawText.length} chars. '
          'Preview: "${rawText.substring(0, rawText.length.clamp(0, 80)).replaceAll('\n', '↵')}"');

      if (rawText.isEmpty) {
        debugPrint('[GeminiDiseaseAI] ❌ Empty stage-list response from Gemini.');
        return null;
      }

      final parsed = _parseJsonResponse(rawText, context: 'stageList("$stage")');
      if (parsed == null) return null;

      final diseases = List<String>.from(parsed['diseases'] ?? []);
      if (diseases.isEmpty) {
        debugPrint('[GeminiDiseaseAI] ⚠️ Gemini returned valid JSON for '
            '"$stage" but the "diseases" array is empty.');
        return null;
      }

      _stageListCache[stage] = diseases;
      debugPrint('[GeminiDiseaseAI] ✅ ${diseases.length} diseases listed for "$stage": '
          '${diseases.take(3).join(", ")}${diseases.length > 3 ? "…" : ""}');
      return diseases;

    } on FirebaseException catch (e) {
      debugPrint('[GeminiDiseaseAI] ❌ Firebase error in listDiseasesForStage: '
          'code=${e.code} message="${e.message}"');
      return null;
    } catch (e) {
      debugPrint('[GeminiDiseaseAI] ❌ listDiseasesForStage unexpected error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROMPT BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  static String _buildManagementPrompt(String diseaseName, String stage) {
    return '''
You are a specialist agricultural AI for coffee farming in East Africa (Kenya, Uganda, Tanzania, Ethiopia).

Generate comprehensive disease management details for "$diseaseName" affecting coffee during the "$stage" stage.

Your audience is a smallholder coffee farmer — use clear, practical, actionable language. Avoid overly academic terminology.

Return ONLY a valid JSON object with NO markdown, NO code fences, NO backticks. Start your response directly with { and end with }:

{
  "description": "<2–3 sentence description of the disease: the pathogen responsible, how it spreads, and why it is particularly problematic at the $stage stage>",
  "symptoms": "<2–3 sentences describing the specific visible disease signs a farmer will observe on their coffee plant at this stage, starting from the earliest symptoms>",
  "chemical_controls": [
    "<fungicide/bactericide name + brief application note (rate, timing, or frequency)>",
    "<chemical 2>",
    "<chemical 3 if applicable>"
  ],
  "biological_controls": [
    "<biological agent or biocontrol product + how and when to use it>",
    "<biological 2 if applicable>"
  ],
  "cultural_controls": [
    "<cultural or agronomic practice for direct disease management>",
    "<cultural 2>",
    "<cultural 3 if applicable>"
  ],
  "possible_causes": [
    "<environmental, agronomic, or physiological condition predisposing the crop to this disease>",
    "<cause 2>",
    "<cause 3 if applicable>"
  ],
  "preventive_measures": [
    "<practical preventive action actionable by a smallholder farmer with limited resources>",
    "<measure 2>",
    "<measure 3>",
    "<measure 4 if applicable>"
  ]
}

Rules:
- Start your response with { and end with }. No markdown. No code fences. No backticks.
- All lists must have at least 1 item.
- Fungicide/bactericide names must be real, Kenya/Uganda-registered products where possible.
- Biological controls should include locally available options (e.g. Trichoderma, Bacillus subtilis, copper-based organic products).
- Cultural controls should be different from preventive measures — focus on managing an active infection vs preventing one.
- Preventive measures must be actionable by a smallholder farmer with limited resources.
- Keep each field concise — do not exceed 3 sentences for text fields or 4 items for list fields.
''';
  }

  static String _buildStageListPrompt(String stage) {
    return '''
You are an expert in East African coffee agronomy and plant pathology.

List all significant diseases known to affect Arabica and Robusta coffee plants during the "$stage" growth stage in East Africa.

Return ONLY valid JSON with NO markdown, NO code fences, NO backticks. Start your response directly with { and end with }:

{
  "diseases": [
    "<Disease common name 1>",
    "<Disease common name 2>",
    "<Disease common name 3>"
  ]
}

Rules:
- Start your response with { and end with }. No markdown. No code fences. No backticks.
- Use standard common names (e.g. "Coffee Leaf Rust", "Coffee Berry Disease").
- Include only economically significant diseases at the "$stage" stage.
- List between 4 and 12 diseases maximum.
- Do not include pests or insects — diseases only (fungal, bacterial, viral, nematode-caused).
''';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JSON PARSER
  //
  // Mirrors GeminiPestAiService._parseJsonResponse() with identical
  // robustness fixes for truncation, outer quote wrapping, and code fences.
  // ══════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic>? _parseJsonResponse(
    String rawText, {
    required String context,
  }) {
    try {
      String cleaned = rawText.trim();

      // ── Step 1: Strip ALL markdown code fences ───────────────────────────
      final hasFences = cleaned.contains('```');
      if (hasFences) {
        debugPrint('[GeminiDiseaseAI] ⚠️ Response for $context contains markdown '
            'code fences — stripping them now.');
        cleaned = cleaned.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      }

      // ── Step 2: Strip outer quote wrapping ───────────────────────────────
      if (cleaned.startsWith('"') && cleaned.length > 1) {
        final afterQuote = cleaned.substring(1).trimLeft();
        if (afterQuote.startsWith('{')) {
          debugPrint('[GeminiDiseaseAI] ⚠️ Response for $context is wrapped in '
              'outer double-quotes — stripping outer quotes.');
          cleaned = cleaned.substring(1);
          if (cleaned.endsWith('"')) {
            cleaned = cleaned.substring(0, cleaned.length - 1);
          }
          cleaned = cleaned.replaceAll(r'\"', '"').trim();
        }
      }

      // ── Step 3: Find the outermost JSON object ───────────────────────────
      final firstBrace = cleaned.indexOf('{');
      final lastBrace  = cleaned.lastIndexOf('}');

      if (firstBrace == -1) {
        debugPrint('[GeminiDiseaseAI] ❌ No opening "{" found for $context. '
            'First 300 chars: "${cleaned.substring(0, cleaned.length.clamp(0, 300))}"');
        return null;
      }

      if (lastBrace == -1 || lastBrace <= firstBrace) {
        // JSON-repair fallback: the model truncated the response mid-object.
        // Try to close any unclosed arrays then close the top-level object,
        // then parse whatever fields survived intact.
        debugPrint('[GeminiDiseaseAI] No closing brace found for $context - '
            'attempting JSON-repair on truncated response '
            '(${rawText.length} chars).');
        final repaired = _repairTruncatedJson(cleaned.substring(firstBrace));
        if (repaired != null) {
          debugPrint('[GeminiDiseaseAI] Repaired JSON for $context - '
              '(${repaired.keys.length} keys recovered).');
          return repaired;
        }
        debugPrint('[GeminiDiseaseAI] JSON-repair failed for $context. '
            'Response length: ${rawText.length} chars.');
        return null;
      }

      if (firstBrace > 0 || lastBrace < cleaned.length - 1) {
        debugPrint('[GeminiDiseaseAI] ⚠️ Extracting JSON substring for $context '
            '(extra text found outside braces).');
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }

      // ── Step 4: Decode ───────────────────────────────────────────────────
      final result = jsonDecode(cleaned) as Map<String, dynamic>;
      debugPrint('[GeminiDiseaseAI] ✅ JSON parsed successfully for $context '
          '(${result.keys.length} keys).');
      return result;

    } catch (e) {
      debugPrint('[GeminiDiseaseAI] ❌ JSON parse FAILED for $context: $e\n'
          '   Raw text (first 400 chars): '
          '"${rawText.substring(0, rawText.length.clamp(0, 400))}"');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  // JSON REPAIR — close truncated JSON so partial responses are still useful
  // ══════════════════════════════════════════════════════════════════════════

  /// Attempts to repair a truncated JSON object string.
  ///
  /// Strategy:
  ///   1. Walk the string tracking depth of `{` / `[` and whether we are
  ///      inside a string literal.
  ///   2. Strip the last incomplete token (unfinished string or bare word).
  ///   3. Remove trailing commas before closing characters.
  ///   4. Append the closers needed to balance all open `[` and `{`.
  ///   5. Try jsonDecode — return null on failure.
  static Map<String, dynamic>? _repairTruncatedJson(String partial) {
    try {
      // Walk through to find the last safely-parseable position.
      final buf = StringBuffer();
      bool inString = false;
      bool escaped = false;
      final stack = <String>[];  // '{' or '['

      for (int i = 0; i < partial.length; i++) {
        final ch = partial[i];
        if (escaped) {
          buf.write(ch);
          escaped = false;
          continue;
        }
        if (ch == r'\' && inString) {
          buf.write(ch);
          escaped = true;
          continue;
        }
        if (ch == '"') {
          inString = !inString;
          buf.write(ch);
          continue;
        }
        if (!inString) {
          if (ch == '{' || ch == '[') stack.add(ch);
          if (ch == '}' || ch == ']') {
            if (stack.isNotEmpty) stack.removeLast();
          }
        }
        buf.write(ch);
      }

      // If we ended mid-string, close it.
      String working = buf.toString();
      if (inString) working += '"';

      // Strip trailing commas before closing bracket/brace (invalid JSON).
      working = working.replaceAll(RegExp(r',\s*([}\]])'), r'\1');

      // Close any unclosed arrays / objects in reverse stack order.
      for (int i = stack.length - 1; i >= 0; i--) {
        working += stack[i] == '{' ? '}' : ']';
      }

      final result = jsonDecode(working) as Map<String, dynamic>;
      return result;
    } catch (_) {
      return null;
    }
  }

  // CACHE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  static void clearAllCaches() {
    _managementCache.clear();
    _stageListCache.clear();
    debugPrint('[GeminiDiseaseAI] 🗑 All caches cleared.');
  }

  static bool isManagementCached({
    required String diseaseName,
    required String stage,
  }) =>
      _managementCache.containsKey('$diseaseName|$stage');

  static int get managementCacheSize => _managementCache.length;
}