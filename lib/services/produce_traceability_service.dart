import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:coffeecore/models/farmer_produce.dart';
import 'package:coffeecore/models/produce_trace_stage.dart';
import 'package:coffeecore/models/traced_submission.dart';

/// Firestore access for the QR-based produce traceability pipeline: each
/// submission's stage-transition history, and the live cooperative-wide
/// view combining every farmer's submissions with their current stage.
/// Everything here is reactive (never a one-shot fetch feeding a stored
/// total) for the same reason as FarmerSettlementService and
/// ProduceScreen's _produceDataStreamForCoop — a denormalized "current
/// stage" field would drift the moment a scan was recorded without also
/// updating it.
class ProduceTraceabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  CollectionReference<Map<String, dynamic>> _submissionsRef(
          String coopId, String userId) =>
      _firestore
          .collection('${coopId}_FarmerProduce')
          .doc(userId)
          .collection('submissions');

  CollectionReference<Map<String, dynamic>> _traceStagesRef(
          String coopId, String userId, String submissionId) =>
      _submissionsRef(coopId, userId)
          .doc(submissionId)
          .collection('traceStages');

  Stream<List<ProduceTraceEntry>> stageHistory(
      String coopId, String userId, String submissionId) {
    return _traceStagesRef(coopId, userId, submissionId)
        .orderBy('timestamp')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ProduceTraceEntry.fromDocument(d)).toList());
  }

  /// A submission with no recorded scans yet is implicitly at the first
  /// pipeline stage — no write is needed at submission time to establish
  /// that starting state.
  ProduceStage currentStage(List<ProduceTraceEntry> history) {
    return history.isEmpty ? ProduceStage.received : history.last.stage;
  }

  Future<void> recordStage({
    required String coopId,
    required String userId,
    required String submissionId,
    required ProduceStage stage,
    required String scannedBy,
    required String scannedByName,
    String note = '',
  }) async {
    try {
      await _traceStagesRef(coopId, userId, submissionId).add(
        ProduceTraceEntry(
          stage: stage,
          scannedBy: scannedBy,
          scannedByName: scannedByName,
          note: note,
          timestamp: Timestamp.now(),
        ).toMap(),
      );
    } catch (e, st) {
      _log.e('ProduceTraceabilityService.recordStage: Error – $e',
          stackTrace: st);
      rethrow;
    }
  }

  Stream<TracedSubmission> _tracedSubmission(
      String coopId, String userId, FarmerProduce submission) {
    return stageHistory(coopId, userId, submission.submissionId).map(
        (history) => TracedSubmission(
            submission: submission, stage: currentStage(history)));
  }

  Stream<List<TracedSubmission>> _tracedSubmissionsForUser(
      String coopId, String userId) {
    return _submissionsRef(coopId, userId).snapshots().switchMap((subSnap) {
      final submissions =
          subSnap.docs.map((d) => FarmerProduce.fromDocument(d)).toList();
      if (submissions.isEmpty) {
        return Stream<List<TracedSubmission>>.value(const []);
      }
      return CombineLatestStream.list(
        submissions.map((s) => _tracedSubmission(coopId, userId, s)),
      );
    });
  }

  /// Re-subscribes whenever the cooperative's user list changes, mirroring
  /// the same switchMap-over-users pattern used by
  /// FarmerSettlementService.settlementForCoop and ProduceScreen's
  /// _produceDataStreamForCoop.
  Stream<List<TracedSubmission>> tracedSubmissionsForCoop(String coopId) {
    return _firestore
        .collection('${coopId}_users')
        .snapshots()
        .switchMap((userSnapshot) {
      if (userSnapshot.docs.isEmpty) {
        return Stream<List<TracedSubmission>>.value(const []);
      }
      return CombineLatestStream.list(
        userSnapshot.docs
            .map((doc) => _tracedSubmissionsForUser(coopId, doc.id)),
      ).map((lists) => lists.expand((l) => l).toList());
    });
  }
}
