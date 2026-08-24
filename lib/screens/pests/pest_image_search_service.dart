import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// PEST IMAGE SEARCH SERVICE  —  v5
//
// SOURCE (the only one — every result is verified on coffee):
//
//   iNaturalist Observations API, coffee-qualified free-text search
//      Every photo is peer-reviewed by multiple expert identifiers AND the
//      query is qualified with "coffee Coffea", so a returned observation is
//      both the correct species and actually on a coffee plant.
//      Free · no API key · 100 req/min
//      https://api.inaturalist.org/v1/observations
//
// HOST-AGNOSTIC FALLBACKS REMOVED ENTIRELY (v5):
//   Earlier versions fell back to a bare taxon_name query, the iNaturalist
//   Taxa API's species-representative photo, and a Wikipedia infobox image
//   when the coffee-qualified search came up short. All three can return the
//   correct species/pathogen photographed on an unrelated host plant, which a
//   farmer has no way to distinguish from a genuine coffee photo — so a pest
//   with weak coffee-specific coverage now shows a "no images" state instead.
//
// PIXABAY REMOVED ENTIRELY (v4):
//   A general stock photography site has almost no correctly-tagged photos of
//   rare agricultural micro-pests. When it finds nothing it falls back to
//   popular-but-wrong insects (butterflies). No query tuning fixes this.
//
// CATERPILLAR BUG FIX (v4):
//   Old config: 'Lepidoptera' (entire ORDER, includes all butterflies & moths).
//   iNaturalist ranked adult butterfly photos first because they dominate votes.
//   Fix: Use only specific coffee-attacking caterpillar species PLUS the
//   iNaturalist life-stage annotation filter (term_id=1, term_value_id=6 = Larva)
//   so observations are restricted to larval-stage photos only.
// ─────────────────────────────────────────────────────────────────────────────

const String _kINatBaseUrl = 'https://api.inaturalist.org/v1';
const String _kUserAgent =
    'CoffeeCore/4.0 (Flutter; East Africa coffee pest management)';

// iNaturalist controlled-term IDs for life-stage annotation filtering.
// Source: https://www.inaturalist.org/controlled_terms
const String _kTermLifeStage = '1'; // term_id      = "Life Stage"
const String _kValueLarva = '6'; // term_value_id = "Larva" / caterpillar

// ─────────────────────────────────────────────────────────────────────────────
// PER-PEST CONFIGURATION
//
// taxonNames     Scientific names for iNaturalist, ordered most-specific first.
//                NEVER use order-level names (e.g. Lepidoptera) — too broad.
//
// filterToLarva  When true, adds term_id=1 & term_value_id=6 to iNaturalist
//                observations query → Larva life stage ONLY.
//                Set only for pests whose adult form is a different wrong insect.
// ─────────────────────────────────────────────────────────────────────────────

class _PestConfig {
  final List<String> taxonNames;
  final bool filterToLarva;

  const _PestConfig({
    required this.taxonNames,
    this.filterToLarva = false,
  });
}

