import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// Result from ① soil vision scanner
class SoilTypeResult {
  final bool confident;
  final String? identifiedSoilType;
  final double? confidencePercent;
  final String? reasoning;
  final List<String> candidates;

  const SoilTypeResult({
    required this.confident,
    this.identifiedSoilType,
    this.confidencePercent,
    this.reasoning,
    this.candidates = const [],
  });

  factory SoilTypeResult.fromJson(Map<String, dynamic> json) => SoilTypeResult(
        confident: json['confident'] == true,
        identifiedSoilType: json['identified_soil_type'] as String?,
        confidencePercent: (json['confidence_percent'] as num?)?.toDouble(),
        reasoning: json['reasoning'] as String?,
        candidates: List<String>.from(json['candidates'] ?? []),
      );
}

/// A cross-nutrient interaction flagged by ② the holistic analyst
class NutrientInteraction {
  final String nutrient1;
  final String nutrient2;
  final String type;     // 'antagonism' | 'synergy'
  final String severity; // 'low' | 'medium' | 'high'
  final String description;

  const NutrientInteraction({
    required this.nutrient1,
    required this.nutrient2,
    required this.type,
    required this.severity,
    required this.description,
  });

  factory NutrientInteraction.fromJson(Map<String, dynamic> json) =>
      NutrientInteraction(
        nutrient1:   json['nutrient1']   as String? ?? '',
        nutrient2:   json['nutrient2']   as String? ?? '',
        type:        json['type']        as String? ?? 'antagonism',
        severity:    json['severity']    as String? ?? 'medium',
        description: json['description'] as String? ?? '',
      );
}

/// A prioritised AI recommendation for a single nutrient from ②
class SoilRecommendation {
  final String nutrient;
  final String priority;         // 'critical' | 'high' | 'medium' | 'low'
  final String artificial;       // Chemical/fertilizer solution
  final String natural;          // Organic/natural solution
  final String biological;       // Biological/microbial solution
  final String application;      // How & when to apply
  final String avoid;            // What practices/inputs to avoid
  final String causes;           // Likely causes of the deficiency/excess
  final String futureEnhancements; // Long-term improvement strategies

  const SoilRecommendation({
    required this.nutrient,
    required this.priority,
    required this.artificial,
    required this.natural,
    required this.biological,
    required this.application,
    required this.avoid,
    required this.causes,
    required this.futureEnhancements,
  });

  factory SoilRecommendation.fromJson(Map<String, dynamic> json) =>
      SoilRecommendation(
        nutrient:             json['nutrient']              as String? ?? '',
        priority:             json['priority']              as String? ?? 'medium',
        artificial:           json['artificial']            as String? ?? '',
        natural:              json['natural']               as String? ?? '',
        biological:           json['biological']            as String? ?? '',
        application:          json['application']           as String? ?? '',
        avoid:                json['avoid']                 as String? ?? '',
        causes:               json['causes']                as String? ?? '',
        futureEnhancements:   json['future_enhancements']  as String? ?? '',
      );

  /// Converts to the Map\<String,String> shape used by CoffeeSoilForm
  Map<String, String> toRecommendationMap() => {
        if (causes.isNotEmpty)              'causes':              causes,
        if (artificial.isNotEmpty)          'artificial':          artificial,
        if (natural.isNotEmpty)             'natural':             natural,
        if (biological.isNotEmpty)          'biological':          biological,
        if (application.isNotEmpty)         'application':         application,
        if (avoid.isNotEmpty)               'avoid':               avoid,
        if (futureEnhancements.isNotEmpty)  'future_enhancements': futureEnhancements,
      };
}

/// Full result from ② generateSoilAnalysis()
class SoilAnalysisResult {
  final int healthScore;
  final Map<String, String> nutrientStatus; // nutrient → Low|Optimal|High
  final List<NutrientInteraction> interactions;
  final List<SoilRecommendation> recommendations;
  final String summary;
  final String moisture;

  const SoilAnalysisResult({
    required this.healthScore,
    required this.nutrientStatus,
    required this.interactions,
    required this.recommendations,
    required this.summary,
    required this.moisture,
  });

  factory SoilAnalysisResult.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['nutrient_status'] as Map<String, dynamic>? ?? {};
    final interactionsRaw =
        json['interactions'] as List<dynamic>? ?? [];
    final recommendationsRaw =
        json['recommendations'] as List<dynamic>? ?? [];

    return SoilAnalysisResult(
      healthScore:    (json['health_score'] as num?)?.toInt() ?? 50,
      nutrientStatus: statusRaw.map((k, v) => MapEntry(k, v.toString())),
      interactions:   interactionsRaw
          .map((e) =>
              NutrientInteraction.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: recommendationsRaw
          .map((e) =>
              SoilRecommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary:  json['summary']  as String? ?? '',
      moisture: json['moisture'] as String? ?? '',
    );
  }

  /// Convenience: build the _allRecommendations map expected by the form
  Map<String, Map<String, String>> toAllRecommendations() {
    return {
      for (final rec in recommendations)
        if (nutrientStatus[rec.nutrient] != 'Optimal')
          rec.nutrient: rec.toRecommendationMap(),
      // Moisture is global — attach it to the first deficient nutrient
      // so the existing UI can show it.
    };
  }
}

/// A single week action inside a ③ FertilizationPlan
class FertilizationWeek {
  final int week;
  final String action;
  final String product;
  final double quantityKgPerAcre;
  final double quantityGPerPlant; // = (quantityKgPerAcre × 1000) ÷ plantDensity
  final String timing;
  final String notes;

  const FertilizationWeek({
    required this.week,
    required this.action,
    required this.product,
    required this.quantityKgPerAcre,
    required this.quantityGPerPlant,
    required this.timing,
    required this.notes,
  });

  factory FertilizationWeek.fromJson(Map<String, dynamic> json) =>
      FertilizationWeek(
        week:               (json['week'] as num?)?.toInt() ?? 1,
        action:             json['action']   as String? ?? '',
        product:            json['product']  as String? ?? '',
        quantityKgPerAcre:  (json['quantity_kg_per_acre'] as num?)?.toDouble() ?? 0,
        quantityGPerPlant:  (json['quantity_g_per_plant']  as num?)?.toDouble() ?? 0,
        timing:             json['timing']   as String? ?? '',
        notes:              json['notes']    as String? ?? '',
      );
}

/// Full result from ③ generateFertilizationPlan()
class FertilizationPlan {
  final List<FertilizationWeek> weeks;
  final int followUpDays;
  final String summary;

  const FertilizationPlan({
    required this.weeks,
    required this.followUpDays,
    required this.summary,
  });

