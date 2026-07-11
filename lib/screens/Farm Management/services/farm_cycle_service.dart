import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_cycle_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cycle_stage.dart';

/// Firestore CRUD for the `FarmCycles` collection. Replaces the cycle
/// management half of the old `data_manager.dart` with typed, farm-scoped
/// records instead of raw `List<Map<String, dynamic>>` under
/// `FarmData/{uid}/Cycles/{cycleName}`.
class FarmCycleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _collection = 'FarmCycles';

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<FarmCycle>> cyclesForFarm(String farmId) {
    if (_uid == null) {
      _log.w('FarmCycleService.cyclesForFarm: No authenticated user');
      return Stream.value([]);
    }
    return _firestore
        .collection(_collection)
        .where('farmId', isEqualTo: farmId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FarmCycle.fromFirestore(
                d as DocumentSnapshot<Map<String, dynamic>>))
            .toList())
        .handleError((Object e, StackTrace st) {
      _log.e('FarmCycleService.cyclesForFarm: Stream error – $e',
          stackTrace: st);
      return <FarmCycle>[];
    });
  }

  Future<FarmCycle?> getCycleById(String cycleId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(cycleId).get();
      if (!doc.exists) return null;
      return FarmCycle.fromFirestore(doc);
    } catch (e, st) {
      _log.e('FarmCycleService.getCycleById: Error – $e', stackTrace: st);
      return null;
    }
  }

  Future<String> startNewCycle({
    required String farmId,
    required String name,
    required int year,
    String? varietyPlanted,
  }) async {
    if (_uid == null) {
      throw StateError('FarmCycleService.startNewCycle: No authenticated user');
    }
    try {
      final now = DateTime.now();
      final cycle = FarmCycle(
        farmId: farmId,
        userId: _uid!,
        name: name,
        year: year,
        varietyPlanted: varietyPlanted,
        currentStage: CycleStage.landPrep,
        stageHistory: [
          StageHistoryEntry(stage: CycleStage.landPrep, enteredAt: now),
        ],
        startDate: now,
        status: CycleStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      final ref =
          await _firestore.collection(_collection).add(cycle.toFirestore());
      _log.i(
          'FarmCycleService.startNewCycle: Created cycle ${ref.id} for farm $farmId');
      return ref.id;
    } catch (e, st) {
      _log.e('FarmCycleService.startNewCycle: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> advanceStage(FarmCycle cycle, CycleStage newStage) async {
    if (cycle.id == null) {
      throw ArgumentError('FarmCycleService.advanceStage: cycle.id is null');
    }
    try {
      final updatedHistory = [
        ...cycle.stageHistory,
        StageHistoryEntry(stage: newStage, enteredAt: DateTime.now()),
      ];
      await _firestore.collection(_collection).doc(cycle.id).update({
        'currentStage': newStage.storageValue,
        'stageHistory': updatedHistory.map((e) => e.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _log.i(
          'FarmCycleService.advanceStage: Cycle ${cycle.id} -> ${newStage.label}');
    } catch (e, st) {
      _log.e('FarmCycleService.advanceStage: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateRollups({
    required String cycleId,
    required double totalCost,
    required double totalRevenue,
  }) async {
    try {
      await _firestore.collection(_collection).doc(cycleId).update({
        'totalCost': totalCost,
        'totalRevenue': totalRevenue,
        'profitLoss': totalRevenue - totalCost,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e, st) {
      _log.e('FarmCycleService.updateRollups: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> completeCycle(String cycleId) async {
    try {
      await _firestore.collection(_collection).doc(cycleId).update({
        'status': CycleStatus.completed.storageValue,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _log.i('FarmCycleService.completeCycle: Cycle $cycleId marked complete');
    } catch (e, st) {
      _log.e('FarmCycleService.completeCycle: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> renameCycle(String cycleId, String newName) async {
    try {
      await _firestore.collection(_collection).doc(cycleId).update({
        'name': newName.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e, st) {
      _log.e('FarmCycleService.renameCycle: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteCycle(String cycleId) async {
    try {
      await _firestore.collection(_collection).doc(cycleId).delete();
      _log.i('FarmCycleService.deleteCycle: Deleted cycle $cycleId');
    } catch (e, st) {
      _log.e('FarmCycleService.deleteCycle: Error – $e', stackTrace: st);
      rethrow;
    }
  }
}
