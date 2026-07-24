import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';

/// One farm plus the export choices made for it (whether to include it,
/// and the ground-truth land-cover label to send alongside the geometry).
class GeoJsonFarmSelection {
  final FarmPolygon farm;
  final bool included;
  final String groundTruth; // 'forest' | 'non-forest'

  const GeoJsonFarmSelection({
    required this.farm,
    required this.included,
    required this.groundTruth,
  });
}

/// Builds a GeoJSON FeatureCollection of farm polygons for sharing with
/// external partners (e.g. a satellite imagery provider validating a
/// forest / non-forest classification algorithm against sample AOIs).
class GeoJsonExportService {
  /// Converts the stored `List<LatLng>` (lat/lng) into a closed GeoJSON
  /// ring in `[lng, lat]` order, as required by the GeoJSON spec.
  static List<List<double>> _toClosedRing(FarmPolygon farm) {
    final ring = farm.coordinates
        .map((c) => [c.longitude, c.latitude])
        .toList(growable: true);
    if (ring.isNotEmpty &&
        (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
      ring.add(ring.first);
    }
    return ring;
  }

  static Map<String, dynamic> _toFeature(GeoJsonFarmSelection selection) {
    final farm = selection.farm;
    final properties = <String, dynamic>{
      'farm_id': farm.farmId,
      'farm_name': farm.farmName,
      'class': selection.groundTruth,
      'ground_truth': selection.groundTruth,
      'land_use': 'coffee farm',
      'area_ha': double.parse(farm.areaHectares.toStringAsFixed(4)),
      'perimeter_m': double.parse(farm.perimeterMeters.toStringAsFixed(2)),
      'created_at': farm.createdAt.toIso8601String(),
    };

    final eudr = farm.eudrCompliance;
    if (eudr != null) {
      properties['was_forested_before_2020'] = eudr.wasForestedBefore2020;
      properties['tree_cover_2000_percent'] =
          double.parse(eudr.treeCoverPercent2000.toStringAsFixed(2));
      properties['remaining_tree_cover_percent'] =
          double.parse(eudr.remainingTreeCoverPercent.toStringAsFixed(2));
      properties['eudr_data_source'] = eudr.dataSource;
    }

    return {
      'type': 'Feature',
      'properties': properties,
      'geometry': {
        'type': 'Polygon',
        'coordinates': [_toClosedRing(farm)],
      },
    };
  }

  /// Builds the full FeatureCollection for the given (included) selections.
  static Map<String, dynamic> buildFeatureCollection(
    List<GeoJsonFarmSelection> selections,
  ) {
    final included = selections.where((s) => s.included).toList();
    return {
      'type': 'FeatureCollection',
      'features': included.map(_toFeature).toList(),
    };
  }
}
