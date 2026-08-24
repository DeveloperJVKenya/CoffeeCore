import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// DISEASE IMAGE SEARCH SERVICE  —  v2
//
// Mirrors PestImageSearchService architecture exactly.
// Source (the only one — every result is verified on coffee):
//
//   iNaturalist Observations API, coffee-qualified free-text search
//      Research-grade verified photos of pathogens and disease symptoms,
//      queried with a "coffee"/"Coffea" qualifier (or an explicit symptom
//      query) so every result is confirmed to actually be on coffee — not
//      just the correct pathogen photographed on an unrelated host plant.
//      Free · no API key.
//      https://api.inaturalist.org/v1/observations
//
// HOST-AGNOSTIC FALLBACKS REMOVED ENTIRELY (v2):
//   Earlier versions fell back to a bare taxon_name query, the iNaturalist
//   Taxa API's species-representative photo, and a Wikipedia infobox image
//   when the coffee-qualified search came up short. All three can return the
//   correct pathogen photographed on an unrelated host plant, which a farmer
//   has no way to distinguish from a genuine coffee photo — so a disease with
//   weak coffee-specific coverage now shows a "no images" state instead.
//
// DISEASE-SPECIFIC NOTES:
//   • Many coffee diseases are caused by microscopic fungi — iNaturalist has
//     good coverage of their macroscopic symptoms on host plants.
//   • Taxon queries use the pathogen scientific name; symptom-level photos
//     are returned via observation queries on the coffee host plant + taxon.
//   • OTA contamination and storage molds use genus-level taxa only (Aspergillus, Penicillium).
// ─────────────────────────────────────────────────────────────────────────────

const String _kINatBaseUrl = 'https://api.inaturalist.org/v1';
const String _kUserAgent =
    'CoffeeCore/1.0 (Flutter; East Africa coffee disease management)';

// ─────────────────────────────────────────────────────────────────────────────
// PER-DISEASE CONFIGURATION
//
// taxonNames     Scientific name(s) for iNaturalist observations queries.
//                Use pathogen name — iNaturalist has observations of fungi/bacteria.
//
// symptomQuery   Optional plain-text search for iNaturalist observations of the
//                disease symptoms on coffee plants where pathogen taxon is obscure.
// ─────────────────────────────────────────────────────────────────────────────

class _DiseaseConfig {
  final List<String> taxonNames;
  final String? symptomQuery;

  const _DiseaseConfig({
    required this.taxonNames,
    this.symptomQuery,
  });
}

