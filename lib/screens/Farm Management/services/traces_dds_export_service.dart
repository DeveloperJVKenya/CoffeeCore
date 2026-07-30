import 'package:coffeecore/screens/Farm%20Management/models/dds_export_batch_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';

/// Shapes farm plots into the GeoJSON shape the EUDR Information System
/// (TRACES) expects for a Due Diligence Statement — WGS-84 (EPSG:4326), a
/// Point for plots <4 ha or a Polygon for plots >=4 ha (per the
/// regulation's own geolocation rule — see FarmPolygon.requiresPolygonGeolocation),
/// and per-plot DDS-relevant properties. This is JV Almacis's evidence
/// *handoff* to an exporter — nothing here is ever transmitted to TRACES
/// by JV Almacis itself; the exporter takes this output and uses it in
/// their own filing, on their own TRACES account.
///
/// This is deliberately a *different* shape from geojson_export_service.dart,
/// which exports for sharing sample AOIs with satellite-imagery partners
/// (ground-truth labels, no operator/HS-code/DDS fields at all) — the two
/// serve unrelated purposes and shouldn't be merged.
///
/// UNVERIFIED CAVEAT: field names/structure below follow the publicly
/// documented DDS requirements (geolocation, product HS code, deforestation-
/// free confirmation, upstream references) as understood from Planetek's
/// tutorial and public EUDR/TRACES documentation — NOT the authoritative
/// CIRCABC API spec, which only the exporter (as a registered TRACES
/// operator) can access. Treat this as the best current draft; the
/// exporter's own compliance team should reconcile it against their real
/// TRACES filing requirements before relying on it.
class TracesDdsExportService {
  static const String _eudrBaselineDate = '2020-12-31';

  /// Builds one GeoJSON Feature for a single plot.
  static Map<String, dynamic> _toFeature(FarmPolygon farm) {
    final planetek = farm.planetekAnalysis;

    final geometry = farm.requiresPolygonGeolocation
        ? {
            'type': 'Polygon',
            'coordinates': [_closedRing(farm)],
          }
        : {
            'type': 'Point',
            'coordinates': _pointCoordinate(farm),
          };

    return {
      'type': 'Feature',
      'properties': {
        'plot_id': farm.farmId,
        'plot_name': farm.farmName,
        'area_ha': double.parse(farm.areaHectares.toStringAsFixed(4)),
        'geolocation_type':
            farm.requiresPolygonGeolocation ? 'polygon' : 'point',
        'deforestation_baseline': _eudrBaselineDate,
        'deforestation_free': planetek?.deforestationCertified,
        'deforestation_signature_verified':
            planetek?.signatureVerified ?? false,
        'deforestation_algorithm_version': planetek?.algorithmVersion,
        'deforestation_checked_at': planetek?.checkedAt.toIso8601String(),
        'boundary_overlap_flagged': farm.hasBoundaryOverlap,
      },
      'geometry': geometry,
    };
  }

  static List<double> _pointCoordinate(FarmPolygon farm) {
    final c = farm.center;
    return [c.longitude, c.latitude];
  }

  static List<List<double>> _closedRing(FarmPolygon farm) {
    final ring =
        farm.coordinates.map((c) => [c.longitude, c.latitude]).toList();
    if (ring.isNotEmpty &&
        (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
      ring.add(ring.first);
    }
    return ring;
  }

  /// Builds the full FeatureCollection for every plot in [farms], plus the
  /// batch-level operator/commodity metadata a DDS also requires. This is
  /// the handoff artifact the exporter uses for their own TRACES filing —
  /// whether by manual portal entry or their own system's import.
  static Map<String, dynamic> buildFeatureCollection(
    List<FarmPolygon> farms, {
    DdsExportBatch? batch,
  }) {
    return {
      'type': 'FeatureCollection',
      if (batch != null)
        'properties': {
          'operator_eori': batch.operatorEori,
          'operator_name': batch.operatorName,
          'operator_address': batch.operatorAddress,
          'operator_country': batch.operatorCountry,
          'hs_code': batch.hsCode,
          'trade_name': batch.tradeName,
          'dds_reference_number': batch.ddsReferenceNumber,
          'dds_verification_number': batch.ddsVerificationNumber,
        },
      'features': farms.map(_toFeature).toList(),
    };
  }
}
