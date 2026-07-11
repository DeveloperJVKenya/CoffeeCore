import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/eudr_compliance_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';

/// EUDR deforestation-compliance data for the selected farm, with refresh
/// orchestration. Never fabricates a result on failure — surfaces
/// [ServiceUnavailableException.userMessage] instead.
class EudrProvider with ChangeNotifier {
  final FarmPolygon farm;
  final EudrComplianceService _eudrService;
  final FarmMappingService _mappingService;

  EudrProvider({
    required this.farm,
    EudrComplianceService? eudrService,
    FarmMappingService? mappingService,
  })  : _eudrService = eudrService ?? EudrComplianceService(),
        _mappingService = mappingService ?? FarmMappingService();

  EudrComplianceData? _compliance;
  bool _isLoading = false;
  String? _error;

  EudrComplianceData? get compliance => _compliance ?? farm.eudrCompliance;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> refreshCompliance() async {
    if (farm.farmId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _eudrService.checkFarmCompliance(
        coordinates: farm.coordinates,
        areaHectares: farm.areaHectares,
      );
      final data = EudrComplianceData.fromResult(result);
      _compliance = data;
      await _mappingService.updateEudrCompliance(farm.farmId!, data);
    } on ServiceUnavailableException catch (e) {
      _error = e.userMessage;
    } catch (e) {
      _error = 'Something went wrong running the EUDR compliance check.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
