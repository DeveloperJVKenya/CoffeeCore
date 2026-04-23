import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// DISEASE IMAGE SEARCH SERVICE  —  v1
//
// Mirrors PestImageSearchService architecture exactly.
// Sources (tried in order; only verified images are ever returned):
//
//   1. iNaturalist Observations API  — research-grade verified photos of pathogens
//      and disease symptoms on coffee plants. Free · no API key.
//      https://api.inaturalist.org/v1/observations
//
//   2. iNaturalist Taxa API          — canonical representative photo per pathogen taxon.
//      Free · no API key.
//      https://api.inaturalist.org/v1/taxa
//
//   3. Wikipedia / Wikimedia Commons — disease article lead image (infobox thumbnail).
//      Returns exactly 1 image per disease. Always correct by definition.
//      Free · no API key.
//      https://en.wikipedia.org/w/api.php
//
// DISEASE-SPECIFIC NOTES:
//   • Many coffee diseases are caused by microscopic fungi — iNaturalist has
//     good coverage of their macroscopic symptoms on host plants.
//   • Taxon queries use the pathogen scientific name; symptom-level photos
//     are returned via observation queries on the coffee host plant + taxon.
//   • OTA contamination and storage molds use genus-level taxa only (Aspergillus, Penicillium).
// ─────────────────────────────────────────────────────────────────────────────

const String _kINatBaseUrl = 'https://api.inaturalist.org/v1';
const String _kWikiBaseUrl = 'https://en.wikipedia.org/w/api.php';
const String _kUserAgent   =
    'CoffeeCore/1.0 (Flutter; East Africa coffee disease management)';

// ─────────────────────────────────────────────────────────────────────────────
// PER-DISEASE CONFIGURATION
//
// taxonNames     Scientific name(s) for iNaturalist observations/taxa queries.
//                Use pathogen name — iNaturalist has observations of fungi/bacteria.
//
// wikipediaTitle Exact Wikipedia article title. Verified fallback image.
//
// symptomQuery   Optional plain-text search for iNaturalist observations of the
//                disease symptoms on coffee plants where pathogen taxon is obscure.
// ─────────────────────────────────────────────────────────────────────────────

class _DiseaseConfig {
  final List<String> taxonNames;
  final String?      wikipediaTitle;
  final String?      symptomQuery;

  const _DiseaseConfig({
    required this.taxonNames,
    this.wikipediaTitle,
    this.symptomQuery,
  });
}

