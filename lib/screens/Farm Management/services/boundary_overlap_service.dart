import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/utils/geo_math.dart';
import 'package:logger/logger.dart';

/// Checks a farm's boundary against every other registered farm for
/// geometric overlap — two different farmers claiming the same physical
/// land is a real EUDR fraud/data-integrity signal (the same plot can't
/// legitimately back two independent deforestation-free claims), distinct
/// from either the GFW or Planetek deforestation checks.
class BoundaryOverlapService {
  final FarmMappingService _mappingService;
  final Logger _log = Logger(printer: PrettyPrinter());

  BoundaryOverlapService({FarmMappingService? mappingService})
      : _mappingService = mappingService ?? FarmMappingService();

  /// Runs the overlap check for [farm] against every other farm in the
  /// system, persists the result, and returns the overlapping farm IDs
  /// (empty if none). Deliberately checks across *all* farms regardless
  /// of owner — the risk this guards against is specifically two
  /// different farmers' plots overlapping, not just one farmer's own.
  Future<List<String>> checkAndPersist(FarmPolygon farm) async {
    if (farm.farmId == null) return const [];

    final overlaps = await check(farm);
    await _mappingService.updateBoundaryOverlap(farm.farmId!, overlaps);
    return overlaps;
  }

  /// Runs the overlap check without persisting — useful for previewing
  /// before a farm boundary is first saved.
  Future<List<String>> check(FarmPolygon farm) async {
    if (farm.coordinates.length < 3) return const [];

    final allFarms = await _mappingService.fetchAllFarms();
    final overlapping = <String>[];

    for (final other in allFarms) {
      if (other.farmId == farm.farmId) continue;
      if (other.coordinates.length < 3) continue;
      if (GeoMath.polygonsOverlap(farm.coordinates, other.coordinates)) {
        overlapping.add(other.farmId ?? '');
      }
    }

    final result = overlapping.where((id) => id.isNotEmpty).toList();
    _log.i(
      'BoundaryOverlapService.check: "${farm.farmName}" overlaps with '
      '${result.length} other farm(s)',
    );
    return result;
  }
}