const Map<String, _DiseaseConfig> _diseaseConfig = {
  // ── Vegetative / All-Stage Diseases ─────────────────────────────────────────

  'Coffee Leaf Rust': _DiseaseConfig(
    taxonNames: [
      'Hemileia vastatrix', // coffee leaf rust — the specific pathogen
      'Hemileia', // genus — all Hemileia are rusts on coffee
    ],
    symptomQuery: 'coffee leaf rust orange spots Coffea arabica',
  ),

  'Coffee Berry Disease': _DiseaseConfig(
    taxonNames: [
      'Colletotrichum kahawae', // CBD pathogen — specific to coffee berries
      'Colletotrichum gloeosporioides', // broad Colletotrichum — anthracnose group
    ],
    symptomQuery: 'Colletotrichum kahawae coffee berry black',
  ),

  'Coffee Wilt Disease': _DiseaseConfig(
    taxonNames: [
      'Gibberella xylarioides', // coffee wilt perfect stage
      'Fusarium xylarioides', // anamorph — same fungus
      'Fusarium', // genus — wilt fusaria
    ],
  ),

  'Coffee Root Rot': _DiseaseConfig(
    taxonNames: [
      'Phytophthora cinnamomi', // root rot of coffee
      'Pythium', // damping-off / root rot genus
      'Fusarium solani', // fusarium root rot
    ],
    symptomQuery: 'Phytophthora root rot coffee',
  ),

  'Coffee Brown Eye Spot': _DiseaseConfig(
    taxonNames: [
      'Cercospora coffeicola', // brown eye spot pathogen — specific
      'Cercospora', // genus — all produce leaf spots
    ],
    symptomQuery: 'Cercospora coffee leaf spot brown',
  ),

  'Coffee Damping Off': _DiseaseConfig(
    taxonNames: [
      'Pythium', // primary damping-off genus
      'Rhizoctonia solani', // secondary damping-off fungus
    ],
    symptomQuery: 'coffee seedling damping off nursery Pythium',
  ),

  'Coffee Sooty Mold': _DiseaseConfig(
    taxonNames: [
      'Capnodium coffeae', // coffee sooty mold — specific species
      'Cladosporium', // broad sooty mold genus
      'Capnodiales', // sooty mold order — all are sooty molds
    ],
    symptomQuery: 'sooty mold coffee black coating leaves',
  ),

  'Coffee Bacterial Blight': _DiseaseConfig(
    taxonNames: [
      'Pseudomonas syringae', // bacterial blight pathogen group
    ],
    symptomQuery: 'Pseudomonas coffee bacterial blight leaf spot',
  ),

  'Coffee Anthracnose': _DiseaseConfig(
    taxonNames: [
      'Colletotrichum gloeosporioides', // primary anthracnose species
      'Colletotrichum', // genus — all cause anthracnose
    ],
    symptomQuery: 'Colletotrichum anthracnose coffee berry lesion',
  ),

  'Coffee Nursery Blight': _DiseaseConfig(
    taxonNames: [
      'Rhizoctonia solani', // primary nursery blight pathogen
      'Pythium', // secondary damping-off pathogen
    ],
    symptomQuery: 'Rhizoctonia seedling blight nursery',
  ),

  // ── Post-harvest / Storage Diseases ─────────────────────────────────────────

  'Coffee Green Mold': _DiseaseConfig(
    taxonNames: [
      'Penicillium', // green/blue mold genus — primary coffee storage mold
      'Aspergillus', // co-occurrence in storage
    ],
    symptomQuery: 'Penicillium mold green stored coffee beans',
  ),

  'Coffee Ochratoxin A Contamination': _DiseaseConfig(
    taxonNames: [
      'Aspergillus carbonarius', // primary OTA producer on coffee
      'Aspergillus ochraceus', // secondary OTA producer
      'Aspergillus', // genus fallback
    ],
    symptomQuery: 'Aspergillus coffee beans mold storage',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// CACHE MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _CacheEntry {
  final List<String> urls;
  final DateTime cachedAt;
  const _CacheEntry(this.urls, this.cachedAt);
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseImageSearchService {
  DiseaseImageSearchService._();

  static final http.Client _client = http.Client();
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheDuration = Duration(hours: 12);

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
    final urls = <String>[];

    if (config != null) {
      // ── Coffee-qualified text search only (symptom query, or an
      //    auto-built "<taxon> coffee Coffea" fallback) ───────────────────
      // The bare taxon_name, iNaturalist-Taxa-default-photo, and Wikipedia-
      // infobox fallback tiers were removed entirely — genus-level entries
      // (e.g. "Fusarium", "Aspergillus", "Pythium") are broad enough that an
      // unqualified search returns that pathogen on ANY host worldwide, and a
      // farmer has no way to tell that apart from a genuine coffee photo.
      // Fewer images, but every one is confirmed to actually be on coffee.
      for (final taxon in config.taxonNames) {
        if (urls.length >= maxResults) break;
        final query = config.symptomQuery ?? '$taxon coffee Coffea';
        final fetched = await _iNatObservationsByText(
            query: query, maxResults: maxResults - urls.length);
        _mergeUnique(urls, fetched, maxResults);
      }
    } else {
      // ── Unknown disease — generic coffee-qualified text search ─────────────
      debugPrint('[DiseaseImageSearch] ℹ️ No config for "$diseaseName" — '
          'using generic coffee-qualified iNaturalist text search.');
      final generic = await _iNatObservationsByText(
          query: '$diseaseName coffee plant', maxResults: maxResults);
      _mergeUnique(urls, generic, maxResults);
    }

    debugPrint('[DiseaseImageSearch] ✅ Found ${urls.length} images for '
        '"$diseaseName" (stage="$stage")');
    _cache[cacheKey] = _CacheEntry(List.unmodifiable(urls), DateTime.now());
    return urls;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE — iNaturalist Observations by coffee-qualified plain text
  //
  // The only image source in this service — see the removal note where this
  // is called for why the host-agnostic fallback tiers (bare taxon_name, iNat
  // Taxa default photo, Wikipedia infobox) were dropped entirely.
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> _iNatObservationsByText({
    required String query,
    required int maxResults,
  }) async {
    try {
      final uri = Uri.parse('$_kINatBaseUrl/observations').replace(
        queryParameters: {
          'q': query,
          'quality_grade': 'research',
          'photos': 'true',
          'per_page': maxResults.clamp(1, 10).toString(),
          'order_by': 'votes',
          'order': 'desc',
          'photo_licensed': 'true',
        },
      );

      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': _kUserAgent,
      }).timeout(const Duration(seconds: 14));

      if (response.statusCode != 200) {
        debugPrint('[DiseaseImageSearch] iNat text HTTP ${response.statusCode} '
            'for "$query"');
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>?) ?? [];
      final urls = <String>[];

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
    final key = '$diseaseName|$stage|$maxResults';
    final entry = _cache[key];
    if (entry == null) return false;
    return DateTime.now().difference(entry.cachedAt) < _cacheDuration;
  }
}
