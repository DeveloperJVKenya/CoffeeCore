import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';

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

  static const String _gfwBase = 'https://data-api.globalforestwatch.org';
  static const double _forestThresholdPercent = 30.0;
  static const Duration _timeout = Duration(seconds: 25);

  /// Runs the full compliance check for a farm polygon.
  Future<EudrComplianceResult> checkFarmCompliance({
    required List<LatLng> coordinates,
    required double areaHectares,
  }) async {
    try {
      _log.i(
        'EUDR: Starting compliance check for polygon '
        '(${coordinates.length} pts, ~${areaHectares.toStringAsFixed(2)} ha)',
      );

      // 1. Register polygon with GFW geostore
      final geostoreId = await _createGeostore(coordinates);
      if (geostoreId == null) {
        throw Exception('Failed to register polygon with GFW geostore');
      }
      _log.i('EUDR: GFW geostore created: $geostoreId');

      // 2. Query Hansen UMD tree-cover-loss analysis
      final analysis = await _queryTreeCoverLoss(geostoreId);

      // 3. Parse response (defensive – GFW API v2 structure)
      final treeCover2000 =
          (analysis['treeCover'] as num? ??
           analysis['tree_cover_2000'] as num? ??
           analysis['treeCover2000'] as num? ?? 0).toDouble();

      // Loss may come as an array by year or as a total scalar
      final lossList = (analysis['loss'] as List<dynamic>?) ??
                       (analysis['lossByYear'] as List<dynamic>?) ?? [];

      double lossBefore2020 = 0.0;
      if (lossList.isNotEmpty && lossList.first is Map) {
        for (final item in lossList) {
          final year = (item['year'] as num? ?? 0).toInt();
          if (year < 2020) {
            lossBefore2020 += (item['area'] as num? ?? item['loss'] as num? ?? 0).toDouble();
          }
        }
      } else if (analysis['loss'] is num) {
        // Fallback: total loss scalar (less ideal)
        lossBefore2020 = (analysis['loss'] as num).toDouble();
      }

      // 4. Compliance interpretation
      final lossPercent = areaHectares > 0
          ? (lossBefore2020 / areaHectares * 100).clamp(0, 100)
          : 0.0;
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
        dataSource: 'Global Forest Watch (GFW) – Hansen-UMD Global Forest Change',
        checkedAt: DateTime.now(),
      );
    } catch (e, st) {
      _log.e('EUDR compliance check failed: $e', stackTrace: st);
      rethrow;
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
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log.w('GFW geostore creation failed: ${res.statusCode} ${res.body}');
      return null;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['data']?['id'] as String?;
  }

  Future<Map<String, dynamic>> _queryTreeCoverLoss(String geostoreId) async {
    final uri = Uri.parse(
      '$_gfwBase/umd/tree-cover-loss?geostore=$geostoreId&thresh=30',
    );
    final res = await http.get(uri).timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'GFW tree-cover-loss query failed: ${res.statusCode} ${res.body}',
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['data']?['attributes'] as Map<String, dynamic>? ?? {};
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