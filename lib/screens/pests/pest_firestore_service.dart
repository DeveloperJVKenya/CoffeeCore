import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PEST FIRESTORE SERVICE
//
// Firestore collection structure:
//
//   pest_diagnoses/                          ← root collection
//     {userId}/                             ← document per user
//       diagnoses/                          ← sub-collection
//         {diagnosisId}/                    ← auto-ID document per record
//           pestName        : String
//           stage           : String
//           detectionMode   : String  ("knownBoth" | "knownStage" | "aiScan")
//           managementData  : Map<String, dynamic>
//           imageUrls       : List<String>
//           aiConfidence    : double?
//           aiReasoning     : String?
//           savedAt         : Timestamp
//           appVersion      : String   ("1.0.0" — bump on each release)
//
// Why this structure?
//   • One document per user keeps security rules simple:
//     allow read, write: if request.auth.uid == userId;
//   • Sub-collection "diagnoses" allows efficient pagination and ordering
//     without reading all users' data.
//   • Storing managementData embedded avoids extra reads — the farmer
//     can review past diagnoses fully offline after first load.
// ─────────────────────────────────────────────────────────────────────────────

// Data model returned by loadHistory()
class PestDiagnosisRecord {
  final String id;
  final String pestName;
  final String stage;
  final String detectionMode;
  final Map<String, dynamic> managementData;
  final List<String> imageUrls;
  final double? aiConfidence;
  final String? aiReasoning;
  final DateTime savedAt;

  const PestDiagnosisRecord({
    required this.id,
    required this.pestName,
    required this.stage,
    required this.detectionMode,
    required this.managementData,
    required this.imageUrls,
    this.aiConfidence,
    this.aiReasoning,
    required this.savedAt,
  });

