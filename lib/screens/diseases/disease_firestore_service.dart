import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DISEASE FIRESTORE SERVICE
//
// Firestore collection structure (mirrors pest_diagnoses exactly):
//
//   disease_diagnoses/                       ← root collection
//     {userId}/                             ← document per user
//       diagnoses/                          ← sub-collection
//         {diagnosisId}/                    ← auto-ID document per record
//           diseaseName     : String
//           stage           : String
//           detectionMode   : String  ("knownBoth" | "knownStage" | "aiScan" | "customSearch")
//           managementData  : Map<String, dynamic>
//           imageUrls       : List<String>
//           aiConfidence    : double?
//           aiReasoning     : String?
//           savedAt         : Timestamp
//           appVersion      : String   ("1.0.0")
//
// Why separate from pest_diagnoses?
//   • Separate root collection keeps security rules and history pages isolated.
//   • Avoids name collisions if a user manages both pests and diseases.
//   • Allows independent pagination and ordering of disease history.
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseDiagnosisRecord {
  final String id;
  final String diseaseName;
  final String stage;
  final String detectionMode;
  final Map<String, dynamic> managementData;
  final List<String> imageUrls;
  final double? aiConfidence;
  final String? aiReasoning;
  final DateTime savedAt;

  const DiseaseDiagnosisRecord({
    required this.id,
    required this.diseaseName,
    required this.stage,
    required this.detectionMode,
    required this.managementData,
    required this.imageUrls,
    this.aiConfidence,
    this.aiReasoning,
    required this.savedAt,
  });

  factory DiseaseDiagnosisRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return DiseaseDiagnosisRecord(
      id: doc.id,
      diseaseName: d['diseaseName'] as String? ?? 'Unknown Disease',
      stage: d['stage'] as String? ?? '',
      detectionMode: d['detectionMode'] as String? ?? '',
      managementData: (d['managementData'] as Map<String, dynamic>?) ?? {},
      imageUrls: List<String>.from(d['imageUrls'] ?? []),
      aiConfidence: (d['aiConfidence'] as num?)?.toDouble(),
      aiReasoning: d['aiReasoning'] as String?,
      savedAt: (d['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'diseaseName': diseaseName,
        'stage': stage,
        'detectionMode': detectionMode,
        'managementData': managementData,
        'imageUrls': imageUrls,
        'aiConfidence': aiConfidence,
        'aiReasoning': aiReasoning,
        'savedAt': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseFirestoreService {
  DiseaseFirestoreService._(); // prevent instantiation

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Logger _logger = Logger(printer: PrettyPrinter());

  static const int _maxHistoryRecords = 100;
  static const String _rootCollection = 'disease_diagnoses';

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String get _userId {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw const _AuthException();
    return uid;
  }

  static CollectionReference<Map<String, dynamic>> get _diagnosesRef =>
      _db.collection(_rootCollection).doc(_userId).collection('diagnoses');

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 1 — Save a disease diagnosis
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> saveDiagnosis({
    required String diseaseName,
    required String stage,
    required String detectionMode,
    required Map<String, dynamic> managementData,
    required List<String> imageUrls,
    double? aiConfidence,
    String? aiReasoning,
  }) async {
    _logger.i('Saving disease diagnosis for "$diseaseName" | '
        'stage="$stage" | mode="$detectionMode"');

    final record = DiseaseDiagnosisRecord(
      id: '',
      diseaseName: diseaseName,
      stage: stage,
      detectionMode: detectionMode,
      managementData: managementData,
      imageUrls: imageUrls.take(10).toList(),
      aiConfidence: aiConfidence,
      aiReasoning: aiReasoning,
      savedAt: DateTime.now(),
    );

    await _enforceRecordLimit();

    try {
      final docRef = await _diagnosesRef.add(record.toMap());
      _logger.i('Saved disease diagnosis with Firestore ID: ${docRef.id}');
      return docRef.id;
    } on FirebaseException catch (e) {
      _logger.e('Firestore write error saving disease diagnosis',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 2 — Load diagnosis history
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<DiseaseDiagnosisRecord>> loadHistory({
    int limit = 20,
  }) async {
    _logger.i('Loading disease diagnosis history (limit=$limit)');

    try {
      final snapshot = await _diagnosesRef
          .orderBy('savedAt', descending: true)
          .limit(limit.clamp(1, _maxHistoryRecords))
          .get();

      final records = snapshot.docs
          .map((doc) => DiseaseDiagnosisRecord.fromFirestore(doc))
          .toList();

      _logger.i('Loaded ${records.length} disease diagnosis records.');
      return records;
    } on _AuthException {
      _logger.w('loadHistory — user not signed in, returning empty history.');
      return [];
    } on FirebaseException catch (e) {
      _logger.e('Firestore error loading disease history',
          error: e, stackTrace: StackTrace.current);
      return [];
    } catch (e, st) {
      _logger.e('Unexpected error loading disease history',
          error: e, stackTrace: st);
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 3 — Load a single diagnosis by ID
  // ══════════════════════════════════════════════════════════════════════════

  static Future<DiseaseDiagnosisRecord?> loadById(String diagnosisId) async {
    _logger.i('Loading disease diagnosis by ID: "$diagnosisId"');
    try {
      final doc = await _diagnosesRef.doc(diagnosisId).get();
      if (!doc.exists || doc.data() == null) {
        _logger.w('Disease diagnosis "$diagnosisId" not found or has no data.');
        return null;
      }
      return DiseaseDiagnosisRecord.fromFirestore(doc);
    } on _AuthException {
      _logger.w('loadById failed — user not signed in.');
      return null;
    } catch (e, st) {
      _logger.e('Error loading disease diagnosis "$diagnosisId"',
          error: e, stackTrace: st);
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 4 — Delete a diagnosis
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> deleteDiagnosis(String diagnosisId) async {
    _logger.i('Deleting disease diagnosis "$diagnosisId"');
    try {
      await _diagnosesRef.doc(diagnosisId).delete();
      _logger.i('Deleted disease diagnosis "$diagnosisId".');
    } on _AuthException {
      _logger.e('deleteDiagnosis failed — user not signed in.');
      rethrow;
    } on FirebaseException catch (e) {
      _logger.e('Error deleting disease diagnosis "$diagnosisId"',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 5 — Real-time stream of history
  // ══════════════════════════════════════════════════════════════════════════

  static Stream<List<DiseaseDiagnosisRecord>> historyStream({int limit = 30}) {
    _logger.i('Opening real-time disease history stream (limit=$limit)');
    try {
      return _diagnosesRef
          .orderBy('savedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => DiseaseDiagnosisRecord.fromFirestore(doc))
                .toList(),
          );
    } on _AuthException {
      _logger.w('historyStream — user not signed in, returning empty stream.');
      return const Stream.empty();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 5b — Admin trend analytics: every diagnosis for a known set
  // of user IDs (Main Admin passes every user, Coop Admin passes only their
  // cooperative's users — the caller resolves that list; see
  // pest_disease_trends_screen.dart). Each read targets one known
  // disease_diagnoses/{userId}/diagnoses path directly (not a collectionGroup
  // scan) since Firestore's security-rule evaluation for collectionGroup
  // queries requires the rule to be provable for the query as a whole and
  // does not reliably honour a plain isAdmin()-style rule the way a query
  // against a single, known parent path does — this mirrors the same rule
  // structure that already works for the owner's own historyStream() above.
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<DiseaseDiagnosisRecord>> diagnosesForUsers(
    List<String> userIds,
  ) async {
    _logger.i('Loading disease diagnoses for ${userIds.length} visible users');
    final records = <DiseaseDiagnosisRecord>[];
    final futures = userIds.map((uid) async {
      try {
        final snapshot = await _db
            .collection(_rootCollection)
            .doc(uid)
            .collection('diagnoses')
            .get();
        return snapshot.docs
            .map((doc) => DiseaseDiagnosisRecord.fromFirestore(doc))
            .toList();
      } on FirebaseException catch (e) {
        _logger.w('Skipping disease diagnoses for user "$uid"', error: e);
        return <DiseaseDiagnosisRecord>[];
      }
    });
    for (final result in await Future.wait(futures)) {
      records.addAll(result);
    }
    _logger
        .i('Loaded ${records.length} disease diagnoses across visible users');
    return records;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 6 — Clear all history
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> clearAllHistory() async {
    _logger.i('Clearing ALL disease history for user "$_userId"');
    try {
      const batchSize = 400;
      int totalDeleted = 0;
      while (true) {
        final snapshot = await _diagnosesRef.limit(batchSize).get();
        if (snapshot.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        totalDeleted += snapshot.docs.length;
        _logger.i('Batch deleted ${snapshot.docs.length} disease records '
            '(total so far: $totalDeleted).');
      }
      _logger.i('All disease history cleared. '
          'Total records deleted: $totalDeleted.');
    } on _AuthException {
      _logger.e('clearAllHistory — user not signed in.');
      rethrow;
    } on FirebaseException catch (e) {
      _logger.e('clearAllHistory error',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 7 — Count total diagnoses
  // ══════════════════════════════════════════════════════════════════════════

  static Future<int> diagnosisCount() async {
    try {
      final result = await _diagnosesRef.count().get();
      final count = result.count ?? 0;
      _logger.i('Disease diagnosis count for current user: $count');
      return count;
    } on _AuthException {
      _logger.w('diagnosisCount — user not signed in, returning 0.');
      return 0;
    } catch (e, st) {
      _logger.e('diagnosisCount error', error: e, stackTrace: st);
      return 0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE — Record limit enforcement
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> _enforceRecordLimit() async {
    try {
      final count = await diagnosisCount();
      if (count < _maxHistoryRecords) {
        return;
      }
      _logger.w('Disease record limit reached ($count records). '
          'Deleting oldest record before saving new one.');
      final oldest = await _diagnosesRef
          .orderBy('savedAt', descending: false)
          .limit(1)
          .get();
      if (oldest.docs.isNotEmpty) {
        final oldestId = oldest.docs.first.id;
        await oldest.docs.first.reference.delete();
        _logger.i('Oldest disease record "$oldestId" deleted to enforce '
            '$_maxHistoryRecords record limit.');
      }
    } on _AuthException {
      _logger.w('_enforceRecordLimit — user not signed in.');
    } catch (e, st) {
      _logger.w(
          'Record limit check failed (non-critical), '
          'proceeding with save anyway.',
          error: e,
          stackTrace: st);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private exception
// ─────────────────────────────────────────────────────────────────────────────

class _AuthException implements Exception {
  const _AuthException();
  @override
  String toString() => 'DiseaseFirestoreService: No authenticated user. '
      'Ensure Firebase Auth is initialised and a user is signed in.';
}
