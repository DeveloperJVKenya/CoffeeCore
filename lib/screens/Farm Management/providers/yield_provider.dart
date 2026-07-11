import 'dart:async';
import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/yield_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/yield_service.dart';

/// Yield records + aggregate stats for the selected farm + cycle.
class YieldProvider with ChangeNotifier {
  final String farmId;
  final YieldService _service;

  YieldProvider({required this.farmId, YieldService? service})
      : _service = service ?? YieldService();

  String? _cycleId;
  List<YieldRecord> _records = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<YieldRecord>>? _sub;

  List<YieldRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;
  YieldStats get stats => _service.computeStats(_records);

  void updateCycle(String? cycleId) {
    if (_cycleId == cycleId) return;
    _cycleId = cycleId;
    _sub?.cancel();
    if (cycleId == null) {
      _records = [];
      notifyListeners();
      return;
    }
    _isLoading = true;
    _sub = _service.recordsForCycle(farmId, cycleId).listen((v) {
      _records = v;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<String> addRecord(YieldRecord record) => _service.addRecord(record);

  Future<void> deleteRecord(String recordId) => _service.deleteRecord(recordId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
