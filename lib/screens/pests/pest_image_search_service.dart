import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// ⚠️  CONFIGURATION
// ─────────────────────────────────────────────────────────────────────────────

const String _kPixabayApiKey  = '55515322-ac3ea56be51300c58d71bd837';
const String _kPixabayBaseUrl = 'https://pixabay.com/api/';

// ─────────────────────────────────────────────────────────────────────────────
// PER-PEST SEARCH PRIORITY LIST
//
// DESIGN RATIONALE — why this approach instead of category=animals:
//
// Problem with category=animals + generic terms:
//   Searching "thrips tiny insect plant" in category=animals made Pixabay rank
//   by POPULARITY within the animals category. Popular insects (ants, bees,
//   beetles) dominated results because they have more views/tags. Thrips,
//   antestia bugs, and stem borers have very few Pixabay photos and lost
//   the ranking competition — so wrong insects appeared for those pests.
//
// Solution — two rules:
//   1. NO category filter. Without a category, Pixabay matches by TAG
//      against the full index. A specific term like "thrips insect" only
//      returns photos tagged as thrips — not random popular insects.
//   2. Hand-crafted priority lists per pest. Each pest gets 3–4 terms
//      ordered from most specific → least specific:
//        Term 1: exact common name as used in photography/entomology
//        Term 2: scientific name (contributors often tag with Latin names)
//        Term 3: visual characteristic that is unique to this pest
//        Term 4: broader but still pest-specific term
//
// Fallback policy:
//   If ALL terms return 0 results → return empty list → pest_results_page.dart
//   shows the local asset fallback. Showing NO image is always better than
//   showing the WRONG insect (e.g. ants when the user selected Thrips).
// ─────────────────────────────────────────────────────────────────────────────

/// Each entry maps the exact pest name (as it appears in kStagePests /
/// kPestDetails) to an ordered list of Pixabay search terms.
/// Terms are tried in order; the first one that returns ≥1 result wins.
const Map<String, List<String>> _pestSearchPriority = {

  // ── Vegetative Stage ──────────────────────────────────────────────────────

  'Coffee Leaf Miner': [
    'coffee leaf miner',          // exact common name
    'Leucoptera coffeella',       // scientific name — used as photo tag
    'leaf miner damage coffee',   // visible symptom: winding tunnels on leaves
    'leaf miner moth larva',      // broader but still leaf-miner specific
  ],

  'Coffee Stem Borer': [
    'coffee stem borer',          // exact common name
    'Xylotrechus quadripes',      // scientific name (Kenya highland species)
    'stem borer beetle coffee',   // descriptive + host plant
    'longhorn beetle stem borer', // family characteristic (longhorn body)
  ],

  'Root-Knot Nematodes': [
    'root knot nematode',         // exact common name
    'Meloidogyne root',           // genus — widely used in scientific photos
    'nematode root gall',         // visible symptom: swollen root galls
    'plant root nematode damage', // broader symptom-focused
  ],

  'White Flies': [
    'whitefly plant',             // one word = better tag match on Pixabay
    'Bemisia tabaci',             // most common coffee whitefly species
    'whitefly infestation leaf',  // visual: white cloud under leaves
    'Trialeurodes whitefly',      // alternate genus also found on coffee
  ],

  'Coffee Mealybug': [
    'mealybug plant',             // mealybugs are visually distinctive — white fluffy
    'Planococcus citri',          // coffee mealybug scientific name
    'mealybug infestation stem',  // visible: cottony masses on stems
    'pseudococcus mealybug',      // alternate genus
  ],

  'Caterpillars': [
    'caterpillar leaf damage',    // plant-damage context
    'green caterpillar plant',    // most coffee caterpillars are green
    'moth caterpillar crop',      // crop context avoids butterfly photos
    'larva defoliation plant',    // symptom: defoliation
  ],

  'Ants': [
    'ants plant stem',            // plant-context ants (not ground-only photos)
    'ant aphid farming plant',    // ants on coffee often tend aphids/mealybugs
    'fire ant crop',              // fire ants common coffee pest in tropics
    'ant colony stem plant',      // colony on plant structure
  ],

  'Scale Insects': [
    'scale insect plant',         // distinctive waxy bumps on bark
    'armored scale bark',         // hard-scale type common on coffee
    'Coccidae soft scale',        // soft scale family
    'scale insect infestation',   // visible heavy infestation
  ],

  'Thrips': [
    'thrips insect',              // slender, fringed-wing insects — distinctive
    'Thrips tabaci',              // most common and widely photographed species
    'Frankliniella thrips',       // second most common genus
    'thrips flower damage',       // visible symptom: silvery scarring on tissue
  ],

  // ── Flowering & Fruit Development ─────────────────────────────────────────

  'Coffee Berry Borer': [
    'coffee berry borer',         // exact common name — many tagged photos
    'Hypothenemus hampei',        // scientific name — widely documented in research
    'coffee borer beetle',        // descriptive variant
    'berry borer damage coffee',  // symptom: tiny hole in the cherry
  ],

  'Coffee Antestia Bug': [
    'antestia bug',               // exact common name
    'Antestiopsis coffee',        // genus name for coffee antestia
    'shield bug coffee plant',    // antestia is a shield bug — distinctive shape
    'stink bug plant brown',      // pentatomidae family — brown marbled coloring
  ],

  // ── Post-harvest / Storage ────────────────────────────────────────────────

  'Coffee Weevil': [
    'coffee weevil',              // exact common name
    'Araecerus fasciculatus',     // scientific name (coffee bean weevil)
    'grain weevil beetle',        // family look — snout beetle shape
    'weevil storage grain',       // post-harvest storage context
  ],
};