  factory PestDiagnosisRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return PestDiagnosisRecord(
      id: doc.id,
      pestName: d['pestName'] as String? ?? 'Unknown Pest',
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
        'pestName': pestName,
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

class PestFirestoreService {
  PestFirestoreService._(); // prevent instantiation

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Logger _logger = Logger(printer: PrettyPrinter());

  // ── Max records stored per user (prevents unbounded growth) ───────────────
  static const int _maxHistoryRecords = 100;

  // ── Root collection name ───────────────────────────────────────────────────
  static const String _rootCollection = 'pest_diagnoses';

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS — userId + collection reference
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns the current authenticated user's UID.
  /// Throws [_AuthException] if no user is signed in.
  static String get _userId {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw const _AuthException();
    return uid;
  }

  /// Returns the diagnoses sub-collection reference for the current user.
  static CollectionReference<Map<String, dynamic>> get _diagnosesRef =>
      _db.collection(_rootCollection).doc(_userId).collection('diagnoses');

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 1 — Save a diagnosis
  // ══════════════════════════════════════════════════════════════════════════

  /// Saves a pest diagnosis to Firestore for the current user.
  ///
  /// Returns the Firestore document ID of the saved record.
  /// Throws on auth failure or Firestore write error.
  static Future<String> saveDiagnosis({
    required String pestName,
    required String stage,
    required String detectionMode,
    required Map<String, dynamic> managementData,
    required List<String> imageUrls,
    double? aiConfidence,
    String? aiReasoning,
  }) async {
    _logger.i('Saving pest diagnosis for "$pestName" | '
        'stage="$stage" | mode="$detectionMode"');

    final record = PestDiagnosisRecord(
      id: '', // Firestore will assign
      pestName: pestName,
      stage: stage,
      detectionMode: detectionMode,
      managementData: managementData,
      imageUrls: imageUrls.take(10).toList(), // cap at 10 URLs per record
      aiConfidence: aiConfidence,
      aiReasoning: aiReasoning,
      savedAt: DateTime.now(),
    );

    // ── Check record count to avoid exceeding _maxHistoryRecords ──────────
    await _enforceRecordLimit();

    // ── Write to Firestore ─────────────────────────────────────────────────
    try {
      final docRef = await _diagnosesRef.add(record.toMap());
      _logger.i('Saved pest diagnosis with Firestore ID: ${docRef.id}');
      return docRef.id;
    } on FirebaseException catch (e) {
      _logger.e('Firestore write error saving pest diagnosis',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 2 — Load diagnosis history
  // ══════════════════════════════════════════════════════════════════════════

  /// Loads the farmer's past diagnoses, ordered newest first.
  ///
  /// [limit] — how many records to load (default 20, max 100).
  /// Returns an empty list if no records exist or the user is not signed in.
  static Future<List<PestDiagnosisRecord>> loadHistory({
    int limit = 20,
  }) async {
    _logger.i('Loading pest diagnosis history (limit=$limit)');

    try {
      final snapshot = await _diagnosesRef
          .orderBy('savedAt', descending: true)
          .limit(limit.clamp(1, _maxHistoryRecords))
          .get();

      final records = snapshot.docs
          .map((doc) => PestDiagnosisRecord.fromFirestore(doc))
          .toList();

      _logger.i('Loaded ${records.length} pest diagnosis records.');
      return records;
    } on _AuthException {
      _logger.w('loadHistory — user not signed in, returning empty history.');
      return [];
    } on FirebaseException catch (e) {
      _logger.e('Firestore error loading pest history',
          error: e, stackTrace: StackTrace.current);
      return [];
    } catch (e, st) {
      _logger.e('Unexpected error loading pest history',
          error: e, stackTrace: st);
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 3 — Load a single diagnosis by ID
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetches a single diagnosis record by its Firestore document ID.
  /// Returns null if not found or on error.
  static Future<PestDiagnosisRecord?> loadById(String diagnosisId) async {
    _logger.i('Loading pest diagnosis by ID: "$diagnosisId"');
    try {
      final doc = await _diagnosesRef.doc(diagnosisId).get();
      if (!doc.exists || doc.data() == null) {
        _logger.w('Pest diagnosis "$diagnosisId" not found or has no data.');
        return null;
      }
      _logger.i('Loaded pest diagnosis "$diagnosisId".');
      return PestDiagnosisRecord.fromFirestore(doc);
    } on _AuthException {
      _logger.w('loadById failed — user not signed in.');
      return null;
    } catch (e, st) {
      _logger.e('Error loading pest diagnosis "$diagnosisId"',
          error: e, stackTrace: st);
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 4 — Delete a diagnosis
  // ══════════════════════════════════════════════════════════════════════════

  /// Deletes a single diagnosis record by its Firestore document ID.
  /// The farmer can call this from the pest history screen.
  static Future<void> deleteDiagnosis(String diagnosisId) async {
    _logger.i('Deleting pest diagnosis "$diagnosisId"');
    try {
      await _diagnosesRef.doc(diagnosisId).delete();
      _logger.i('Deleted pest diagnosis "$diagnosisId".');
    } on _AuthException {
      _logger.e('deleteDiagnosis failed — user not signed in.');
      rethrow;
    } on FirebaseException catch (e) {
      _logger.e('Error deleting pest diagnosis "$diagnosisId"',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 5 — Real-time stream of history
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns a live stream of the farmer's diagnosis history.
  /// Use this in CoffeeUserPestHistoryPage with a StreamBuilder for
  /// real-time updates when a new diagnosis is saved elsewhere.
  static Stream<List<PestDiagnosisRecord>> historyStream({int limit = 30}) {
    _logger.i('Opening real-time pest history stream (limit=$limit)');
    try {
      return _diagnosesRef
          .orderBy('savedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => PestDiagnosisRecord.fromFirestore(doc))
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
  // pest_diagnoses/{userId}/diagnoses path directly (not a collectionGroup
  // scan) since Firestore's security-rule evaluation for collectionGroup
  // queries requires the rule to be provable for the query as a whole and
  // does not reliably honour a plain isAdmin()-style rule the way a query
  // against a single, known parent path does — this mirrors the same rule
  // structure that already works for the owner's own historyStream() above.
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<PestDiagnosisRecord>> diagnosesForUsers(
    List<String> userIds,
  ) async {
    _logger.i('Loading pest diagnoses for ${userIds.length} visible users');
    final records = <PestDiagnosisRecord>[];
    final futures = userIds.map((uid) async {
      try {
        final snapshot = await _db
            .collection(_rootCollection)
            .doc(uid)
            .collection('diagnoses')
            .get();
        return snapshot.docs
            .map((doc) => PestDiagnosisRecord.fromFirestore(doc))
            .toList();
      } on FirebaseException catch (e) {
        _logger.w('Skipping pest diagnoses for user "$uid"', error: e);
        return <PestDiagnosisRecord>[];
      }
    });
    for (final result in await Future.wait(futures)) {
      records.addAll(result);
    }
    _logger.i('Loaded ${records.length} pest diagnoses across visible users');
    return records;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 6 — Clear all history for the current user
  // ══════════════════════════════════════════════════════════════════════════

  /// Deletes ALL diagnosis records for the current user.
  /// Used by a "Clear History" option in settings.
  /// Runs in batches of 500 to respect Firestore batch write limits.
  static Future<void> clearAllHistory() async {
    _logger.i('Clearing ALL pest history for user "$_userId"');
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
        _logger.i('Batch deleted ${snapshot.docs.length} pest records '
            '(total so far: $totalDeleted).');
      }
      _logger
          .i('All pest history cleared. Total records deleted: $totalDeleted.');
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

  /// Returns the total number of diagnosis records saved by the current user.
  /// Returns 0 on error or if not signed in.
  static Future<int> diagnosisCount() async {
    try {
      // count() uses Firestore's aggregation query — does NOT read all docs
      final result = await _diagnosesRef.count().get();
      final count = result.count ?? 0;
      _logger.i('Diagnosis count for current user: $count');
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

  /// If the user already has [_maxHistoryRecords] records, deletes the oldest
  /// one before saving a new record. Keeps storage bounded automatically.
  static Future<void> _enforceRecordLimit() async {
    try {
      final count = await diagnosisCount();
      if (count < _maxHistoryRecords) {
        return;
      }

      _logger.w('Pest record limit reached ($count records). '
          'Deleting oldest record before saving new one.');

      // Find the oldest record
      final oldest = await _diagnosesRef
          .orderBy('savedAt', descending: false)
          .limit(1)
          .get();

      if (oldest.docs.isNotEmpty) {
        final oldestId = oldest.docs.first.id;
        await oldest.docs.first.reference.delete();
        _logger.i('Oldest pest record "$oldestId" deleted to enforce '
            '$_maxHistoryRecords record limit.');
      }
    } on _AuthException {
      _logger.w('_enforceRecordLimit — user not signed in.');
    } catch (e, st) {
      // Non-critical — proceed with save even if limit check fails
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
  String toString() => 'PestFirestoreService: No authenticated user. '
      'Ensure Firebase Auth is initialised and a user is signed in.';
}
