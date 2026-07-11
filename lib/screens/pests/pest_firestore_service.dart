import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
    debugPrint('[PestFirestore] 💾 Saving diagnosis for '
        '"$pestName" | stage="$stage" | mode="$detectionMode"');

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
      debugPrint('[PestFirestore] ✅ Saved with Firestore ID: ${docRef.id}');
      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('[PestFirestore] ❌ Firestore write error: '
          'code=${e.code} message="${e.message}"');
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
    debugPrint('[PestFirestore] 📋 Loading history (limit=$limit)');

    try {
      final snapshot = await _diagnosesRef
          .orderBy('savedAt', descending: true)
          .limit(limit.clamp(1, _maxHistoryRecords))
          .get();

      final records = snapshot.docs
          .map((doc) => PestDiagnosisRecord.fromFirestore(doc))
          .toList();

      debugPrint('[PestFirestore] ✅ Loaded ${records.length} records.');
      return records;
    } on _AuthException {
      debugPrint('[PestFirestore] ⚠️ Not signed in — returning empty history.');
      return [];
    } on FirebaseException catch (e) {
      debugPrint('[PestFirestore] ❌ Firestore load error: '
          'code=${e.code} message="${e.message}"');
      return [];
    } catch (e) {
      debugPrint('[PestFirestore] ❌ Unexpected loadHistory error: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 3 — Load a single diagnosis by ID
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetches a single diagnosis record by its Firestore document ID.
  /// Returns null if not found or on error.
  static Future<PestDiagnosisRecord?> loadById(String diagnosisId) async {
    debugPrint(
        '[PestFirestore] 🔍 Loading single record by ID: "$diagnosisId"');
    try {
      final doc = await _diagnosesRef.doc(diagnosisId).get();
      if (!doc.exists || doc.data() == null) {
        debugPrint('[PestFirestore] ⚠️ Record "$diagnosisId" not found '
            'or has no data.');
        return null;
      }
      debugPrint('[PestFirestore] ✅ Loaded record "$diagnosisId".');
      return PestDiagnosisRecord.fromFirestore(doc);
    } on _AuthException {
      debugPrint('[PestFirestore] ⚠️ loadById failed — user not signed in.');
      return null;
    } catch (e) {
      debugPrint('[PestFirestore] ❌ loadById error for "$diagnosisId": $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 4 — Delete a diagnosis
  // ══════════════════════════════════════════════════════════════════════════

  /// Deletes a single diagnosis record by its Firestore document ID.
  /// The farmer can call this from the pest history screen.
  static Future<void> deleteDiagnosis(String diagnosisId) async {
    debugPrint('[PestFirestore] 🗑 Deleting diagnosis "$diagnosisId"');
    try {
      await _diagnosesRef.doc(diagnosisId).delete();
      debugPrint('[PestFirestore] ✅ Deleted "$diagnosisId".');
    } on _AuthException {
      debugPrint(
          '[PestFirestore] ❌ deleteDiagnosis failed — user not signed in.');
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('[PestFirestore] ❌ Delete error for "$diagnosisId": '
          'code=${e.code} message="${e.message}"');
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
    debugPrint('[PestFirestore] 🔴 Opening real-time history stream '
        '(limit=$limit)');
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
      debugPrint('[PestFirestore] ⚠️ historyStream — user not signed in. '
          'Returning empty stream.');
      return const Stream.empty();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 6 — Clear all history for the current user
  // ══════════════════════════════════════════════════════════════════════════

  /// Deletes ALL diagnosis records for the current user.
  /// Used by a "Clear History" option in settings.
  /// Runs in batches of 500 to respect Firestore batch write limits.
  static Future<void> clearAllHistory() async {
    debugPrint('[PestFirestore] 🗑 Clearing ALL history for user "$_userId"');
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
        debugPrint('[PestFirestore] 🗑 Batch deleted ${snapshot.docs.length} '
            'records (total so far: $totalDeleted).');
      }
      debugPrint('[PestFirestore] ✅ All history cleared. '
          'Total records deleted: $totalDeleted.');
    } on _AuthException {
      debugPrint('[PestFirestore] ❌ clearAllHistory — user not signed in.');
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('[PestFirestore] ❌ clearAllHistory error: '
          'code=${e.code} message="${e.message}"');
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
      debugPrint('[PestFirestore] 🔢 Diagnosis count for current user: $count');
      return count;
    } on _AuthException {
      debugPrint('[PestFirestore] ⚠️ diagnosisCount — user not signed in. '
          'Returning 0.');
      return 0;
    } catch (e) {
      debugPrint('[PestFirestore] ❌ diagnosisCount error: $e');
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
        debugPrint(
            '[PestFirestore] 📊 Record count $count / $_maxHistoryRecords '
            '— within limit, no deletion needed.');
        return;
      }

      debugPrint('[PestFirestore] ⚠️ Record limit reached ($count records). '
          'Deleting oldest record before saving new one.');

      // Find the oldest record
      final oldest = await _diagnosesRef
          .orderBy('savedAt', descending: false)
          .limit(1)
          .get();

      if (oldest.docs.isNotEmpty) {
        final oldestId = oldest.docs.first.id;
        await oldest.docs.first.reference.delete();
        debugPrint('[PestFirestore] 🗑 Oldest record "$oldestId" deleted '
            'to enforce $_maxHistoryRecords record limit.');
      }
    } on _AuthException {
      debugPrint(
          '[PestFirestore] ⚠️ _enforceRecordLimit — user not signed in.');
    } catch (e) {
      // Non-critical — proceed with save even if limit check fails
      debugPrint(
          '[PestFirestore] ⚠️ Record limit check failed (non-critical): $e '
          '— proceeding with save anyway.');
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
