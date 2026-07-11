import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/activity_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/activity_service.dart';

/// Activities for the selected farm, optionally scoped to a cycle.
/// Depends on the active cycle id via `updateCycle` — wired as a
/// `ChangeNotifierProxyProvider<FarmCycleProvider, ActivityProvider>` at the
/// detail-shell level.
class ActivityProvider with ChangeNotifier {
  final String farmId;
  final ActivityService _service;

  ActivityProvider({required this.farmId, ActivityService? service})
      : _service = service ?? ActivityService() {
    _subscribe();
  }

  List<FarmActivity> _activities = [];
  bool _isLoading = true;
  String? _error;
  String? _cycleId;
  StreamSubscription<List<FarmActivity>>? _sub;

  List<FarmActivity> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateCycle(String? cycleId) {
    if (_cycleId == cycleId) return;
    _cycleId = cycleId;
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _isLoading = true;
    _sub = _service.activitiesForFarm(farmId, cycleId: _cycleId).listen(
        (activities) {
      _activities = activities;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<String> addActivity(FarmActivity activity) =>
      _service.addActivity(activity);

  Future<void> updateActivity(FarmActivity activity) =>
      _service.updateActivity(activity);

  Future<void> deleteActivity(String activityId) =>
      _service.deleteActivity(activityId);

  Future<String> uploadPhoto({
    required String fileName,
    required Uint8List? webBytes,
    required File? nativeFile,
  }) {
    return _service.uploadActivityPhoto(
      farmId: farmId,
      fileName: fileName,
      webBytes: webBytes,
      nativeFile: nativeFile,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