/// Used when a pest name is NOT found in [_pestSearchPriority].
/// Strips known irrelevant prefixes and adds "insect" context.
/// This path should never be hit for standard coffee pests.
List<String> _fallbackTermsFor(String pestName) {
  final simplified = pestName
      .replaceAll(RegExp(r'^Coffee\s+',    caseSensitive: false), '')
      .replaceAll(RegExp(r'^Root-Knot\s+', caseSensitive: false), '')
      .trim();
  return ['$simplified insect', simplified];
}

// ─────────────────────────────────────────────────────────────────────────────
// In-memory cache
// ─────────────────────────────────────────────────────────────────────────────

class _CacheEntry {
  final List<String> urls;
  final DateTime cachedAt;
  const _CacheEntry(this.urls, this.cachedAt);
}

// ─────────────────────────────────────────────────────────────────────────────
// PEST IMAGE SEARCH SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class PestImageSearchService {
  PestImageSearchService._();

  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheDuration = Duration(hours: 1);
  static final http.Client _client = http.Client();

  // ══════════════════════════════════════════════════════════════════════════
  // CREDENTIAL VALIDATOR
  // ══════════════════════════════════════════════════════════════════════════

  static bool _isApiKeyConfigured() {
    if (_kPixabayApiKey == 'YOUR_PIXABAY_API_KEY_HERE' || _kPixabayApiKey.isEmpty) {
      debugPrint('[PestImageSearch] ❌ PIXABAY KEY NOT SET — '
          'Go to https://pixabay.com/api/docs/ , sign in (free), '
          'copy your key, and paste it into _kPixabayApiKey.');
      return false;
    }
    if (_kPixabayApiKey.length < 10) {
      debugPrint('[PestImageSearch] ❌ KEY TOO SHORT — '
          '${_kPixabayApiKey.length} chars. '
          'Valid key: "12345678-abc1234def5678abc9012def3".');
      return false;
    }
    if (_kPixabayApiKey.startsWith('AIza')) {
      debugPrint('[PestImageSearch] ❌ WRONG KEY TYPE — '
          'That is a Google Cloud key. Get a Pixabay key at '
          'https://pixabay.com/api/docs/');
      return false;
    }
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIMARY PUBLIC METHOD
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> searchPestImages({
    required String pestName,
    required String stage,
    int maxResults = 6,
  }) async {
    final clampedMax = maxResults.clamp(3, 20);
    final cacheKey   = '$pestName|$stage|$clampedMax';

    debugPrint('[PestImageSearch] 🔍 Requesting images for '
        '"$pestName" | stage="$stage" | max=$clampedMax');

    // ── Cache hit ──────────────────────────────────────────────────────────
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _cacheDuration) {
      debugPrint('[PestImageSearch] ✅ Cache hit for "$pestName" '
          '(${cached.urls.length} images, '
          'cached ${DateTime.now().difference(cached.cachedAt).inMinutes}min ago)');
      return cached.urls;
    }

    // ── Credential guard ───────────────────────────────────────────────────
    if (!_isApiKeyConfigured()) {
      debugPrint('[PestImageSearch] ⏭ Skipping — key not configured. '
          'Falling back to local assets.');
      _cache[cacheKey] = _CacheEntry([], DateTime.now());
      return [];
    }

    // ── Resolve ordered term list for this pest ────────────────────────────
    final terms = _pestSearchPriority[pestName] ?? _fallbackTermsFor(pestName);

    if (!_pestSearchPriority.containsKey(pestName)) {
      debugPrint('[PestImageSearch] ⚠️ "$pestName" not in _pestSearchPriority '
          '— using generic fallback. Add it to the map for accurate results.');
    } else {
      debugPrint('[PestImageSearch] 🗺 "$pestName" → '
          '${terms.length} terms: ${terms.map((t) => '"$t"').join(', ')}');
    }

    // ── Try each term — stop at first non-empty result ─────────────────────
    List<String> results = [];

    for (int i = 0; i < terms.length; i++) {
      final term = terms[i];
      debugPrint('[PestImageSearch] 🌐 Query ${i + 1}/${terms.length}: "$term"');

      try {
        results = await _executeSearch(term: term, numResults: clampedMax);

        if (results.isNotEmpty) {
          debugPrint('[PestImageSearch] ✅ Query ${i + 1} ("$term") returned '
              '${results.length} images. Stopping.');
          break;
        }
        debugPrint('[PestImageSearch] ⚠️ Query ${i + 1} ("$term") '
            'returned 0 images. Trying next term…');

      } on _QuotaExceededException {
        debugPrint('[PestImageSearch] ❌ RATE LIMIT — '
            '100 requests per 60 seconds. Wait and retry.');
        break;
      } on _AuthException catch (e) {
        debugPrint('[PestImageSearch] ❌ AUTH ERROR — $e');
        break;
      } on _NetworkException catch (e) {
        debugPrint('[PestImageSearch] ❌ Network error on query ${i + 1}: $e');
      } catch (e) {
        debugPrint('[PestImageSearch] ❌ Unexpected error on query ${i + 1}: $e');
      }
    }

    // Empty result = correct behaviour. Local asset fallback is always better
    // than displaying the wrong insect to the farmer.
    if (results.isEmpty) {
      debugPrint('[PestImageSearch] ℹ️ All ${terms.length} terms for '
          '"$pestName" returned 0 images. '
          'Returning empty → local asset fallback will display.');
    }

    _cache[cacheKey] = _CacheEntry(results, DateTime.now());
    debugPrint('[PestImageSearch] 📦 "$pestName" complete → '
        '${results.length} images cached.');
    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HTTP SEARCH EXECUTOR
  //
  // KEY DESIGN DECISION — no "category" parameter:
  //
  // Pixabay categories rank by POPULARITY within that bucket.
  // Popular insects (ants, bees) dominate category=animals for any query.
  // Without a category, Pixabay matches purely by TAG — a search for
  // "thrips insect" only returns photos tagged as thrips, regardless of
  // their popularity versus bees or ants. This gives correct results.
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> _executeSearch({
    required String term,
    required int    numResults,
  }) async {
    final uri = Uri.parse(_kPixabayBaseUrl).replace(
      queryParameters: {
        'key'        : _kPixabayApiKey,
        'q'          : term,
        'image_type' : 'photo',      // real photographs only
        'safesearch' : 'true',
        'lang'       : 'en',
        'order'      : 'popular',    // highest quality (most-viewed) first
        'per_page'   : numResults.toString(),
        'min_width'  : '300',        // skip thumbnails too small for carousel
        // NO 'category' — tag-based matching is more specific (see above)
      },
    );

    late http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw _NetworkException(e.toString());
    }

    debugPrint('[PestImageSearch] HTTP ${response.statusCode} for "$term"');

    switch (response.statusCode) {
      case 200:
        return _parsePixabayResponse(response.body, term: term);
      case 400:
        throw const _AuthException(
          'HTTP 400 — Pixabay rejected the request. '
          'API key likely invalid or query >100 characters. '
          'Re-copy your key from https://pixabay.com/api/docs/',
        );
      case 429:
        throw const _QuotaExceededException();
      case 403:
        debugPrint('[PestImageSearch] ❌ HTTP 403 — account may be inactive.');
        return [];
      default:
        debugPrint('[PestImageSearch] ⚠️ HTTP ${response.statusCode}: '
            '${response.body.substring(0, response.body.length.clamp(0, 200))}');
        return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESPONSE PARSER — Pixabay JSON
  //
  // Size preference:
  //   largeImageURL  → 1280 px max — preferred for the carousel
  //   webformatURL   → 640 px max  — fallback; valid for 24 h per Pixabay TOS
  // ══════════════════════════════════════════════════════════════════════════

  static List<String> _parsePixabayResponse(
    String responseBody, {
    required String term,
  }) {
    try {
      final json  = jsonDecode(responseBody) as Map<String, dynamic>;
      final total = json['totalHits'] as int? ?? 0;
      final hits  = json['hits']      as List<dynamic>?;

      debugPrint('[PestImageSearch] totalHits=$total for "$term"');

      if (hits == null || hits.isEmpty) return [];

      final urls = <String>[];
      for (final hit in hits) {
        final large  = hit['largeImageURL'] as String?;
        final webfmt = hit['webformatURL']  as String?;
        final chosen = (large != null && large.isNotEmpty) ? large : webfmt;

        if (chosen == null || chosen.isEmpty) continue;
        if (!chosen.startsWith('https://')) continue;

        urls.add(chosen);
      }

      debugPrint('[PestImageSearch] ✅ ${urls.length} valid URLs for "$term".');
      return urls;

    } catch (e) {
      debugPrint('[PestImageSearch] ❌ JSON parse error for "$term": $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT — same public API as all previous versions
  // ══════════════════════════════════════════════════════════════════════════

  static void clearCache() {
    _cache.clear();
    debugPrint('[PestImageSearch] 🗑 Cache cleared.');
  }

  static int get cacheSize => _cache.length;

  static bool isCached({
    required String pestName,
    required String stage,
    int maxResults = 6,
  }) {
    final key   = '$pestName|$stage|$maxResults';
    final entry = _cache[key];
    if (entry == null) return false;
    return DateTime.now().difference(entry.cachedAt) < _cacheDuration;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private exception types
// ─────────────────────────────────────────────────────────────────────────────

class _QuotaExceededException implements Exception {
  const _QuotaExceededException();
  @override
  String toString() => 'Pixabay rate limit hit (100 requests per 60 seconds).';
}

class _NetworkException implements Exception {
  final String message;
  const _NetworkException(this.message);
  @override
  String toString() => 'Network error: $message';
}

class _AuthException implements Exception {
  final String message;
  const _AuthException(this.message);
  @override
  String toString() => message;
}