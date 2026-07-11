import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Farm%20Management/models/yield_model.dart';

/// Aggregate yield statistics for a cycle.
class YieldStats {
  final double totalKg;
  final double averageMoisture;
  final int recordCount;

  const YieldStats({
    required this.totalKg,
    required this.averageMoisture,
    required this.recordCount,
  });

  static const YieldStats empty =
      YieldStats(totalKg: 0, averageMoisture: 0, recordCount: 0);
}

/// Firestore CRUD for the `YieldRecords` collection.
class YieldService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _collection = 'YieldRecords';

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<YieldRecord>> recordsForCycle(String farmId, String cycleId) {
    if (_uid == null) return Stream.value([]);
    return _firestore
        .collection(_collection)
        .where('farmId', isEqualTo: farmId)
        .where('cycleId', isEqualTo: cycleId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => YieldRecord.fromFirestore(d)).toList())
        .handleError((Object e, StackTrace st) {
      _log.e('YieldService.recordsForCycle: Stream error – $e', stackTrace: st);
      return <YieldRecord>[];
    });
  }

  Future<String> addRecord(YieldRecord record) async {
    try {
      final ref =
          await _firestore.collection(_collection).add(record.toFirestore());
      return ref.id;
    } catch (e, st) {
      _log.e('YieldService.addRecord: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteRecord(String recordId) async {
    try {
      await _firestore.collection(_collection).doc(recordId).delete();
    } catch (e, st) {
      _log.e('YieldService.deleteRecord: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  YieldStats computeStats(List<YieldRecord> records) {
    if (records.isEmpty) return YieldStats.empty;
    final totalKg = records.fold<double>(0.0, (t, r) => t + r.kgHarvested);
    final withMoisture =
        records.where((r) => r.moistureContent != null).toList();
    final avgMoisture = withMoisture.isEmpty
        ? 0.0
        : withMoisture.fold<double>(0.0, (t, r) => t + r.moistureContent!) /
            withMoisture.length;
    return YieldStats(
      totalKg: totalKg,
      averageMoisture: avgMoisture,
      recordCount: records.length,
    );
  }
}
