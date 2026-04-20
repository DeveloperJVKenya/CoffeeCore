import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GEMINI PEST AI SERVICE
//
// ✅ Uses firebase_ai package (FirebaseAI.googleAI()) — matches the rest of
//    the project as seen in coffee_ai_chat_screen.dart.
//    The deprecated firebase_vertexai / FirebaseVertexAI has been removed.
// ─────────────────────────────────────────────────────────────────────────────

class GeminiPestAiService {
  GeminiPestAiService._();

  // ✅ gemini-2.5-flash — confirmed stable model for Firebase AI (Google AI backend)
  static const String _model = 'gemini-2.5-flash';

  // ── In-memory caches ───────────────────────────────────────────────────────
  static final Map<String, Map<String, dynamic>> _managementCache = {};
  static final Map<String, List<String>>         _stageListCache  = {};

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC — Generate enriched management details (Paths A & B)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> generateManagementDetails({
    required String pestName,
    required String stage,
  }) async {
    final cacheKey = '$pestName|$stage';

    if (_managementCache.containsKey(cacheKey)) {
      debugPrint('[GeminiPestAI] ✅ Cache hit — management for "$pestName" '
          '(stage="$stage")');
      return _managementCache[cacheKey];
    }

    debugPrint('[GeminiPestAI] 🤖 Calling Gemini API — '
        'management details for "$pestName" at "$stage"');

    try {
      // ✅ FirebaseAI.googleAI() — replaces deprecated FirebaseVertexAI.instance
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.3,
          // ✅ FIX: Increased from 1200 → 2048.
          //    Root cause of the truncation bug:
          //    A full 6-section JSON response for one pest needs ~1300–1600
          //    characters. At 1200 tokens (~900–1200 chars) Gemini cut the
          //    response before the closing "}", leaving _parseJsonResponse
          //    unable to find a valid JSON object (lastIndexOf('}') = -1).
          //    2048 tokens gives comfortable headroom for all six fields.
          maxOutputTokens: 2048,
        ),
      );

      debugPrint('[GeminiPestAI] 📤 Sending prompt for "$pestName"…');

      final response = await model.generateContent(
          [Content.text(_buildManagementPrompt(pestName, stage))]);
      final rawText = response.text ?? '';

      debugPrint('[GeminiPestAI] 📥 Raw response received — '
          '${rawText.length} characters. '
          'First 80 chars: "${rawText.substring(0, rawText.length.clamp(0, 80)).replaceAll('\n', '↵')}"');

      if (rawText.isEmpty) {
        debugPrint('[GeminiPestAI] ❌ Empty response from Gemini. '
            'This can happen when the model hits a safety filter or times out. '
            'Try again or check Firebase AI quota in Google Cloud Console.');
        return null;
      }

      final parsed = _parseJsonResponse(rawText, context: 'management("$pestName")');
      if (parsed == null) return null;

      // ── Validate expected keys are present ────────────────────────────
      final missingKeys = <String>[];
      for (final key in ['description', 'symptoms', 'chemical_controls',
                          'biological_controls', 'possible_causes',
                          'preventive_measures']) {
        if (!parsed.containsKey(key)) missingKeys.add(key);
      }
      if (missingKeys.isNotEmpty) {
        debugPrint('[GeminiPestAI] ⚠️ Parsed JSON is missing expected keys: '
            '$missingKeys. Will use what was returned.');
      }