const Map<String, _DiseaseConfig> _diseaseConfig = {

  // ── Vegetative / All-Stage Diseases ─────────────────────────────────────────

  'Coffee Leaf Rust': _DiseaseConfig(
    taxonNames: [
      'Hemileia vastatrix',  // coffee leaf rust — the specific pathogen
      'Hemileia',            // genus — all Hemileia are rusts on coffee
    ],
    wikipediaTitle: 'Coffee leaf rust',
    symptomQuery:  'coffee leaf rust orange spots Coffea arabica',
  ),

  'Coffee Berry Disease': _DiseaseConfig(
    taxonNames: [
      'Colletotrichum kahawae',       // CBD pathogen — specific to coffee berries
      'Colletotrichum gloeosporioides', // broad Colletotrichum — anthracnose group
    ],
    wikipediaTitle: 'Coffee berry disease',
    symptomQuery:  'Colletotrichum kahawae coffee berry black',
  ),

  'Coffee Wilt Disease': _DiseaseConfig(
    taxonNames: [
      'Gibberella xylarioides',  // coffee wilt perfect stage
      'Fusarium xylarioides',    // anamorph — same fungus
      'Fusarium',                // genus — wilt fusaria
    ],
    wikipediaTitle: 'Coffee wilt disease',
  ),

  'Coffee Root Rot': _DiseaseConfig(
    taxonNames: [
      'Phytophthora cinnamomi',  // root rot of coffee
      'Pythium',                 // damping-off / root rot genus
      'Fusarium solani',         // fusarium root rot
    ],
    wikipediaTitle: 'Phytophthora cinnamomi',
    symptomQuery:  'Phytophthora root rot coffee',
  ),

  'Coffee Brown Eye Spot': _DiseaseConfig(
    taxonNames: [
      'Cercospora coffeicola',  // brown eye spot pathogen — specific
      'Cercospora',             // genus — all produce leaf spots
    ],
    wikipediaTitle: 'Cercospora coffeicola',
    symptomQuery:  'Cercospora coffee leaf spot brown',
  ),

  'Coffee Damping Off': _DiseaseConfig(
    taxonNames: [
      'Pythium',          // primary damping-off genus
      'Rhizoctonia solani', // secondary damping-off fungus
    ],
    wikipediaTitle: 'Damping off',
    symptomQuery:  'coffee seedling damping off nursery Pythium',
  ),

  'Coffee Sooty Mold': _DiseaseConfig(
    taxonNames: [
      'Capnodium coffeae',  // coffee sooty mold — specific species
      'Cladosporium',       // broad sooty mold genus
      'Capnodiales',        // sooty mold order — all are sooty molds
    ],
    wikipediaTitle: 'Sooty mold',
    symptomQuery:  'sooty mold coffee black coating leaves',
  ),

  'Coffee Bacterial Blight': _DiseaseConfig(
    taxonNames: [
      'Pseudomonas syringae',  // bacterial blight pathogen group
    ],
    wikipediaTitle: 'Pseudomonas syringae',
    symptomQuery:  'Pseudomonas coffee bacterial blight leaf spot',
  ),

  'Coffee Anthracnose': _DiseaseConfig(
    taxonNames: [
      'Colletotrichum gloeosporioides', // primary anthracnose species
      'Colletotrichum',                 // genus — all cause anthracnose
    ],
    wikipediaTitle: 'Anthracnose',
    symptomQuery:  'Colletotrichum anthracnose coffee berry lesion',
  ),

  'Coffee Nursery Blight': _DiseaseConfig(
    taxonNames: [
      'Rhizoctonia solani',  // primary nursery blight pathogen
      'Pythium',             // secondary damping-off pathogen
    ],
    wikipediaTitle: 'Rhizoctonia solani',
    symptomQuery:  'Rhizoctonia seedling blight nursery',
  ),

  // ── Post-harvest / Storage Diseases ─────────────────────────────────────────

  'Coffee Green Mold': _DiseaseConfig(
    taxonNames: [
      'Penicillium',   // green/blue mold genus — primary coffee storage mold
      'Aspergillus',   // co-occurrence in storage
    ],
    wikipediaTitle: 'Penicillium',
    symptomQuery:  'Penicillium mold green stored coffee beans',
  ),

  'Coffee Ochratoxin A Contamination': _DiseaseConfig(
    taxonNames: [
      'Aspergillus carbonarius',  // primary OTA producer on coffee
      'Aspergillus ochraceus',    // secondary OTA producer
      'Aspergillus',              // genus fallback
    ],
    wikipediaTitle: 'Ochratoxin A',
    symptomQuery:  'Aspergillus coffee beans mold storage',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// CACHE MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _CacheEntry {
  final List<String> urls;
  final DateTime     cachedAt;
  const _CacheEntry(this.urls, this.cachedAt);
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseImageSearchService {
  DiseaseImageSearchService._();

  static final http.Client _client        = http.Client();
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheDuration    = Duration(hours: 12);

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC — Search images for a given disease name
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> searchDiseaseImages({
    required String diseaseName,
    required String stage,
    int maxResults = 8,
  }) async {
    final cacheKey = '$diseaseName|$stage|$maxResults';

    // ── Cache check ────────────────────────────────────────────────────────
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _cacheDuration) {
      debugPrint('[DiseaseImageSearch] ✅ Cache hit for '
          '"$diseaseName" — ${cached.urls.length} images');
      return cached.urls;
    }

    debugPrint('[DiseaseImageSearch] 🔍 Searching images for "$diseaseName"…');
    final config = _diseaseConfig[diseaseName];
    final urls   = <String>[];

    if (config != null) {
      // ── Source 1: iNaturalist Observations ──────────────────────────────
      for (final taxon in config.taxonNames) {
        if (urls.length >= maxResults) break;
        final fetched = await _iNatObservations(
            taxonName: taxon, maxResults: maxResults - urls.length);
        _mergeUnique(urls, fetched, maxResults);
      }

      // ── Source 1b: Symptom query observations ────────────────────────────
      if (urls.length < maxResults && config.symptomQuery != null) {
        final fetched = await _iNatObservationsByText(
            query: config.symptomQuery!, maxResults: maxResults - urls.length);
        _mergeUnique(urls, fetched, maxResults);
      }

      // ── Source 2: iNaturalist Taxa default photos ─────────────────────────
      if (urls.length < maxResults) {
        for (final taxon in config.taxonNames) {
          if (urls.length >= maxResults) break;
          final fetched = await _iNatTaxa(
              query: taxon, maxResults: maxResults - urls.length);
          _mergeUnique(urls, fetched, maxResults);
        }
      }

      // ── Source 3: Wikipedia infobox image ────────────────────────────────
      if (urls.length < maxResults && config.wikipediaTitle != null) {
        final wikiUrl = await _wikipediaImage(config.wikipediaTitle!);
        if (wikiUrl != null) _mergeUnique(urls, [wikiUrl], maxResults);
      }
    } else {
      // ── Unknown disease — generic text search fallback ────────────────────
      debugPrint('[DiseaseImageSearch] ℹ️ No config for "$diseaseName" — '
          'using generic iNaturalist text search.');
      final generic = await _iNatObservationsByText(
          query: '$diseaseName coffee plant', maxResults: maxResults);
      _mergeUnique(urls, generic, maxResults);

      // Wikipedia fallback using disease name directly
      if (urls.length < maxResults) {
        final wikiUrl = await _wikipediaImage(diseaseName);
        if (wikiUrl != null) _mergeUnique(urls, [wikiUrl], maxResults);
      }
    }

    debugPrint('[DiseaseImageSearch] ✅ Found ${urls.length} images for '
        '"$diseaseName" (stage="$stage")');
    _cache[cacheKey] = _CacheEntry(List.unmodifiable(urls), DateTime.now());
    return urls;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE 1a — iNaturalist Observations by taxon name
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> _iNatObservations({
    required String taxonName,
    required int    maxResults,
  }) async {
    try {
      final uri = Uri.parse('$_kINatBaseUrl/observations').replace(
        queryParameters: {
          'taxon_name'    : taxonName,
          'quality_grade' : 'research',
          'photos'        : 'true',
          'per_page'      : maxResults.clamp(1, 20).toString(),
          'order_by'      : 'votes',
          'order'         : 'desc',
          'photo_licensed': 'true',
        },
      );

      final response = await _client
          .get(uri, headers: {
            'Accept'    : 'application/json',
            'User-Agent': _kUserAgent,
          })
          .timeout(const Duration(seconds: 14));

      if (response.statusCode != 200) {
        debugPrint('[DiseaseImageSearch] iNat obs HTTP ${response.statusCode} '
            'for "$taxonName"');
        return [];
      }

      final json    = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>?) ?? [];
      final urls    = <String>[];

      for (final obs in results) {
        if (urls.length >= maxResults) break;
        final photos = (obs['photos'] as List<dynamic>?) ?? [];
        for (final photo in photos) {
          if (urls.length >= maxResults) break;
          final raw = photo['url'] as String?;
          if (raw == null || raw.isEmpty) continue;
          final med = raw.contains('/square.')
              ? raw.replaceFirst('/square.', '/medium.')
              : raw;
          if (med.startsWith('https://')) urls.add(med);
        }
      }

      debugPrint('[DiseaseImageSearch] iNat obs "$taxonName" → ${urls.length}');
      return urls;

    } catch (e) {
      debugPrint('[DiseaseImageSearch] iNat obs error "$taxonName": $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE 1b — iNaturalist Observations by plain text (symptom query)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> _iNatObservationsByText({
    required String query,
    required int    maxResults,
  }) async {
    try {
      final uri = Uri.parse('$_kINatBaseUrl/observations').replace(
        queryParameters: {
          'q'             : query,
          'quality_grade' : 'research',
          'photos'        : 'true',
          'per_page'      : maxResults.clamp(1, 10).toString(),
          'order_by'      : 'votes',
          'order'         : 'desc',
          'photo_licensed': 'true',
        },
      );

      final response = await _client
          .get(uri, headers: {
            'Accept'    : 'application/json',
            'User-Agent': _kUserAgent,
          })
          .timeout(const Duration(seconds: 14));

      if (response.statusCode != 200) {
        debugPrint('[DiseaseImageSearch] iNat text HTTP ${response.statusCode} '
            'for "$query"');
        return [];
      }

      final json    = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>?) ?? [];
      final urls    = <String>[];

      for (final obs in results) {
        if (urls.length >= maxResults) break;
        final photos = (obs['photos'] as List<dynamic>?) ?? [];
        for (final photo in photos) {
          if (urls.length >= maxResults) break;
          final raw = photo['url'] as String?;
          if (raw == null || raw.isEmpty) continue;
          final med = raw.contains('/square.')
              ? raw.replaceFirst('/square.', '/medium.')
              : raw;
          if (med.startsWith('https://')) urls.add(med);
        }
      }

      debugPrint('[DiseaseImageSearch] iNat text "$query" → ${urls.length}');
      return urls;

    } catch (e) {
      debugPrint('[DiseaseImageSearch] iNat text error "$query": $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE 2 — iNaturalist Taxa API (default representative photo)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> _iNatTaxa({
    required String query,
    required int    maxResults,
  }) async {
    try {
      final uri = Uri.parse('$_kINatBaseUrl/taxa').replace(
        queryParameters: {
          'q'       : query,
          'photos'  : 'true',
          'per_page': maxResults.clamp(1, 5).toString(),
        },
      );

      final response = await _client
          .get(uri, headers: {
            'Accept'    : 'application/json',
            'User-Agent': _kUserAgent,
          })
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint('[DiseaseImageSearch] iNat taxa HTTP ${response.statusCode} '
            'for "$query"');
        return [];
      }

      final json    = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>?) ?? [];
      final urls    = <String>[];

      for (final taxon in results) {
        if (urls.length >= maxResults) break;
        final dp = taxon['default_photo'] as Map<String, dynamic>?;
        if (dp == null) continue;
        String? url = (dp['medium_url'] ?? dp['url']) as String?;
        if (url == null || url.isEmpty) continue;
        if (url.contains('/square.')) {
          url = url.replaceFirst('/square.', '/medium.');
        }
        if (url.startsWith('https://')) urls.add(url);
      }

      debugPrint('[DiseaseImageSearch] iNat taxa "$query" → ${urls.length}');
      return urls;

    } catch (e) {
      debugPrint('[DiseaseImageSearch] iNat taxa error "$query": $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE 3 — Wikipedia page infobox image
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String?> _wikipediaImage(String articleTitle) async {
    try {
      final uri = Uri.parse(_kWikiBaseUrl).replace(
        queryParameters: {
          'action'     : 'query',
          'titles'     : articleTitle,
          'prop'       : 'pageimages',
          'format'     : 'json',
          'pithumbsize': '640',
          'pilicense'  : 'any',
          'redirects'  : '1',
        },
      );

      final response = await _client
          .get(uri, headers: {
            'Accept'    : 'application/json',
            'User-Agent': _kUserAgent,
          })
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint('[DiseaseImageSearch] Wikipedia HTTP ${response.statusCode} '
            'for "$articleTitle"');
        return null;
      }

      final json  = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = (json['query']?['pages'] as Map<String, dynamic>?) ?? {};

      for (final page in pages.values) {
        final source = page['thumbnail']?['source'] as String?;
        if (source == null || source.isEmpty) continue;
        if (!source.startsWith('https://')) continue;
        final larger = source.replaceAllMapped(
            RegExp(r'/(\d+)px-'), (_) => '/800px-');
        debugPrint('[DiseaseImageSearch] Wikipedia ✅ image found for "$articleTitle"');
        return larger;
      }
      return null;

    } catch (e) {
      debugPrint('[DiseaseImageSearch] Wikipedia error "$articleTitle": $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS + CACHE
  // ══════════════════════════════════════════════════════════════════════════

  static void _mergeUnique(List<String> dest, List<String> src, int max) {
    for (final url in src) {
      if (dest.length >= max) break;
      if (!dest.contains(url)) dest.add(url);
    }
  }

  static void clearCache() {
    _cache.clear();
    debugPrint('[DiseaseImageSearch] 🗑 Cache cleared.');
  }

  static int get cacheSize => _cache.length;

  static bool isCached({
    required String diseaseName,
    required String stage,
    int maxResults = 8,
  }) {
    final key   = '$diseaseName|$stage|$maxResults';
    final entry = _cache[key];
    if (entry == null) return false;
    return DateTime.now().difference(entry.cachedAt) < _cacheDuration;
  }
}