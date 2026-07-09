import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/config.dart';
import 'package:coffeecore/screens/Farm%20Mapping/service_exceptions.dart';

// ── EUDR Compliance Result ──────────────────────────────────
class EudrComplianceResult {
  final bool isCompliant;
  final bool wasForestedBefore2020;
  final double treeCoverPercent2000;
  final double treeCoverLossAreaHa;
  final double remainingTreeCoverPercent;
  final String explanation;
  final String recommendation;
  final String dataSource;
  final DateTime checkedAt;

  const EudrComplianceResult({
    required this.isCompliant,
    required this.wasForestedBefore2020,
    required this.treeCoverPercent2000,
    required this.treeCoverLossAreaHa,
    required this.remainingTreeCoverPercent,
    required this.explanation,
    required this.recommendation,
    required this.dataSource,
    required this.checkedAt,
  });
}

class EudrComplianceService {
  final Logger _log = Logger(printer: PrettyPrinter());

  // GFW's Data API doesn't send CORS headers, so browser (web) builds route
  // through a Cloud Functions proxy that fetches server-side instead.
  // Native builds (Android/iOS/desktop) aren't subject to browser CORS and
  // call GFW directly.
  static const String _gfwBase = kIsWeb
      ? 'https://us-central1-coffeecore-7111a.cloudfunctions.net/gfwProxy'
      : 'https://data-api.globalforestwatch.org';
  static const String _gfwApiKey = Config.gfwApiKey;
  static const double _forestThresholdPercent = 30.0;
  static const Duration _timeout = Duration(seconds: 25);

  bool _isPlaceholderKey(String key) => key.startsWith('YOUR_') || key.isEmpty;

  /// Runs the full compliance check for a farm polygon.
  Future<EudrComplianceResult> checkFarmCompliance({
    required List<LatLng> coordinates,
    required double areaHectares,
  }) async {
    if (_isPlaceholderKey(_gfwApiKey)) {
      _log.w(
        'EudrComplianceService.checkFarmCompliance: '
        'Global Forest Watch API key not configured',
      );
      throw const ServiceUnavailableException(
        'EUDR deforestation checks are not configured for this app yet.',
      );
    }
    if (areaHectares <= 0.0) {
      throw const ServiceUnavailableException(
        "This farm's mapped area is too small or wasn't recorded correctly "
        'to run a reliable EUDR analysis. Please re-draw the farm boundary '
        'on the map and try again.',
      );
    }
    try {
      _log.i(
        'EUDR: Starting compliance check for polygon '
        '(${coordinates.length} pts, ~${areaHectares.toStringAsFixed(2)} ha)',
      );

      // 1. Register polygon with GFW geostore
      final geostoreId = await _createGeostore(coordinates);
      if (geostoreId == null) {
        throw const ServiceUnavailableException(
          'Could not register this farm boundary with Global Forest Watch. Please try again shortly.',
        );
      }
      _log.i('EUDR: GFW geostore created: $geostoreId');

      // 2. Query Hansen UMD baseline forest extent (year-2000 tree cover)
      //    and cumulative tree-cover loss before the EUDR 2020 cutoff, both
      //    via the Data API's SQL query interface (the old REST analysis
      //    endpoints under /umd/tree-cover-loss no longer exist and 404).
      final forestAreaHa = await _queryForestAreaHa(geostoreId);
      final lossBefore2020 = await _queryLossBeforeYear(geostoreId, 2020);

      final treeCover2000 =
          (forestAreaHa / areaHectares * 100).clamp(0.0, 100.0);

      // 4. Compliance interpretation
      final lossPercent = (lossBefore2020 / areaHectares * 100).clamp(0, 100);
      final remainingCover = (treeCover2000 - lossPercent).clamp(0.0, 100.0);
      final wasForested = treeCover2000 >= _forestThresholdPercent;
      final isCompliant = !wasForested;

      String explanation;
      String recommendation;

      if (wasForested) {
        explanation =
            'Historical satellite analysis (Hansen-UMD / Global Forest Watch) shows '
            'this area had ${treeCover2000.toStringAsFixed(1)}% tree cover in the '
            'year 2000 baseline, classifying it as forested land before 2020. '
            '${lossBefore2020 > 0.01 ? 'Approximately ${lossBefore2020.toStringAsFixed(2)} ha of tree cover was lost before 2020. ' : ''}'
            'Under EUDR (EU Deforestation Regulation), products from land that was '
            'forest before 2020 and later converted to agriculture are blocked from '
            'EU international markets. This farm is flagged as '
            'POTENTIALLY NON-COMPLIANT.';

        recommendation =
            'This farmer requires additional EUDR due-diligence documentation. '
            'Request proof that any forest conversion occurred before 31 December 2020 '
            'or that the conversion was legal under applicable national laws. '
            'Without documented evidence, coffee from this farm may be rejected by EU buyers.';
      } else {
        explanation =
            'Historical satellite analysis (Hansen-UMD / Global Forest Watch) shows '
            'this area had only ${treeCover2000.toStringAsFixed(1)}% tree cover in the '
            'year 2000 baseline, indicating it was not dense forest before 2020. '
            'The land appears to have been non-forest, grassland, or already under '
            'cultivation prior to the EUDR regulatory cutoff. This farm is flagged as '
            'COMPLIANT for preliminary EUDR screening.';

        recommendation =
            'This farmer meets the preliminary EUDR forest-screening criteria. '
            'Proceed with standard supply-chain due diligence. Maintain records of '
            'this compliance check for audit and traceability purposes.';
      }

      return EudrComplianceResult(
        isCompliant: isCompliant,
        wasForestedBefore2020: wasForested,
        treeCoverPercent2000: treeCover2000,
        treeCoverLossAreaHa: lossBefore2020,
        remainingTreeCoverPercent: remainingCover,
        explanation: explanation,
        recommendation: recommendation,
        dataSource:
            'Global Forest Watch (GFW) – Hansen-UMD Global Forest Change',
        checkedAt: DateTime.now(),
      );
    } on ServiceUnavailableException {
      rethrow;
    } catch (e, st) {
      _log.e('EUDR compliance check failed: $e', stackTrace: st);
      throw ServiceUnavailableException(
        isNetworkError(e)
            ? 'Could not reach Global Forest Watch — check your internet connection.'
            : 'Something went wrong running the EUDR deforestation check.',
        isNetworkError: isNetworkError(e),
      );
    }
  }