      _managementCache[cacheKey] = parsed;
      debugPrint('[GeminiPestAI] ✅ Management details cached for "$pestName" '
          '(${parsed.keys.length} top-level keys: ${parsed.keys.toList()})');
      return parsed;

    } on FirebaseException catch (e) {
      debugPrint('[GeminiPestAI] ❌ Firebase error: code=${e.code} '
          'message="${e.message}". '
          'Check that Firebase AI is initialised and the Google AI backend is enabled '
          'in your Firebase project.');
      return null;
    } catch (e, stack) {
      debugPrint('[GeminiPestAI] ❌ Unexpected error generating management: $e');
      debugPrint('[GeminiPestAI]    Stack trace: $stack');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC — List possible pests for a growth stage (Path B assist)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>?> listPestsForStage({
    required String stage,
  }) async {
    if (_stageListCache.containsKey(stage)) {
      debugPrint('[GeminiPestAI] ✅ Cache hit — pest list for "$stage" '
          '(${_stageListCache[stage]!.length} pests)');
      return _stageListCache[stage];
    }

    debugPrint('[GeminiPestAI] 🤖 Calling Gemini API — pest list for stage "$stage"');

    try {
      // ✅ FirebaseAI.googleAI()
      final model = FirebaseAI.googleAI().generativeModel(
        model: _model,
        generationConfig: GenerationConfig(
          temperature:     0.2,
          maxOutputTokens: 512,   // Short list — 400 is fine, but 512 adds headroom
        ),
      );

      debugPrint('[GeminiPestAI] 📤 Sending stage-list prompt for "$stage"…');

      final response = await model.generateContent(
          [Content.text(_buildStageListPrompt(stage))]);
      final rawText = response.text ?? '';

      debugPrint('[GeminiPestAI] 📥 Stage-list response: '
          '${rawText.length} chars. '
          'Preview: "${rawText.substring(0, rawText.length.clamp(0, 80)).replaceAll('\n', '↵')}"');

      if (rawText.isEmpty) {
        debugPrint('[GeminiPestAI] ❌ Empty stage-list response from Gemini.');
        return null;
      }

      final parsed = _parseJsonResponse(rawText, context: 'stageList("$stage")');
      if (parsed == null) return null;

      final pests = List<String>.from(parsed['pests'] ?? []);
      if (pests.isEmpty) {
        debugPrint('[GeminiPestAI] ⚠️ Gemini returned a valid JSON object '
            'for "$stage" but the "pests" array is empty.');
        return null;
      }

      _stageListCache[stage] = pests;
      debugPrint('[GeminiPestAI] ✅ ${pests.length} pests listed for "$stage": '
          '${pests.take(3).join(", ")}${pests.length > 3 ? "…" : ""}');
      return pests;

    } on FirebaseException catch (e) {
      debugPrint('[GeminiPestAI] ❌ Firebase error in listPestsForStage: '
          'code=${e.code} message="${e.message}"');
      return null;
    } catch (e) {
      debugPrint('[GeminiPestAI] ❌ listPestsForStage unexpected error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROMPT BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  static String _buildManagementPrompt(String pestName, String stage) {
    return '''
You are a specialist agricultural AI for coffee farming in East Africa (Kenya, Uganda, Tanzania, Ethiopia).

Generate comprehensive pest management details for "$pestName" attacking coffee during the "$stage" stage.

Your audience is a smallholder coffee farmer — use clear, practical, actionable language. Avoid overly academic terminology.

Return ONLY a valid JSON object with NO markdown formatting, NO code fences, NO backticks, NO explanation outside the JSON. Start your response directly with the opening brace { and end with the closing brace }. Use exactly this structure:

{
  "description": "<2–3 sentence description of the pest: what it is, its lifecycle relevance to coffee, and why it is a problem at the $stage stage>",
  "symptoms": "<2–3 sentences describing the specific visible damage signs a farmer will see on their coffee plant at this stage>",
  "chemical_controls": [
    "<chemical name + brief application note>",
    "<chemical 2>",
    "<chemical 3 if applicable>"
  ],
  "biological_controls": [
    "<biological agent or natural predator + how to use it>",
    "<biological 2 if applicable>"
  ],
  "possible_causes": [
    "<environmental or agronomic condition predisposing the crop>",
    "<cause 2>",
    "<cause 3 if applicable>"
  ],
  "preventive_measures": [
    "<practical preventive action for a smallholder farmer>",
    "<measure 2>",
    "<measure 3>",
    "<measure 4 if applicable>"
  ]
}

Rules:
- Start your response with { and end with }. No markdown. No code fences. No backticks.
- All lists must have at least 1 item.
- Chemical names must be real, Kenya/Uganda-registered pesticides where possible.
- Biological controls should include locally available options (e.g. Beauveria bassiana, neem, parasitoid wasps).
- Preventive measures must be actionable by a smallholder farmer with limited resources.
- Keep each field concise — do not exceed 3 sentences for text fields or 4 items for list fields.
''';
  }

  static String _buildStageListPrompt(String stage) {
    return '''
You are an expert in East African coffee agronomy.

List all significant pests known to attack Arabica and Robusta coffee plants during the "$stage" growth stage in East Africa.

Return ONLY valid JSON with NO markdown, NO code fences, NO backticks. Start your response directly with { and end with }:

{
  "pests": [
    "<Pest common name 1>",
    "<Pest common name 2>",
    "<Pest common name 3>"
  ]
}

Rules:
- Start your response with { and end with }. No markdown. No code fences. No backticks.
- Use standard common names (e.g. "Coffee Berry Borer", "Coffee Leaf Miner").
- Include only economically significant pests at the "$stage" stage.
- List between 4 and 12 pests maximum.
- Do not include diseases — pests only.
''';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JSON PARSER
  //
  // BUGS FIXED IN THIS VERSION:
  //
  // 1. TRUNCATION (primary bug in production):
  //    Gemini's response was being cut at ~990 chars because maxOutputTokens
  //    was 1200 (~900-1200 chars). A full 6-field JSON needs ~1300-1600 chars.
  //    Truncation left no closing "}", so lastIndexOf('}') returned -1 and the
  //    condition lastBrace <= firstBrace (-1 <= 1) triggered the "No JSON
  //    object found" error. Fixed by raising maxOutputTokens to 2048 above.
  //
  // 2. OUTER QUOTE WRAPPING:
  //    Gemini occasionally wraps the JSON in outer double-quotes, producing:
  //       "{ \"description\": \"...\" }"
  //    The leading " shifts firstBrace to position 1 and if the response also
  //    ends with " the lastBrace points before it correctly — but jsonDecode
  //    still sees the outer quotes and fails. We now strip these.
  //
  // 3. CODE FENCE WRAPPING (original fix — preserved):
  //    Gemini sometimes wraps in ```json ... ``` despite being told not to.
  //    replaceAll() strips all occurrences regardless of trailing whitespace.
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
        debugPrint('[GeminiPestAI] ⚠️ Response for $context contains markdown '
            'code fences — stripping them now.');
        cleaned = cleaned.replaceAll(RegExp(r'```(?:json)?'), '').trim();
        debugPrint('[GeminiPestAI] 🔧 After fence removal, first 80 chars: '
            '"${cleaned.substring(0, cleaned.length.clamp(0, 80)).replaceAll('\n', '↵')}"');
      }

      // ── Step 2: Strip outer quote wrapping ───────────────────────────────
      // Gemini occasionally returns: "{ ... }" — the whole JSON as a string.
      // Detect this by checking if the text starts with " and the char after
      // the first " is {, then strip the outer quotes and unescape internals.
      if (cleaned.startsWith('"') && cleaned.length > 1) {
        final afterQuote = cleaned.substring(1).trimLeft();
        if (afterQuote.startsWith('{')) {
          debugPrint('[GeminiPestAI] ⚠️ Response for $context is wrapped in '
              'outer double-quotes — stripping outer quotes.');
          // Remove leading " and trailing " (if present)
          cleaned = cleaned.substring(1);
          if (cleaned.endsWith('"')) {
            cleaned = cleaned.substring(0, cleaned.length - 1);
          }
          // Unescape inner escaped quotes that Gemini added when wrapping
          cleaned = cleaned.replaceAll(r'\"', '"').trim();
          debugPrint('[GeminiPestAI] 🔧 After outer-quote strip, first 80 chars: '
              '"${cleaned.substring(0, cleaned.length.clamp(0, 80)).replaceAll('\n', '↵')}"');
        }
      }

      // ── Step 3: Find the outermost JSON object ───────────────────────────
      final firstBrace = cleaned.indexOf('{');
      final lastBrace  = cleaned.lastIndexOf('}');

      if (firstBrace == -1) {
        debugPrint('[GeminiPestAI] ❌ No opening "{" found in response for '
            '$context. The response may be plain text or completely malformed. '
            'Cleaned text (first 300 chars): '
            '"${cleaned.substring(0, cleaned.length.clamp(0, 300))}"');
        return null;
      }

      if (lastBrace == -1 || lastBrace <= firstBrace) {
        // Most likely cause: response was truncated (no closing }).
        // This happens when the JSON body exceeds maxOutputTokens.
        // Raising maxOutputTokens to 2048 above should prevent this entirely.
        debugPrint('[GeminiPestAI] ❌ No closing "}" found for $context — '
            'response was likely truncated mid-JSON (maxOutputTokens too low). '
            'Response length: ${rawText.length} chars. '
            'Cleaned text (first 300 chars): '
            '"${cleaned.substring(0, cleaned.length.clamp(0, 300))}"');
        return null;
      }

      if (firstBrace > 0 || lastBrace < cleaned.length - 1) {
        debugPrint('[GeminiPestAI] ⚠️ Extracting JSON substring for $context '
            '(extra text found outside braces).');
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }

      // ── Step 4: Decode ───────────────────────────────────────────────────
      final result = jsonDecode(cleaned) as Map<String, dynamic>;
      debugPrint('[GeminiPestAI] ✅ JSON parsed successfully for $context '
          '(${result.keys.length} keys).');
      return result;

    } catch (e) {
      debugPrint('[GeminiPestAI] ❌ JSON parse FAILED for $context: $e\n'
          '   Raw text (first 400 chars): '
          '"${rawText.substring(0, rawText.length.clamp(0, 400))}"');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  static void clearAllCaches() {
    _managementCache.clear();
    _stageListCache.clear();
    debugPrint('[GeminiPestAI] 🗑 All caches cleared.');
  }

  static bool isManagementCached({
    required String pestName,
    required String stage,
  }) =>
      _managementCache.containsKey('$pestName|$stage');

  static int get managementCacheSize => _managementCache.length;
}