  factory FertilizationPlan.fromJson(Map<String, dynamic> json) {
    final weeksRaw = json['weeks'] as List<dynamic>? ?? [];
    return FertilizationPlan(
      weeks:         weeksRaw
          .map((e) => FertilizationWeek.fromJson(e as Map<String, dynamic>))
          .toList(),
      followUpDays:  (json['follow_up_date_days'] as num?)?.toInt() ?? 90,
      summary:       json['summary'] as String? ?? '',
    );
  }
}

/// Predicted value range for a single nutrient from ④
class NutrientPrediction {
  final double current;
  final double expectedLow;
  final double expectedHigh;
  final String confidence; // 'high' | 'medium' | 'low'

  const NutrientPrediction({
    required this.current,
    required this.expectedLow,
    required this.expectedHigh,
    required this.confidence,
  });

  factory NutrientPrediction.fromJson(Map<String, dynamic> json) =>
      NutrientPrediction(
        current:       (json['current']       as num?)?.toDouble() ?? 0,
        expectedLow:   (json['expected_low']   as num?)?.toDouble() ?? 0,
        expectedHigh:  (json['expected_high']  as num?)?.toDouble() ?? 0,
        confidence:     json['confidence']      as String? ?? 'medium',
      );
}

/// Full result from ④ predictInterventionOutcome()
class InterventionPrediction {
  final Map<String, NutrientPrediction> predictions;
  final List<String> caveats;
  final String summary;

  const InterventionPrediction({
    required this.predictions,
    required this.caveats,
    required this.summary,
  });

  factory InterventionPrediction.fromJson(Map<String, dynamic> json) {
    final predsRaw = json['predictions'] as Map<String, dynamic>? ?? {};
    return InterventionPrediction(
      predictions: predsRaw.map((k, v) => MapEntry(
            k, NutrientPrediction.fromJson(v as Map<String, dynamic>))),
      caveats: List<String>.from(json['caveats'] ?? []),
      summary: json['summary'] as String? ?? '',
    );
  }
}

/// Full result from ⑤ analyzeSoilTrend()
class SoilTrendResult {
  final String overallDirection; // 'improving' | 'declining' | 'stable'
  final String trendSummary;
  final List<String> criticalAlerts;
  final List<String> positiveTrends;
  final String recommendedAction;

  const SoilTrendResult({
    required this.overallDirection,
    required this.trendSummary,
    required this.criticalAlerts,
    required this.positiveTrends,
    required this.recommendedAction,
  });

