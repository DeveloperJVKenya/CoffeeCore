import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Farm%20Management/models/dds_export_batch_model.dart';
import 'package:logger/logger.dart';

/// Firestore CRUD for tier-03 "exporter package" DDS export batches — see
/// dds_export_batch_model.dart. JV Almacis never files these with TRACES
/// itself; this is the persistence layer a future batch-curation screen
/// sits on top of, for assembling the evidence handoff package an
/// exporter takes to their own TRACES filing.
class DdsExportBatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _collection = 'DdsExportBatches';

  Future<String> createBatch(DdsExportBatch batch) async {
    try {
      final ref =
          await _firestore.collection(_collection).add(batch.toFirestore());
      _log.i(
        'DdsExportBatchService.createBatch: Created ${ref.id} '
        '(${batch.includedFarmIds.length} plot(s))',
      );
      return ref.id;
    } catch (e, st) {
      _log.e('DdsExportBatchService.createBatch: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<List<DdsExportBatch>> fetchAllBatches() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map(DdsExportBatch.fromFirestore).toList();
    } catch (e, st) {
      _log.e('DdsExportBatchService.fetchAllBatches: Error – $e',
          stackTrace: st);
      rethrow;
    }
  }

  Future<DdsExportBatch?> fetchBatch(String batchId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(batchId).get();
      if (!doc.exists) return null;
      return DdsExportBatch.fromFirestore(doc);
    } catch (e, st) {
      _log.e('DdsExportBatchService.fetchBatch: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateIncludedFarms(String batchId, List<String> farmIds) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(batchId)
          .update({'includedFarmIds': farmIds});
    } catch (e, st) {
      _log.e('DdsExportBatchService.updateIncludedFarms: Error – $e',
          stackTrace: st);
      rethrow;
    }
  }

  /// Records the Reference/Verification Number pair once the *exporter*
  /// has actually filed this batch with TRACES on their own account — JV
  /// Almacis never files it. This just lets our own evidence chain
  /// (Planetek/GFW) reference the exporter's filing receipt for
  /// record-keeping. Nothing in this codebase calls this yet; it would be
  /// invoked from wherever an exporter reports back their reference
  /// number (a future manual-entry step, most likely).
  Future<void> recordSubmission(
    String batchId, {
    required String ddsReferenceNumber,
    required String ddsVerificationNumber,
  }) async {
    try {
      await _firestore.collection(_collection).doc(batchId).update({
        'status': DdsExportBatchStatus.submitted.name,
        'ddsReferenceNumber': ddsReferenceNumber,
        'ddsVerificationNumber': ddsVerificationNumber,
        'submittedAt': Timestamp.fromDate(DateTime.now()),
      });
      _log.i(
        'DdsExportBatchService.recordSubmission: Batch $batchId filed, '
        'ref=$ddsReferenceNumber',
      );
    } catch (e, st) {
      _log.e('DdsExportBatchService.recordSubmission: Error – $e',
          stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteBatch(String batchId) async {
    try {
      await _firestore.collection(_collection).doc(batchId).delete();
    } catch (e, st) {
      _log.e('DdsExportBatchService.deleteBatch: Error – $e', stackTrace: st);
      rethrow;
    }
  }
}
