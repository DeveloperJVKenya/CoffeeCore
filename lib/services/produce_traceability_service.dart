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

  /// Advances a bag to [stage], guarded by a transaction against the
  /// submission doc's `currentStage` field so two devices scanning the same
  /// physical tag near-simultaneously can't both write a "next" stage from
  /// a stale read — the second writer sees the first writer's update and is
  /// rejected instead of silently producing a duplicate/out-of-order entry.
  /// [expectedCurrentStage] is whatever the caller displayed as "current
  /// stage" when the operator chose to advance it (i.e. the value this
  /// service's own [currentStage] computed from stage history). A
  /// submission whose doc has no `currentStage` field yet (every submission
  /// recorded before this guard existed, or one with no scans yet) is
  /// trusted on this first write and the field is then populated, so
  /// pre-existing data never spuriously conflicts.
  Future<void> recordStage({
    required String coopId,
    required String userId,
    required String submissionId,
    required ProduceStage expectedCurrentStage,
    required ProduceStage stage,
    required String scannedBy,
    required String scannedByName,
    String note = '',
  }) async {
    final submissionRef = _submissionsRef(coopId, userId).doc(submissionId);
    final entryRef = _traceStagesRef(coopId, userId, submissionId).doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final submissionSnap = await transaction.get(submissionRef);
        final data = submissionSnap.data();
        if (data != null && data.containsKey('currentStage')) {
          final storedStage =
              ProduceStageX.fromStorage(data['currentStage']?.toString());
          if (storedStage != expectedCurrentStage) {
            throw StateError(
                'This bag was already advanced to ${storedStage.label} by '
                'another scan. Refresh and try again.');
          }
        }
        transaction.set(
          submissionRef,
          {'currentStage': stage.storageValue},
          SetOptions(merge: true),
        );
        transaction.set(
          entryRef,
          ProduceTraceEntry(
            stage: stage,
            scannedBy: scannedBy,
            scannedByName: scannedByName,
            note: note,
            timestamp: Timestamp.now(),
          ).toMap(),
        );
      });
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
