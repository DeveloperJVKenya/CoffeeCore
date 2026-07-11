import 'dart:async';
import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';

/// Owns the current user's [FarmPolygon] list stream and the currently
/// selected farm. Instantiated once above `FarmManagementHomeScreen`.
class FarmHubProvider with ChangeNotifier {
  final FarmMappingService _service;

  FarmHubProvider({FarmMappingService? service})
      : _service = service ?? FarmMappingService() {
    _subscribe();
  }

  List<FarmPolygon> _farms = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedFarmId;
  StreamSubscription<List<FarmPolygon>>? _sub;

  List<FarmPolygon> get farms => _farms;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedFarmId => _selectedFarmId;

  FarmPolygon? get selectedFarm {
    if (_selectedFarmId == null) return null;
    try {
      return _farms.firstWhere((f) => f.farmId == _selectedFarmId);
    } catch (_) {
      return null;
    }
  }

  void _subscribe() {
    _sub = _service.userFarmsStream().listen((farms) {
      _farms = farms;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    });
  }

  void selectFarm(String? farmId) {
    _selectedFarmId = farmId;
    notifyListeners();
  }

  Future<String?> saveFarm(FarmPolygon farm) => _service.saveFarm(farm);

  Future<void> renameFarm(String farmId, String newName) =>
      _service.renameFarm(farmId, newName);

  Future<void> deleteFarm(String farmId) async {
    await _service.deleteFarm(farmId);
    if (_selectedFarmId == farmId) {
      _selectedFarmId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