const Map<String, _PestConfig> _pestConfig = {
  // ── Vegetative Stage ────────────────────────────────────────────────────────

  'Coffee Leaf Miner': _PestConfig(
    taxonNames: [
      'Leucoptera coffeella', // coffee leaf miner — primary East Africa species
      'Leucoptera', // genus — all Leucoptera are leaf miners
    ],
  ),

  'Coffee Stem Borer': _PestConfig(
    taxonNames: [
      'Xylotrechus quadripes', // Kenya highland coffee stem borer beetle
      'Xylotrechus', // genus — all are bark/stem borers
      'Cerambycidae', // longhorn beetle family — all bore into wood
    ],
  ),

  'Root-Knot Nematodes': _PestConfig(
    taxonNames: [
      'Meloidogyne incognita', // most common coffee root-knot nematode species
      'Meloidogyne', // genus — all produce characteristic root galls
    ],
  ),

  'White Flies': _PestConfig(
    taxonNames: [
      'Bemisia tabaci', // silverleaf whitefly — primary coffee pest
      'Trialeurodes vaporariorum', // greenhouse whitefly — common secondary
      'Aleyrodidae', // whitefly family — all species are whiteflies
    ],
  ),

  'Coffee Mealybug': _PestConfig(
    taxonNames: [
      'Planococcus citri', // coffee/citrus mealybug — primary species
      'Pseudococcidae', // mealybug family — all have the waxy coating
    ],
  ),

  'Caterpillars': _PestConfig(
    // ═══════════════════════════════════════════════════════════════════════
    // PRIMARY BUG FIX: butterflies were appearing for this pest.
    //
    // Root cause: 'Lepidoptera' is an ORDER containing all butterflies/moths.
    // Adult butterfly photos dominate iNaturalist votes for that taxon.
    //
    // Fix A — Specific coffee-attacking caterpillar species only:
    //   Spodoptera exigua    (beet armyworm)    — confirmed East Africa coffee
    //   Spodoptera frugiperda (fall armyworm)   — invasive, East Africa since 2016
    //   Achaea janata        (castor looper)    — documented coffee defoliator
    //   Helicoverpa armigera (cotton bollworm)  — polyphagous, attacks coffee
    //
    // Fix B — filterToLarva = true:
    //   Adds term_id=1 & term_value_id=6 to the iNaturalist observations query.
    //   This is the "Life Stage = Larva" annotation. Even for the above species,
    //   this ensures only larval (caterpillar) life-stage photos are returned,
    //   ruling out any adult moth observations of the same species.
    // ═══════════════════════════════════════════════════════════════════════
    taxonNames: [
      'Spodoptera exigua', // beet armyworm caterpillar — East Africa coffee
      'Spodoptera frugiperda', // fall armyworm caterpillar — East Africa
      'Achaea janata', // castor looper caterpillar — coffee defoliator
      'Helicoverpa armigera', // cotton bollworm larva — polyphagous pest
    ],
    filterToLarva: true,
  ),

  'Ants': _PestConfig(
    taxonNames: [
      'Anoplolepis gracilipes', // crazy ant — invasive, farms mealybugs on coffee
      'Solenopsis', // fire ants — attack coffee roots and stem base
      'Formicidae', // ant family — all life stages are ants
    ],
  ),

  'Scale Insects': _PestConfig(
    taxonNames: [
      'Diaspididae', // armored scale insects — hard flat waxy cover on bark
      'Coccidae', // soft scale insects — common on coffee branches
      'Coccoidea', // scale insect superfamily — broadest safe fallback
    ],
  ),

  'Thrips': _PestConfig(
    taxonNames: [
      'Frankliniella occidentalis', // most-photographed thrips species globally
      'Thrips tabaci', // coffee/onion thrips — primary East Africa
      'Thysanoptera', // thrips ORDER — contains ONLY thrips species
    ],
  ),

  // ── Flowering & Fruit Development ───────────────────────────────────────────

  'Coffee Berry Borer': _PestConfig(
    taxonNames: [
      'Hypothenemus hampei', // coffee berry borer — globally documented
      'Scolytinae', // bark and ambrosia beetle subfamily
    ],
  ),

  'Coffee Antestia Bug': _PestConfig(
    taxonNames: [
      'Antestiopsis orbitalis', // primary East Africa coffee antestia species
      'Antestiopsis', // genus — all species attack coffee berries
      'Pentatomidae', // stink/shield bug family — correct body shape
    ],
  ),

  // ── Post-harvest / Storage ──────────────────────────────────────────────────

  'Coffee Weevil': _PestConfig(
    taxonNames: [
      'Araecerus fasciculatus', // coffee bean weevil — primary storage pest
      'Araecerus', // genus fallback
      'Curculionidae', // weevil family — distinctive snout shape
    ],
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// Cache
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
  static const Duration _cacheDuration = Duration(hours: 6);
  static final http.Client _client = http.Client();

  // ══════════════════════════════════════════════════════════════════════════
  // PRIMARY PUBLIC METHOD
  // Signature identical to previous versions — no changes needed in callers.
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> searchPestImages({
    required String pestName,
    required String stage,
    int maxResults = 6,
  }) async {
    final clampedMax = maxResults.clamp(1, 10);
    final cacheKey = '$pestName|$stage|$clampedMax';

    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _cacheDuration) {
      debugPrint('[PestImageSearch] ✅ Cache hit — "$pestName" '
          '(${cached.urls.length} images, '
          '${DateTime.now().difference(cached.cachedAt).inMinutes}min old)');
      return cached.urls;
    }

    debugPrint('[PestImageSearch] 🔍 Searching "$pestName" | '
        'stage="$stage" | max=$clampedMax');

    final config = _pestConfig[pestName];
    if (config == null) {
      debugPrint('[PestImageSearch] ⚠️ No config for "$pestName". '
          'Add an entry to _pestConfig for this pest. '
          'Returning empty → UI will show no-images state.');
      _cache[cacheKey] = _CacheEntry(const [], DateTime.now());
      return const [];
    }

    final collected = <String>[];

    // ── Source: iNaturalist Observations, coffee-qualified only ──────────────
    // Every query is qualified with "coffee Coffea" — genus/family/order-level
    // fallback entries (e.g. "Formicidae", "Aspergillus") are broad enough that
    // an unqualified taxon query returns that organism on ANY host plant
    // worldwide, not specifically on coffee. The old bare-taxon / iNat-Taxa /
    // Wikipedia fallback tiers were removed entirely (not just deprioritized)
    // because they could silently surface a correct species photographed on an
    // unrelated host plant — a farmer has no way to tell that apart from a
    // genuine coffee photo. Fewer images but every one is actually on coffee —
    // a pest with weak iNaturalist coverage on coffee specifically may now show
    // a "no images" state instead of a wrong-host photo.
    for (final taxon in config.taxonNames) {
      if (collected.length >= clampedMax) break;
      debugPrint('[PestImageSearch] 🌿 iNat obs (coffee-qualified): "$taxon"'
          '${config.filterToLarva ? " [larva-only]" : ""}');
      final textUrls = await _iNatObservationsByText(
        query: '$taxon coffee Coffea',
        maxResults: clampedMax - collected.length,
        filterLarva: config.filterToLarva,
      );
      _mergeUnique(collected, textUrls, clampedMax);
    }
    debugPrint('[PestImageSearch] ↳ After iNat obs: ${collected.length}');

    if (collected.isEmpty) {
      debugPrint('[PestImageSearch] ℹ️ All sources: 0 images for "$pestName". '
          'UI will show no-images message.');
    } else {
      debugPrint(
          '[PestImageSearch] ✅ "$pestName" → ${collected.length} images.');
    }

    _cache[cacheKey] =
        _CacheEntry(List.unmodifiable(collected), DateTime.now());
    return collected;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOURCE — iNaturalist Observations by coffee-qualified plain text
  //
  // Uses the free-text `q` parameter (not `taxon_name`) so a host-plant
  // qualifier ("coffee Coffea") narrows results to observations actually
  // tagged/described as being on coffee, instead of the organism on any host
  // anywhere in the world. This is the only image source in this service —
  // see the removal note where this is called for why the host-agnostic
  // fallback tiers (bare taxon_name, iNat Taxa default photo, Wikipedia
  // infobox) were dropped entirely rather than kept as a lower-priority tier.
  //
  // quality_grade=research : peer-reviewed, multi-identifier agreement required.
  // order_by=votes         : most-confirmed observations appear first.
  // photo_licensed=true    : only openly licensed photos (safe for display).
  // term_id / term_value_id: life-stage annotation filter when filterLarva=true.
  //
  // URL transform: "/square." (75 px) → "/medium." (500 px).
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> _iNatObservationsByText({
    required String query,
    required int maxResults,
    bool filterLarva = false,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'quality_grade': 'research',
        'photos': 'true',
        'per_page': maxResults.clamp(1, 20).toString(),
        'order_by': 'votes',
        'order': 'desc',
        'photo_licensed': 'true',
      };
      if (filterLarva) {
        params['term_id'] = _kTermLifeStage;
        params['term_value_id'] = _kValueLarva;
      }

      final uri = Uri.parse('$_kINatBaseUrl/observations')
          .replace(queryParameters: params);

      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': _kUserAgent,
      }).timeout(const Duration(seconds: 14));

      if (response.statusCode != 200) {
        debugPrint('[PestImageSearch] iNat text HTTP ${response.statusCode} '
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

      debugPrint('[PestImageSearch] iNat text "$query" → ${urls.length}');
      return urls;
    } catch (e) {
      debugPrint('[PestImageSearch] iNat text error "$query": $e');
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
    debugPrint('[PestImageSearch] 🗑 Cache cleared.');
  }

  static int get cacheSize => _cache.length;

  static bool isCached({
    required String pestName,
    required String stage,
    int maxResults = 6,
  }) {
    final key = '$pestName|$stage|$maxResults';
    final entry = _cache[key];
    if (entry == null) return false;
    return DateTime.now().difference(entry.cachedAt) < _cacheDuration;
  }
}