  factory SoilTrendResult.fromJson(Map<String, dynamic> json) =>
      SoilTrendResult(
        overallDirection:  json['overall_direction']    as String? ?? 'stable',
        trendSummary:      json['trend_summary']        as String? ?? '',
        criticalAlerts:    List<String>.from(json['critical_alerts']  ?? []),
        positiveTrends:    List<String>.from(json['positive_trends']  ?? []),
        recommendedAction: json['recommended_next_action'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// GEMINI SOIL AI SERVICE
//
// ✅ Uses firebase_ai package (FirebaseAI.googleAI()) — same backend as
//    GeminiPestAiService throughout the project.
//
// Six public entry points matching the six AI integration touchpoints:
//   ① identifySoilType()          — vision scan → soil type
//   ② generateSoilAnalysis()      — holistic 8-nutrient analysis + interactions
//   ③ generateFertilizationPlan() — week-by-week fertilizer schedule
//   ④ predictInterventionOutcome()— predicted nutrient values after intervention
//   ⑤ analyzeSoilTrend()          — cross-reading trend intelligence
//   ⑥ askSoilAdvisor()            — free-text conversational Q&A
// ─────────────────────────────────────────────────────────────────────────────

class GeminiSoilAiService {
  GeminiSoilAiService._();

  static const String _model = 'gemini-2.5-flash';

  // The advisor uses the same model as everything else — gemini-2.5-flash.
  // gemini-2.0-flash was deprecated for new users (API error confirmed).
  // Instead we defeat the thinking-token starvation by setting a token limit
  // large enough to absorb both the internal thinking pass (~2000–4000 tokens)
  // AND a complete response (~12 000+ tokens remaining = ~48 000 chars).
  // See _advisorMaxTokens usage in askSoilAdvisor().
  static const int _advisorMaxTokens = 16384;

  // ── In-memory caches ────────────────────────────────────────────────────────
  static final Map<String, SoilTypeResult>        _soilTypeCache    = {};
  static final Map<String, SoilAnalysisResult>    _analysisCache    = {};
  static final Map<String, FertilizationPlan>     _planCache        = {};
  static final Map<String, InterventionPrediction> _predictionCache = {};
  static final Map<String, SoilTrendResult>       _trendCache       = {};

  // ════════════════════════════════════════════════════════════════════════════
  // ① SOIL TYPE VISION SCANNER
  // ════════════════════════════════════════════════════════════════════════════

  static Future<SoilTypeResult?> identifySoilType({
    required Uint8List imageBytes,
    required String    mimeType,
  }) async {
    final cacheKey =
        'soiltype_${imageBytes.length}_${imageBytes.take(8).join("")}';
    if (_soilTypeCache.containsKey(cacheKey)) {
      debugPrint('[GeminiSoilAI] ✅ Cache hit — soil type scan');
      return _soilTypeCache[cacheKey];
    }

    debugPrint('[GeminiSoilAI] 🤖 Calling Gemini — soil type vision scan '
        '(${imageBytes.length} bytes, $mimeType)');

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.2,
          // 2048 ensures Gemini 2.5 Flash has sufficient budget after its
          // internal thinking pass — 512 caused the JSON to be truncated at
          // ~15 tokens, leaving the response without a closing "}" and
          // preventing autofill of the soil-type dropdown.
          maxOutputTokens: 2048,
        ),
      );

      const textPrompt = '''
You are an expert soil scientist specialising in East African coffee farming regions (Kenya, Uganda, Tanzania, Ethiopia).

A smallholder coffee farmer has photographed their bare soil. Identify the soil type from ONLY these five categories:
- Volcanic: Dark, crumbly, mineral-rich, often black or very dark brown.
- Red: Reddish clay, sticky when wet, heavy texture.
- Alluvial: Soft, silty, light brown, typically found near rivers or flood plains.
- Forest: Dark, spongy, organic matter visible, moist texture.
- Laterite: Hard, reddish-brown, gravelly, compact surface.

Return ONLY valid JSON. Start with { and end with }. No markdown, no code fences.

If you are 65% or more confident:
{
  "confident": true,
  "identified_soil_type": "<one of: Volcanic | Red | Alluvial | Forest | Laterite>",
  "confidence_percent": <number 65–100>,
  "reasoning": "<1–2 sentences describing the visual features used to identify the soil>",
  "candidates": []
}

If you are less than 65% confident:
{
  "confident": false,
  "identified_soil_type": null,
  "confidence_percent": <number>,
  "reasoning": "<1–2 sentences explaining the uncertainty>",
  "candidates": ["<most likely type>", "<second most likely type>"]
}
''';

      final response = await model.generateContent([
        Content.multi([
          InlineDataPart(mimeType, imageBytes),
          TextPart(textPrompt),
        ]),
      ]);

      final rawText = response.text ?? '';
      // Log finish reason to surface future truncations quickly.
      final finishReason = response.candidates.firstOrNull?.finishReason;
      debugPrint('[GeminiSoilAI] 📥 Soil-type response: '
          '${rawText.length} chars, finishReason=$finishReason. '
          'Preview: "${rawText.substring(0, rawText.length.clamp(0, 80)).replaceAll('\n', '↵')}"');

      if (rawText.isEmpty) {
        debugPrint('[GeminiSoilAI] ❌ Empty soil-type response.');
        return null;
      }

      final parsed = _parseJsonResponse(rawText, context: 'identifySoilType');
      if (parsed == null) return null;

      final result = SoilTypeResult.fromJson(parsed);
      _soilTypeCache[cacheKey] = result;
      debugPrint('[GeminiSoilAI] ✅ Soil type: '
          '${result.identifiedSoilType} (${result.confidencePercent}%)');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('[GeminiSoilAI] ❌ Firebase error in identifySoilType: '
          'code=${e.code} message="${e.message}"');
      return null;
    } catch (e, stack) {
      debugPrint('[GeminiSoilAI] ❌ Unexpected error in identifySoilType: $e');
      debugPrint('[GeminiSoilAI]    Stack: $stack');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ② HOLISTIC NUTRIENT ANALYST
  // ════════════════════════════════════════════════════════════════════════════

  static Future<SoilAnalysisResult?> generateSoilAnalysis({
    required Map<String, double> nutrientValues,
    required String  stage,
    required String? soilType,
    required int     plantDensity,
    required bool    isPerPlant,
  }) async {
    final cacheKey =
        '${_mapKey(nutrientValues)}|$stage|${soilType ?? "unknown"}';
    if (_analysisCache.containsKey(cacheKey)) {
      debugPrint('[GeminiSoilAI] ✅ Cache hit — soil analysis');
      return _analysisCache[cacheKey];
    }

    debugPrint('[GeminiSoilAI] 🤖 Calling Gemini — holistic soil analysis '
        'stage="$stage" soilType="$soilType"');

    try {
      // Gemini 2.5 Flash consumes ~1500–3000 tokens for its internal thinking
      // pass BEFORE emitting any visible output. With the old 2048 limit the
      // thinking pass ate the entire budget, leaving only ~200 visible chars —
      // never enough to close the JSON object.  16 384 matches _advisorMaxTokens
      // and is confirmed sufficient: thinking gets ~3000, output gets ~13 000+.
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.3,
          maxOutputTokens: 16384,
        ),
      );

      final response = await model.generateContent([
        Content.text(_buildAnalysisPrompt(
            nutrientValues, stage, soilType, plantDensity, isPerPlant)),
      ]);
      final rawText      = response.text ?? '';
      final finishReason = response.candidates.firstOrNull?.finishReason;

      debugPrint('[GeminiSoilAI] 📥 Analysis response: '
          '${rawText.length} chars, finishReason=$finishReason. '
          'Preview: "${rawText.substring(0, rawText.length.clamp(0, 80)).replaceAll('\n', '↵')}"');

      if (finishReason.toString().toUpperCase().contains('MAX_TOKENS')) {
        debugPrint('[GeminiSoilAI] ⚠️ Analysis hit MAX_TOKENS — '
            'response may still be recoverable via partial parse.');
      }

      if (rawText.isEmpty) {
        debugPrint('[GeminiSoilAI] ❌ Empty analysis response.');
        return null;
      }

      final parsed =
          _parseJsonResponse(rawText, context: 'generateSoilAnalysis');
      if (parsed == null) return null;

      final result = SoilAnalysisResult.fromJson(parsed);
      _analysisCache[cacheKey] = result;
      debugPrint('[GeminiSoilAI] ✅ Soil analysis complete — '
          'score=${result.healthScore}, '
          'interactions=${result.interactions.length}, '
          'recommendations=${result.recommendations.length}');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('[GeminiSoilAI] ❌ Firebase error in generateSoilAnalysis: '
          'code=${e.code} message="${e.message}"');
      return null;
    } catch (e, stack) {
      debugPrint(
          '[GeminiSoilAI] ❌ Unexpected error in generateSoilAnalysis: $e');
      debugPrint('[GeminiSoilAI]    Stack: $stack');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ③ FERTILIZATION SCHEDULE GENERATOR
  // ════════════════════════════════════════════════════════════════════════════

  static Future<FertilizationPlan?> generateFertilizationPlan({
    required Map<String, double> nutrientValues,
    required Map<String, String> nutrientStatus,
    required String  stage,
    required String? soilType,
    required int     plantDensity,
    required bool    isPerPlant,
  }) async {
    final cacheKey =
        'plan_${_mapKey(nutrientValues)}|$stage|${soilType ?? "unknown"}';
    if (_planCache.containsKey(cacheKey)) {
      debugPrint('[GeminiSoilAI] ✅ Cache hit — fertilization plan');
      return _planCache[cacheKey];
    }

    debugPrint('[GeminiSoilAI] 🤖 Calling Gemini — fertilization plan '
        'stage="$stage" soilType="$soilType"');

    try {
      // 8 192 tokens: thinking pass ~2000 + full plan JSON ~6000 headroom.
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.3,
          maxOutputTokens: 8192,
        ),
      );

      final response = await model.generateContent([
        Content.text(_buildFertilizationPrompt(
            nutrientValues, nutrientStatus, stage, soilType,
            plantDensity, isPerPlant)),
      ]);
      final rawText      = response.text ?? '';
      final finishReason = response.candidates.firstOrNull?.finishReason;

      debugPrint('[GeminiSoilAI] 📥 Fertilization plan response: '
          '${rawText.length} chars, finishReason=$finishReason.');

      if (rawText.isEmpty) {
        debugPrint('[GeminiSoilAI] ❌ Empty fertilization plan response.');
        return null;
      }

      final parsed =
          _parseJsonResponse(rawText, context: 'generateFertilizationPlan');
      if (parsed == null) return null;

      final result = FertilizationPlan.fromJson(parsed);
      _planCache[cacheKey] = result;
      debugPrint('[GeminiSoilAI] ✅ Fertilization plan — '
          '${result.weeks.length} weeks, '
          'follow-up in ${result.followUpDays} days');
      return result;
    } on FirebaseException catch (e) {
      debugPrint(
          '[GeminiSoilAI] ❌ Firebase error in generateFertilizationPlan: '
          'code=${e.code} message="${e.message}"');
      return null;
    } catch (e, stack) {
      debugPrint('[GeminiSoilAI] ❌ Unexpected error in '
          'generateFertilizationPlan: $e');
      debugPrint('[GeminiSoilAI]    Stack: $stack');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ④ INTERVENTION OUTCOME PREDICTOR
  // ════════════════════════════════════════════════════════════════════════════

  static Future<InterventionPrediction?> predictInterventionOutcome({
    required Map<String, double> currentValues,
    required String  interventionProduct,
    required double  interventionQuantityKgPerAcre,
    required String  stage,
    required String? soilType,
  }) async {
    final cacheKey =
        'pred_${_mapKey(currentValues)}|$interventionProduct|'
        '${interventionQuantityKgPerAcre.toStringAsFixed(1)}|$stage';
    if (_predictionCache.containsKey(cacheKey)) {
      debugPrint('[GeminiSoilAI] ✅ Cache hit — intervention prediction');
      return _predictionCache[cacheKey];
    }

    debugPrint('[GeminiSoilAI] 🤖 Calling Gemini — intervention outcome '
        'product="$interventionProduct" '
        'qty=${interventionQuantityKgPerAcre}kg/acre');

    try {
      // 4 096 tokens: thinking ~1500 + compact 8-nutrient prediction JSON.
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.2,
          maxOutputTokens: 4096,
        ),
      );

      final response = await model.generateContent([
        Content.text(_buildPredictionPrompt(currentValues,
            interventionProduct, interventionQuantityKgPerAcre,
            stage, soilType)),
      ]);
      final rawText = response.text ?? '';

      if (rawText.isEmpty) {
        debugPrint('[GeminiSoilAI] ❌ Empty prediction response.');
        return null;
      }

      final parsed = _parseJsonResponse(
          rawText, context: 'predictInterventionOutcome');
      if (parsed == null) return null;

      final result = InterventionPrediction.fromJson(parsed);
      _predictionCache[cacheKey] = result;
      debugPrint('[GeminiSoilAI] ✅ Intervention prediction — '
          '${result.predictions.length} nutrients predicted');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('[GeminiSoilAI] ❌ Firebase error in '
          'predictInterventionOutcome: code=${e.code} message="${e.message}"');
      return null;
    } catch (e, stack) {
      debugPrint('[GeminiSoilAI] ❌ Unexpected error in '
          'predictInterventionOutcome: $e');
      debugPrint('[GeminiSoilAI]    Stack: $stack');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ⑤ SOIL TREND ANALYST
  // ════════════════════════════════════════════════════════════════════════════

  static Future<SoilTrendResult?> analyzeSoilTrend({
    required List<Map<String, dynamic>> readings,
    required String? soilType,
    required String  stage,
  }) async {
    if (readings.length < 2) {
      debugPrint('[GeminiSoilAI] ⚠️ Not enough readings for trend analysis '
          '(need ≥2, got ${readings.length})');
      return null;
    }

    final lastTs =
        readings.last['timestamp']?.toString() ?? readings.length.toString();
    final cacheKey =
        'trend_${readings.length}_${lastTs}_${soilType ?? "unknown"}';
    if (_trendCache.containsKey(cacheKey)) {
      debugPrint('[GeminiSoilAI] ✅ Cache hit — trend analysis');
      return _trendCache[cacheKey];
    }

    debugPrint('[GeminiSoilAI] 🤖 Calling Gemini — trend analysis '
        '(${readings.length} readings, soilType="$soilType", stage="$stage")');

    try {
      // 4 096 tokens: thinking ~1500 + compact trend JSON ~2500 headroom.
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.3,
          maxOutputTokens: 4096,
        ),
      );

      final response = await model.generateContent([
        Content.text(_buildTrendPrompt(readings, soilType, stage)),
      ]);
      final rawText = response.text ?? '';

      if (rawText.isEmpty) {
        debugPrint('[GeminiSoilAI] ❌ Empty trend response.');
        return null;
      }

      final parsed =
          _parseJsonResponse(rawText, context: 'analyzeSoilTrend');
      if (parsed == null) return null;

      final result = SoilTrendResult.fromJson(parsed);
      _trendCache[cacheKey] = result;
      debugPrint('[GeminiSoilAI] ✅ Trend analysis — '
          'direction=${result.overallDirection}, '
          'alerts=${result.criticalAlerts.length}');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('[GeminiSoilAI] ❌ Firebase error in analyzeSoilTrend: '
          'code=${e.code} message="${e.message}"');
      return null;
    } catch (e, stack) {
      debugPrint(
          '[GeminiSoilAI] ❌ Unexpected error in analyzeSoilTrend: $e');
      debugPrint('[GeminiSoilAI]    Stack: $stack');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ⑥ SOIL ADVISOR CHAT
  // ════════════════════════════════════════════════════════════════════════════

  static Future<String?> askSoilAdvisor({
    required String question,
    Map<String, double>?     currentNutrients,
    String?                  stage,
    String?                  soilType,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    // Log the FULL question — the old 60-char substring was misleading users
    // into thinking their question hadn't been submitted completely.
    debugPrint('[GeminiSoilAI] 🤖 Soil advisor Q: "$question"');

    try {
      final contextBlock =
          _buildAdvisorContext(currentNutrients, stage, soilType);

      // _model (gemini-2.5-flash) is the only confirmed-available model.
      // _advisorMaxTokens (16 384) gives the thinking pass ~2000–4000 tokens
      // and leaves 12 000+ for the visible response — no truncation possible.
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        systemInstruction: Content.system(contextBlock),
        generationConfig: GenerationConfig(
          temperature:     0.7,
          maxOutputTokens: _advisorMaxTokens,
        ),
      );

      // Build multi-turn history.  The soil context lives in systemInstruction,
      // so user turns contain only the farmer's actual words.
      final contents = <Content>[];
      for (final turn in conversationHistory) {
        if (turn['role'] == 'user') {
          contents.add(Content.text(turn['text'] ?? ''));
        } else if (turn['role'] == 'model') {
          contents.add(Content('model', [TextPart(turn['text'] ?? '')]));
        }
      }
      contents.add(Content.text(question));

      final response = await model.generateContent(contents);
      final answer   = response.text ?? '';

      // Log finish reason — stop = clean completion; MAX_TOKENS = still truncating.
      final finishReason = response.candidates.firstOrNull?.finishReason;
      debugPrint('[GeminiSoilAI] ✅ Advisor answered '
          '(${answer.length} chars, finishReason=$finishReason)');

      if (answer.isEmpty) {
        debugPrint('[GeminiSoilAI] ❌ Empty advisor response.');
        return null;
      }

      return answer;
    } on FirebaseException catch (e) {
      debugPrint('[GeminiSoilAI] ❌ Firebase error in askSoilAdvisor: '
          'code=${e.code} message="${e.message}"');
      return null;
    } catch (e, stack) {
      debugPrint(
          '[GeminiSoilAI] ❌ Unexpected error in askSoilAdvisor: $e');
      debugPrint('[GeminiSoilAI]    Stack: $stack');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PROMPT BUILDERS
  // ════════════════════════════════════════════════════════════════════════════

  static String _buildAnalysisPrompt(
    Map<String, double> values,
    String  stage,
    String? soilType,
    int     plantDensity,
    bool    isPerPlant,
  ) {
    final unit = isPerPlant ? 'mg/plant' : 'kg/acre';
    final valuesStr = values.entries
        .map((e) =>
            '  "${e.key}": ${e.value.toStringAsFixed(2)}'
            '${e.key == 'pH' ? '' : ' $unit'}')
        .join('\n');

    // ── Research-based reference ranges (KCRI / IITA / ICO / CABI) ──────────
    // Per-acre soil test ranges (mg/kg equivalent, applied as kg/acre):
    //   pH        : Low < 5.5 | Optimal 5.5–6.5 | High > 6.5   (Arabica)
    //   Nitrogen  : Low < 40  | Optimal 40–80    | High > 80    kg N/acre
    //   Phosphorus: Low < 10  | Optimal 10–25    | High > 25    kg P/acre
    //   Potassium : Low < 80  | Optimal 80–160   | High > 160   kg K/acre
    //   Magnesium : Low < 20  | Optimal 20–60    | High > 60    kg Mg/acre
    //   Calcium   : Low < 400 | Optimal 400–1600 | High > 1600  kg Ca/acre
    //   Zinc      : Low < 0.4 | Optimal 0.4–2.5  | High > 2.5   kg Zn/acre
    //   Boron     : Low < 0.2 | Optimal 0.2–0.8  | High > 0.8   kg B/acre
    //
    // Per-plant (mg/plant) — divide per-acre by plant density:
    //   Nitrogen   : Low < 40 000/D | Optimal 40 000–80 000/D | High > 80 000/D
    //   (where D = plants/acre; exact thresholds scale linearly)
    // ────────────────────────────────────────────────────────────────────────

    // Build per-plant threshold note for the prompt
    final densityNote = isPerPlant
        ? 'Plant density $plantDensity plants/acre. '
          'Scale reference thresholds: divide per-acre benchmark by $plantDensity '
          'to get mg/plant threshold.'
        : 'Plant density $plantDensity plants/acre. '
          'For application rates per plant divide kg/acre values by $plantDensity.';

    return '''
You are a specialist agricultural AI for coffee farming in East Africa (Kenya, Uganda, Tanzania, Ethiopia).
Your knowledge is grounded in peer-reviewed coffee agronomy research from KCRI (Kenya Coffee Research Institute), IITA, CABI Crop Protection Compendium, ICO technical papers, UCDA, TaCRI, EIAR, and Jimma University.

Analyse the following soil nutrient data for a coffee plot and provide a holistic assessment.
IMPORTANT: reason about nutrient INTERACTIONS — e.g. high Ca can lock out Mg, low pH makes P unavailable regardless of P quantity, high K inhibits B uptake, low pH reduces N mineralisation.

Growth stage: "$stage"
Soil type: "${soilType ?? 'Unknown'}"
$densityNote
Measurement unit: $unit

Soil readings:
$valuesStr

─── RESEARCH-BASED REFERENCE RANGES FOR EAST AFRICAN ARABICA COFFEE ───
Use these peer-reviewed thresholds (KCRI/IITA/CABI) to classify each nutrient:

Nutrient     | Unit      | Low (Deficient)   | Optimal Range    | High (Excess)
-------------|-----------|-------------------|------------------|----------------
pH           | —         | < 5.5             | 5.5 – 6.5        | > 6.5
Nitrogen (N) | kg/acre   | < 40              | 40 – 80          | > 80
Phosphorus(P)| kg/acre   | < 10              | 10 – 25          | > 25
Potassium (K)| kg/acre   | < 80              | 80 – 160         | > 160
Magnesium(Mg)| kg/acre   | < 20              | 20 – 60          | > 60
Calcium (Ca) | kg/acre   | < 400             | 400 – 1600       | > 1600
Zinc (Zn)    | kg/acre   | < 0.4             | 0.4 – 2.5        | > 2.5
Boron (B)    | kg/acre   | < 0.2             | 0.2 – 0.8        | > 0.8

If unit is mg/plant, divide each threshold above by $plantDensity (plants/acre) to get the per-plant equivalent before classifying.

Stage-specific notes:
- Establishment/Seedling: N and P are most critical; keep pH >5.8 to avoid Al toxicity.
- Vegetative Growth: high N demand (up to 100 kg N/acre/year), adequate K for stem strength.
- Flowering & Fruiting: B and Zn critical for fruit set; Ca for cell integrity.
- Maturation & Harvesting: K highest demand for cherry fill; reduce N to avoid over-vegetative growth.
──────────────────────────────────────────────────────────────────────────

Return ONLY valid JSON. Start with { and end with }. No markdown, no code fences.
CRITICAL: The JSON must be complete — every opened array [ and object { MUST have a matching ] and }.
Do NOT truncate the response mid-sentence or mid-field. If you are running out of space, shorten individual text fields but complete all structural JSON brackets.

{
  "health_score": <integer 0-100, overall soil health>,
  "nutrient_status": {
    "pH":         "<Low | Optimal | High>",
    "nitrogen":   "<Low | Optimal | High>",
    "phosphorus": "<Low | Optimal | High>",
    "potassium":  "<Low | Optimal | High>",
    "magnesium":  "<Low | Optimal | High>",
    "calcium":    "<Low | Optimal | High>",
    "zinc":       "<Low | Optimal | High>",
    "boron":      "<Low | Optimal | High>"
  },
  "interactions": [
    {
      "nutrient1":   "<nutrient name>",
      "nutrient2":   "<nutrient name>",
      "type":        "<antagonism | synergy>",
      "severity":    "<low | medium | high>",
      "description": "<1 sentence practical description for a farmer>"
    }
  ],
  "recommendations": [
    {
      "nutrient":             "<nutrient name>",
      "priority":             "<critical | high | medium | low>",
      "causes":               "<2-3 sentences: most likely agronomic causes of this deficiency or excess — leaching, soil pH lock-out, over-application, crop removal, erosion etc.>",
      "artificial":           "<specific registered product name(s) + rate in kg/acre AND g/plant (e.g. CAN 26% at 50 kg/acre = ${(50000 / plantDensity).toStringAsFixed(0)} g/plant at $plantDensity plants/acre)>",
      "natural":              "<locally available organic alternative + rate — e.g. well-rotted coffee husks at 2 t/acre (~${(2000000 / plantDensity).toStringAsFixed(0)} g/plant)>",
      "biological":           "<microbial or biostimulant option if relevant — e.g. Rhizobium inoculant, mycorrhizal drench, EM solution — or empty string if not applicable>",
      "application":          "<step-by-step: timing relative to rain, placement depth, how to mix/dilute, any safety notes>",
      "avoid":                "<specific inputs, practices or timing combinations that will worsen this condition or harm coffee roots>",
      "future_enhancements":  "<2-3 long-term soil improvement strategies: cover crops, shade trees, composting systems, crop rotation, soil structure work>"
    }
  ],
  "summary": "<3-4 sentence plain-language overview of overall soil health, most urgent issue, and expected impact on yield if left unaddressed>",
  "moisture": "<specific mm/year range recommended for this soil type and growth stage, plus irrigation frequency guidance>"
}

Rules:
- Start response with { and end with }. No markdown. No code fences.
- COMPLETE THE FULL JSON — do not cut off mid-field. Every recommendation must include all 8 fields.
- Classify nutrients using the research-based thresholds table above — not generic intuition.
- Always express application rates BOTH per-acre AND per-plant (per-plant = per-acre ÷ $plantDensity).
- Optimal pH for East African Arabica/Robusta coffee: 5.5–6.5. Fix pH first — it controls bioavailability of everything else.
- List ONLY genuinely present interactions — do not fabricate theoretical ones.
- Use real product names: CAN 26%, DAP, TSP, KNO3, MgSO4, ZnSO4, Borax, agricultural lime, elemental sulfur, Rhizobium, Trichoderma.
- Maximum 4 interactions. Maximum 6 recommendations. Prioritise: critical then high then medium then low.
- Every field in each recommendation must be a non-empty, practical sentence — never leave a field as a generic placeholder.
- "avoid" must name SPECIFIC inputs or timing mistakes — not generic warnings.
- "future_enhancements" must name SPECIFIC practices: e.g. Calliandra shade trees, Mucuna cover crop, vermicompost pit.
''';
  }

  static String _buildFertilizationPrompt(
    Map<String, double> values,
    Map<String, String> status,
    String  stage,
    String? soilType,
    int     plantDensity,
    bool    isPerPlant,
  ) {
    final deficient = status.entries
        .where((e) => e.value == 'Low')
        .map((e) => e.key)
        .toList();
    final excess = status.entries
        .where((e) => e.value == 'High')
        .map((e) => e.key)
        .toList();

    return '''
You are a specialist agricultural AI for coffee farming in East Africa (Kenya, Uganda, Tanzania, Ethiopia).

Create a practical fertilization schedule for a smallholder coffee farmer.

Growth stage: "$stage"
Soil type: "${soilType ?? 'Unknown'}"
Plant density: $plantDensity plants/acre
Deficient nutrients: ${deficient.isEmpty ? 'None' : deficient.join(', ')}
Excess nutrients: ${excess.isEmpty ? 'None' : excess.join(', ')}

Return ONLY valid JSON. Start with { and end with }. No markdown, no code fences.
CRITICAL: The JSON must be complete — every opened array [ and object { MUST have a matching ] and }.

{
  "weeks": [
    {
      "week":                  <week number 1–12>,
      "action":                "<brief action title>",
      "product":               "<specific Kenya/Uganda-registered product name>",
      "quantity_kg_per_acre":  <number — kg of product per acre>,
      "quantity_g_per_plant":  <number — grams per plant = (quantity_kg_per_acre × 1000) ÷ $plantDensity>,
      "timing":                "<e.g. early morning before rain | after light rain>",
      "notes":                 "<1 sentence practical tip>"
    }
  ],
  "follow_up_date_days": <integer 60–120 — days until the farmer should retest>,
  "summary": "<2–3 sentence overview of the schedule for the farmer>"
}

Rules:
- Start response with { and end with }. No markdown. No code fences.
- ALWAYS include quantity_g_per_plant = (quantity_kg_per_acre × 1000) ÷ $plantDensity for each week entry.
- Use real available East African products: CAN 26%, DAP, TSP, KNO₃, MgSO₄, ZnSO₄, Borax, agricultural lime, elemental sulfur, farmyard manure, compost.
- Correct sequencing: if pH correction needed, apply lime in week 1 and wait 2 weeks before other fertilizers.
- Maximum 8 week entries. Keep achievable for a smallholder with limited cash — prioritise the most critical deficiency.
- If all nutrients are Optimal, return a light maintenance schedule.
- COMPLETE THE FULL JSON — include the closing summary field and all closing brackets.
''';
  }

  static String _buildPredictionPrompt(
    Map<String, double> values,
    String  product,
    double  quantityKgPerAcre,
    String  stage,
    String? soilType,
  ) {
    final valuesStr = values.entries
        .map((e) => '  ${e.key}: ${e.value.toStringAsFixed(2)}')
        .join('\n');

    return '''
You are a specialist agricultural AI for coffee farming in East Africa.

Predict what soil nutrient readings will look like approximately 90 days after the following intervention.

Current readings:
$valuesStr

Intervention applied:
  Product:  "$product"
  Quantity: $quantityKgPerAcre kg/acre
  Stage:    "$stage"
  Soil type: "${soilType ?? 'Unknown'}"

Return ONLY valid JSON. Start with { and end with }. No markdown, no code fences.

{
  "predictions": {
    "pH":         { "current": <number>, "expected_low": <number>, "expected_high": <number>, "confidence": "<high|medium|low>" },
    "nitrogen":   { "current": <number>, "expected_low": <number>, "expected_high": <number>, "confidence": "<high|medium|low>" },
    "phosphorus": { "current": <number>, "expected_low": <number>, "expected_high": <number>, "confidence": "<high|medium|low>" },
    "potassium":  { "current": <number>, "expected_low": <number>, "expected_high": <number>, "confidence": "<high|medium|low>" },
    "magnesium":  { "current": <number>, "expected_low": <number>, "expected_high": <number>, "confidence": "<high|medium|low>" },
    "calcium":    { "current": <number>, "expected_low": <number>, "expected_high": <number>, "confidence": "<high|medium|low>" },
    "zinc":       { "current": <number>, "expected_low": <number>, "expected_high": <number>, "confidence": "<high|medium|low>" },
    "boron":      { "current": <number>, "expected_low": <number>, "expected_high": <number>, "confidence": "<high|medium|low>" }
  },
  "caveats": [
    "<practical caveat — e.g. result depends on adequate rainfall>",
    "<second caveat if applicable>"
  ],
  "summary": "<2 sentence plain-language prediction the farmer can understand>"
}

Rules:
- Start response with { and end with }. No markdown. No code fences.
- For nutrients the intervention does NOT affect, set expected_low and expected_high equal to current.
- Predictions assume 90-day period and normal East African seasonal rainfall.
- Be conservative — use realistic agronomic ranges, not optimistic best-case.
''';
  }

  static String _buildTrendPrompt(
    List<Map<String, dynamic>> readings,
    String? soilType,
    String  stage,
  ) {
    final readingsStr = readings.asMap().entries.map((entry) {
      final i    = entry.key + 1;
      final r    = entry.value;
      final date = r['timestamp']?.toString().split('T').first ?? 'Reading $i';
      final nutrients =
          (r['nutrients'] as Map<String, dynamic>? ?? {})
              .entries
              .map((e) => '${e.key}: ${e.value}')
              .join(', ');
      return 'Reading $i ($date): $nutrients';
    }).join('\n');

    return '''
You are a specialist agricultural AI for coffee farming in East Africa (Kenya, Uganda, Tanzania, Ethiopia).

Analyse the trend across multiple soil readings from the same coffee plot. Identify genuine patterns over time, not just single-reading issues.

Soil type: "${soilType ?? 'Unknown'}"
Current growth stage: "$stage"

Historical readings (oldest first):
$readingsStr

Return ONLY valid JSON. Start with { and end with }. No markdown, no code fences.

{
  "overall_direction": "<improving | declining | stable>",
  "trend_summary": "<2–3 sentence narrative describing what is happening in the soil over time>",
  "critical_alerts": [
    "<urgent issue visible in the trend data — e.g. pH falling below 5.5 across readings>",
    "<second alert if applicable>"
  ],
  "positive_trends": [
    "<something genuinely improving across readings — e.g. K levels stabilising after intervention>",
    "<second positive if applicable>"
  ],
  "recommended_next_action": "<single most important specific action the farmer should take now — include product name and quantity>"
}

Rules:
- Start response with { and end with }. No markdown. No code fences.
- Only report alerts and positive trends that are GENUINELY visible in the data — do not fabricate.
- recommended_next_action must be highly specific — product name, quantity, timing.
- Write for a smallholder farmer with no technical background.
- If only 2 readings exist, state this limitation briefly in the trend_summary.
''';
  }

  static String _buildAdvisorContext(
    Map<String, double>? nutrients,
    String? stage,
    String? soilType,
  ) {
    // NOTE: Deliberately no sentence-count cap here — the previous
    // "Keep answers to 2–4 sentences" instruction was causing the advisor
    // to produce ~144-char truncated answers that left farmers with
    // incomplete guidance. The model is instructed to be thorough but
    // practical, and the UI supports multi-line scrollable bubbles.
    const systemInstruction =
        'You are a knowledgeable, friendly soil management advisor for '
        'smallholder coffee farmers in East Africa (Kenya, Uganda, Tanzania, '
        'Ethiopia). You give clear, complete, practical advice. You know '
        'locally available fertilizers (CAN 26%, DAP, TSP, KNO₃, lime, '
        'compost, manure) and local growing conditions. '
        'Answer thoroughly and completely — never cut off mid-sentence. '
        'Use as many sentences as the question requires to give the farmer '
        'genuinely useful, actionable guidance. Always be specific: name '
        'products, quantities, and timing where relevant. '
        'Use emojis naturally to make responses friendly and easy to scan '
        '(e.g. 🌿 for plant topics, 💧 for water, ⚠️ for warnings, '
        '✅ for recommendations). '
        'Write for someone with no chemistry background — no jargon. '
        'Use bullet points or numbered steps when listing actions.';

    if (nutrients == null || nutrients.isEmpty) {
      return systemInstruction;
    }

    final nutrientStr = nutrients.entries
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}')
        .join(', ');

    return '$systemInstruction\n\n'
        'The farmer\'s current soil data:\n'
        '  Stage: ${stage ?? 'Unknown'}\n'
        '  Soil type: ${soilType ?? 'Unknown'}\n'
        '  Nutrients: $nutrientStr\n\n'
        'Use this context when answering if relevant.';
  }

  // ════════════════════════════════════════════════════════════════════════════
  // JSON PARSER
  // (Identical robust implementation as GeminiPestAiService — handles
  //  code fences, outer quote wrapping, and truncation gracefully.)
  // ════════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic>? _parseJsonResponse(
    String rawText, {
    required String context,
  }) {
    try {
      String cleaned = rawText.trim();

      // Step 1: Strip markdown code fences
      if (cleaned.contains('```')) {
        debugPrint(
            '[GeminiSoilAI] ⚠️ Code fences in response for $context — stripping.');
        cleaned = cleaned.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      }

      // Step 2: Strip outer quote wrapping
      if (cleaned.startsWith('"') && cleaned.length > 1) {
        final afterQuote = cleaned.substring(1).trimLeft();
        if (afterQuote.startsWith('{')) {
          debugPrint(
              '[GeminiSoilAI] ⚠️ Outer quote wrapping for $context — stripping.');
          cleaned = cleaned.substring(1);
          if (cleaned.endsWith('"')) {
            cleaned = cleaned.substring(0, cleaned.length - 1);
          }
          cleaned = cleaned.replaceAll(r'\"', '"').trim();
        }
      }

      // Step 3: Extract outermost JSON object
      final firstBrace = cleaned.indexOf('{');
      final lastBrace  = cleaned.lastIndexOf('}');

      if (firstBrace == -1) {
        debugPrint('[GeminiSoilAI] ❌ No opening "{" for $context. '
            'Preview: "${cleaned.substring(0, cleaned.length.clamp(0, 300))}"');
        return null;
      }

      if (lastBrace == -1 || lastBrace <= firstBrace) {
        debugPrint('[GeminiSoilAI] ❌ No closing "}" for $context — '
            'likely truncated (${rawText.length} chars). '
            'Attempting partial recovery…');

        // ── Partial recovery ─────────────────────────────────────────────
        // The model sometimes truncates mid-object. Try completing the JSON
        // by appending the minimum needed closing punctuation.
        // Strategy: close any open string, then close the object.
        final partial = cleaned.substring(firstBrace);
        for (final candidate in [
          '$partial}',          // plain close
          '$partial"}',         // close open string then object
          '$partial"]}',        // close string + array + object
          '$partial"]}}',       // two levels deep
        ]) {
          try {
            final recovered =
                jsonDecode(candidate) as Map<String, dynamic>;
            debugPrint('[GeminiSoilAI] ⚠️ Partial JSON recovered for '
                '$context (${recovered.keys.length} keys: '
                '${recovered.keys.toList()})');
            return recovered;
          } catch (_) {
            // Try next candidate.
          }
        }

        debugPrint('[GeminiSoilAI] ❌ Recovery also failed for $context. '
            'Preview: "${cleaned.substring(0, cleaned.length.clamp(0, 300))}"');
        return null;
      }

      if (firstBrace > 0 || lastBrace < cleaned.length - 1) {
        debugPrint(
            '[GeminiSoilAI] ⚠️ Extra text outside JSON for $context — extracting.');
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }

      // Step 4: Decode
      final result = jsonDecode(cleaned) as Map<String, dynamic>;
      debugPrint('[GeminiSoilAI] ✅ JSON parsed for $context '
          '(${result.keys.length} top-level keys: ${result.keys.toList()})');
      return result;
    } catch (e) {
      debugPrint('[GeminiSoilAI] ❌ JSON parse FAILED for $context: $e\n'
          '   Raw (first 400): '
          '"${rawText.substring(0, rawText.length.clamp(0, 400))}"');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  static String _mapKey(Map<String, double> map) => map.entries
      .map((e) => '${e.key}:${e.value.toStringAsFixed(2)}')
      .join('|');

  // ════════════════════════════════════════════════════════════════════════════
  // ⑦ LIVE RESEARCH-GROUNDED INLINE RECOMMENDATIONS
  //
  // Uses Gemini's Google Search grounding tool to pull current guidance from
  // authoritative coffee research databases and extension services, then
  // synthesises it into the same Map<String,String> shape the form UI expects.
  //
  // Called once per nutrient when the farmer enters a value that resolves to
  // a non-Optimal status. Results are cached in _liveRecCache so a repeat
  // of the same (nutrient, status, stage, soilType) does not re-query.
  // ════════════════════════════════════════════════════════════════════════════

  static final Map<String, Map<String, String>> _liveRecCache = {};

  static Future<Map<String, String>> fetchLiveRecommendations({
    required String nutrient,
    required String status,     // 'Low' | 'High'
    required String stage,
    required String? soilType,
    required bool   isPerPlant,
    required int    plantDensity,
  }) async {
    final cacheKey =
        'live_${nutrient}_${status}_${stage}_${soilType ?? "any"}_'
        '${isPerPlant ? "plant" : "acre"}';
    if (_liveRecCache.containsKey(cacheKey)) {
      debugPrint('[GeminiSoilAI] ✅ Cache hit — live recs for $nutrient $status');
      return _liveRecCache[cacheKey]!;
    }

    debugPrint('[GeminiSoilAI] 🌐 Fetching live research recs — '
        '$nutrient $status | stage=$stage | soil=${soilType ?? "unknown"}');

    final unit     = isPerPlant ? 'mg/plant' : 'kg/acre';
    final soilDesc = soilType != null ? '$soilType soil' : 'unknown soil type';

    final prompt = '''
You are an expert coffee agronomist. Use Google Search to find current, peer-reviewed recommendations from authoritative sources including:
- CABI Crop Protection Compendium
- ICO (International Coffee Organization) technical papers
- IITA (International Institute of Tropical Agriculture)
- CIAT coffee research publications
- Kenya Coffee Research Institute (KCRI / KEFRI)
- Uganda Coffee Development Authority (UCDA) extension guides
- Ethiopian Institute of Agricultural Research (EIAR)
- Jimma University College of Agriculture coffee research
- Tanzania Coffee Research Institute (TaCRI)
- FAO soil fertility guides for East Africa

CONTEXT:
- Nutrient: $nutrient
- Status: $status (${status == 'Low' ? 'deficient' : 'excess'})
- Growth stage: $stage
- Soil type: $soilDesc
- Measurement units: $unit (plant density: $plantDensity plants/acre)

Search for and synthesise the most current and specific guidance on correcting $nutrient ${status.toLowerCase()} in coffee on $soilDesc during the $stage stage in East Africa.

Return ONLY valid JSON starting with { and ending with }. No markdown. No code fences.

{
  "causes":              "<2-3 sentences: specific agronomic reasons this condition occurs in East African coffee — leaching, pH lock-out, crop removal rates, soil mineralogy, management practices>",
  "artificial":          "<most effective registered chemical/mineral fertilizer: product name, exact rate in $unit, frequency — based on research findings>",
  "natural":             "<best organic/natural option available to East African smallholders: specific material, rate, timing — e.g. coffee pulp compost at 2 t/acre pre-rains>",
  "biological":          "<microbial or biostimulant approach if research supports it for this nutrient and soil type — or empty string if not applicable>",
  "application":         "<step-by-step application method: timing relative to rains, soil placement depth, dilution if foliar, any mixing precautions, safety notes>",
  "avoid":               "<specific inputs, over-application risks, timing mistakes or incompatible combinations that research shows worsen this condition in coffee>",
  "future_enhancements": "<2-3 long-term soil health strategies recommended by research: shade tree species, cover crops, composting systems, soil structure improvements>"
}

Rules:
- Every field must be a complete, specific, actionable sentence — no placeholders or generic advice.
- Base recommendations on East African conditions and locally available inputs.
- Name specific products (CAN 26%, DAP, TSP, KNO3, MgSO4, ZnSO4, Borax, lime, elemental sulfur) and organic materials (coffee husks, banana leaves, Tithonia mulch, farmyard manure).
- "avoid" must name specific harmful combinations or mistakes — not vague cautions.
- "future_enhancements" must name specific plant species or systems (e.g. Calliandra calothyrsus, Mucuna pruriens, Leucaena leucocephala).
''';

    try {
      // 8 192 tokens: Google Search grounding adds overhead (~2000 thinking +
      // grounding scaffold); this ensures the full 7-field JSON is never cut.
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.2,
          maxOutputTokens: 8192,
        ),
        tools: [
          Tool.googleSearch(),
        ],
      );

      final response = await model.generateContent([Content.text(prompt)]);
      final rawText  = response.text ?? '';

      debugPrint('[GeminiSoilAI] 📥 Live recs response: '
          '${rawText.length} chars for $nutrient $status');

      if (rawText.isEmpty) {
        debugPrint('[GeminiSoilAI] ❌ Empty live recs response — '
            'falling back to static for $nutrient');
        return {};
      }

      final parsed = _parseJsonResponse(rawText, context: 'fetchLiveRecommendations[$nutrient]');
      if (parsed == null) return {};

      final result = <String, String>{};
      for (final key in [
        'causes', 'artificial', 'natural', 'biological',
        'application', 'avoid', 'future_enhancements',
      ]) {
        final v = parsed[key] as String? ?? '';
        if (v.isNotEmpty) result[key] = v;
      }

      _liveRecCache[cacheKey] = result;
      debugPrint('[GeminiSoilAI] ✅ Live recs fetched for $nutrient $status '
          '— ${result.length} categories');
      return result;
    } on FirebaseException catch (e) {
      debugPrint('[GeminiSoilAI] ❌ Firebase error in fetchLiveRecommendations: '
          'code=${e.code} message="${e.message}"');
      return {};
    } catch (e, stack) {
      debugPrint('[GeminiSoilAI] ❌ Error in fetchLiveRecommendations: $e\n$stack');
      return {};
    }
  }

  static void clearLiveRecsCache() {
    _liveRecCache.clear();
    debugPrint('[GeminiSoilAI] 🗑 Live recommendations cache cleared.');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════════


  static void clearAllCaches() {
    _soilTypeCache.clear();
    _analysisCache.clear();
    _planCache.clear();
    _predictionCache.clear();
    _trendCache.clear();
    _liveRecCache.clear();
    debugPrint('[GeminiSoilAI] 🗑 All caches cleared.');
  }

  static void clearAnalysisCache() {
    _analysisCache.clear();
    _planCache.clear();
    _predictionCache.clear();
    debugPrint('[GeminiSoilAI] 🗑 Analysis/plan/prediction caches cleared.');
  }

  static int get totalCacheSize =>
      _soilTypeCache.length +
      _analysisCache.length +
      _planCache.length +
      _predictionCache.length +
      _trendCache.length;
}