  // ── Private helpers ─────────────────────────────────────────

  Future<String?> _createGeostore(List<LatLng> coordinates) async {
    final ring = coordinates.map((c) => [c.longitude, c.latitude]).toList();
    if (ring.isNotEmpty &&
        (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
      ring.add(ring.first);
    }

    final body = jsonEncode({
      'geojson': {
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [ring],
        },
      },
    });

    final res = await http
        .post(
          Uri.parse('$_gfwBase/geostore'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': _gfwApiKey,
          },
          body: body,
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log.w('GFW geostore creation failed: ${res.statusCode} ${res.body}');
      throw ServiceUnavailableException(
        extractApiMessage(res.body) ??
            'Could not register this farm boundary with Global Forest Watch (HTTP ${res.statusCode}).',
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['data']?['id'] as String?;
  }

  /// Baseline forested area (ha) within the geostore at >=30% canopy density
  /// in the year-2000 UMD baseline.
  Future<double> _queryForestAreaHa(String geostoreId) async {
    final rows = await _runSqlQuery(
      dataset: 'umd_tree_cover_density_2000',
      sql: 'SELECT SUM(area__ha) as forest_area FROM results '
          'WHERE umd_tree_cover_density_2000__threshold >= 30',
      geostoreId: geostoreId,
    );
    if (rows.isEmpty) return 0.0;
    return (rows.first['forest_area'] as num? ?? 0).toDouble();
  }

  /// Cumulative Hansen/UMD tree-cover loss (ha) within the geostore, on
  /// land that was >=30% canopy density in 2000, lost strictly before
  /// [beforeYear].
  Future<double> _queryLossBeforeYear(String geostoreId, int beforeYear) async {
    final rows = await _runSqlQuery(
      dataset: 'umd_tree_cover_loss',
      sql: 'SELECT SUM(area__ha) as loss_area FROM results '
          'WHERE umd_tree_cover_density_2000__threshold >= 30 '
          'AND umd_tree_cover_loss__year < $beforeYear',
      geostoreId: geostoreId,
    );
    if (rows.isEmpty) return 0.0;
    return (rows.first['loss_area'] as num? ?? 0).toDouble();
  }

  /// Runs a read-only SQL query against a GFW Data API dataset, scoped to
  /// a previously-created geostore (see /geostore in [_createGeostore]).
  Future<List<Map<String, dynamic>>> _runSqlQuery({
    required String dataset,
    required String sql,
    required String geostoreId,
  }) async {
    final uri = Uri.parse('$_gfwBase/dataset/$dataset/latest/query/json')
        .replace(queryParameters: {
      'sql': sql,
      'geostore_id': geostoreId,
      'geostore_origin': 'rw',
    });
    final res = await http
        .get(uri, headers: {'x-api-key': _gfwApiKey}).timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log.w('GFW $dataset query failed: ${res.statusCode} ${res.body}');
      throw ServiceUnavailableException(
        extractApiMessage(res.body) ??
            'Global Forest Watch returned an error (HTTP ${res.statusCode}).',
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = data['data'] as List<dynamic>?;
    return rows?.cast<Map<String, dynamic>>() ?? [];
  }

  // ── Simulated result for UI testing (no API key needed) ─────
  EudrComplianceResult simulatedResult({bool compliant = false}) {
    final treeCover = compliant ? 12.5 : 78.3;
    final wasForested = treeCover >= _forestThresholdPercent;
    return EudrComplianceResult(
      isCompliant: !wasForested,
      wasForestedBefore2020: wasForested,
      treeCoverPercent2000: treeCover,
      treeCoverLossAreaHa: wasForested ? 1.45 : 0.0,
      remainingTreeCoverPercent: wasForested ? 65.0 : 10.0,
      explanation: wasForested
          ? 'SIMULATION: This area had 78.3% tree cover in 2000 (forested). '
              'Flagged as NON-COMPLIANT under EUDR.'
          : 'SIMULATION: This area had 12.5% tree cover in 2000 (non-forest). '
              'Flagged as COMPLIANT under EUDR.',
      recommendation: wasForested
          ? 'SIMULATION: Request pre-2020 land-use documentation.'
          : 'SIMULATION: Proceed with standard due diligence.',
      dataSource: 'SIMULATED – Replace with real GFW API call',
      checkedAt: DateTime.now(),
    );
  }
}
