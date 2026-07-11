import 'dart:async';
import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_cycle_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cycle_stage.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_cycle_service.dart';

/// Cycles for the currently selected farm, plus the active cycle/stage.
class FarmCycleProvider with ChangeNotifier {
  final String farmId;
  final FarmCycleService _service;

  FarmCycleProvider({required this.farmId, FarmCycleService? service})
      : _service = service ?? FarmCycleService() {
    _subscribe();
  }

  List<FarmCycle> _cycles = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedCycleId;
  StreamSubscription<List<FarmCycle>>? _sub;

  List<FarmCycle> get cycles => _cycles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  FarmCycle? get activeCycle {
    final active =
        _cycles.where((c) => c.status == CycleStatus.active).toList();
    if (active.isEmpty) return null;
    if (_selectedCycleId != null) {
      final match = active.where((c) => c.id == _selectedCycleId).toList();
      if (match.isNotEmpty) return match.first;
    }
    return active.first;
  }

  String? get activeCycleId => activeCycle?.id;

  List<FarmCycle> get pastCycles =>
      _cycles.where((c) => c.status != CycleStatus.active).toList();

  void _subscribe() {
    _sub = _service.cyclesForFarm(farmId).listen((cycles) {
      _cycles = cycles;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    });
  }

  void selectCycle(String? cycleId) {
    _selectedCycleId = cycleId;
    notifyListeners();
  }

  Future<String> startNewCycle({
    required String name,
    required int year,
    String? varietyPlanted,
  }) {
    return _service.startNewCycle(
      farmId: farmId,
      name: name,
      year: year,
      varietyPlanted: varietyPlanted,
    );
  }

  Future<void> advanceStage(FarmCycle cycle, CycleStage newStage) =>
      _service.advanceStage(cycle, newStage);

  Future<void> completeCycle(String cycleId) => _service.completeCycle(cycleId);

  Future<void> renameCycle(String cycleId, String newName) =>
      _service.renameCycle(cycleId, newName);

  Future<void> deleteCycle(String cycleId) => _service.deleteCycle(cycleId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
