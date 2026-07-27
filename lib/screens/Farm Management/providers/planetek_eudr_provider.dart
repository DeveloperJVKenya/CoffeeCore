import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/planetek_analysis_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/planetek_deforestation_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';

/// Planetek certified EUDR deforestation-analysis data for the selected
/// farm, with refresh orchestration. Sibling to [EudrProvider] (GFW
/// screening), not a replacement — the two run and persist independently.
/// Never fabricates a result on failure — surfaces
/// [ServiceUnavailableException.userMessage] instead.
class PlanetekEudrProvider with ChangeNotifier {
  final FarmPolygon farm;
  final PlanetekDeforestationService _planetekService;
  final FarmMappingService _mappingService;

  PlanetekEudrProvider({
    required this.farm,
    PlanetekDeforestationService? planetekService,
    FarmMappingService? mappingService,
  })  : _planetekService = planetekService ?? PlanetekDeforestationService(),
        _mappingService = mappingService ?? FarmMappingService();

  PlanetekAnalysisData? _analysis;
  bool _isLoading = false;
  String? _error;

  PlanetekAnalysisData? get analysis => _analysis ?? farm.planetekAnalysis;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> refreshAnalysis() async {
    if (farm.farmId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _planetekService.runCertifiedAnalysis(
        coordinates: farm.coordinates,
        aoiName: 'aoi_${farm.farmId}',
      );
      _analysis = result;
      await _mappingService.updatePlanetekAnalysis(farm.farmId!, result);
    } on ServiceUnavailableException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error =
          'Something went wrong running the certified deforestation analysis.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
