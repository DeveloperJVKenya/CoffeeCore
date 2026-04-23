import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
      id:             doc.id,
      diseaseName:    d['diseaseName']    as String? ?? 'Unknown Disease',
      stage:          d['stage']          as String? ?? '',
      detectionMode:  d['detectionMode']  as String? ?? '',
      managementData: (d['managementData'] as Map<String, dynamic>?) ?? {},
      imageUrls:      List<String>.from(d['imageUrls'] ?? []),
      aiConfidence:   (d['aiConfidence'] as num?)?.toDouble(),
      aiReasoning:    d['aiReasoning']   as String?,
      savedAt: (d['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'diseaseName'    : diseaseName,
    'stage'          : stage,
    'detectionMode'  : detectionMode,
    'managementData' : managementData,
    'imageUrls'      : imageUrls,
    'aiConfidence'   : aiConfidence,
    'aiReasoning'    : aiReasoning,
    'savedAt'        : FieldValue.serverTimestamp(),
    'appVersion'     : '1.0.0',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseFirestoreService {
  DiseaseFirestoreService._(); // prevent instantiation

  static final FirebaseFirestore _db   = FirebaseFirestore.instance;
  static final FirebaseAuth      _auth = FirebaseAuth.instance;

  static const int    _maxHistoryRecords = 100;
  static const String _rootCollection    = 'disease_diagnoses';

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
    required String               diseaseName,
    required String               stage,
    required String               detectionMode,
    required Map<String, dynamic> managementData,
    required List<String>         imageUrls,
    double?                       aiConfidence,
    String?                       aiReasoning,
  }) async {
    debugPrint('[DiseaseFirestore] 💾 Saving diagnosis for '
        '"$diseaseName" | stage="$stage" | mode="$detectionMode"');

    final record = DiseaseDiagnosisRecord(
      id:             '',
      diseaseName:    diseaseName,
      stage:          stage,
      detectionMode:  detectionMode,
      managementData: managementData,
      imageUrls:      imageUrls.take(10).toList(),
      aiConfidence:   aiConfidence,
      aiReasoning:    aiReasoning,
      savedAt:        DateTime.now(),
    );

    await _enforceRecordLimit();

    try {
      final docRef = await _diagnosesRef.add(record.toMap());
      debugPrint('[DiseaseFirestore] ✅ Saved with Firestore ID: ${docRef.id}');
      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('[DiseaseFirestore] ❌ Firestore write error: '
          'code=${e.code} message="${e.message}"');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 2 — Load diagnosis history
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<DiseaseDiagnosisRecord>> loadHistory({
    int limit = 20,
  }) async {
    debugPrint('[DiseaseFirestore] 📋 Loading history (limit=$limit)');

    try {
      final snapshot = await _diagnosesRef
          .orderBy('savedAt', descending: true)
          .limit(limit.clamp(1, _maxHistoryRecords))
          .get();

      final records = snapshot.docs
          .map((doc) => DiseaseDiagnosisRecord.fromFirestore(doc))
          .toList();

      debugPrint('[DiseaseFirestore] ✅ Loaded ${records.length} records.');
      return records;

    } on _AuthException {
      debugPrint('[DiseaseFirestore] ⚠️ Not signed in — returning empty history.');
      return [];
    } on FirebaseException catch (e) {
      debugPrint('[DiseaseFirestore] ❌ Firestore load error: '
          'code=${e.code} message="${e.message}"');
      return [];
    } catch (e) {
      debugPrint('[DiseaseFirestore] ❌ Unexpected loadHistory error: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 3 — Load a single diagnosis by ID
  // ══════════════════════════════════════════════════════════════════════════

  static Future<DiseaseDiagnosisRecord?> loadById(String diagnosisId) async {
    debugPrint('[DiseaseFirestore] 🔍 Loading single record: "$diagnosisId"');
    try {
      final doc = await _diagnosesRef.doc(diagnosisId).get();
      if (!doc.exists || doc.data() == null) {
        debugPrint('[DiseaseFirestore] ⚠️ Record "$diagnosisId" not found.');
        return null;
      }
      return DiseaseDiagnosisRecord.fromFirestore(doc);
    } on _AuthException {
      debugPrint('[DiseaseFirestore] ⚠️ loadById failed — user not signed in.');
      return null;
    } catch (e) {
      debugPrint('[DiseaseFirestore] ❌ loadById error for "$diagnosisId": $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 4 — Delete a diagnosis
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> deleteDiagnosis(String diagnosisId) async {
    debugPrint('[DiseaseFirestore] 🗑 Deleting diagnosis "$diagnosisId"');
    try {
      await _diagnosesRef.doc(diagnosisId).delete();
      debugPrint('[DiseaseFirestore] ✅ Deleted "$diagnosisId".');
    } on _AuthException {
      debugPrint('[DiseaseFirestore] ❌ deleteDiagnosis — user not signed in.');
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('[DiseaseFirestore] ❌ Delete error for "$diagnosisId": '
          'code=${e.code} message="${e.message}"');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 5 — Real-time stream of history
  // ══════════════════════════════════════════════════════════════════════════

  static Stream<List<DiseaseDiagnosisRecord>> historyStream({int limit = 30}) {
    debugPrint('[DiseaseFirestore] 🔴 Opening real-time history stream (limit=$limit)');
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
      debugPrint('[DiseaseFirestore] ⚠️ historyStream — user not signed in.');
      return const Stream.empty();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 6 — Clear all history
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> clearAllHistory() async {
    debugPrint('[DiseaseFirestore] 🗑 Clearing ALL history for user "$_userId"');
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
        debugPrint('[DiseaseFirestore] 🗑 Batch deleted ${snapshot.docs.length} '
            'records (total: $totalDeleted).');
      }
      debugPrint('[DiseaseFirestore] ✅ All history cleared. Total: $totalDeleted.');
    } on _AuthException {
      debugPrint('[DiseaseFirestore] ❌ clearAllHistory — user not signed in.');
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('[DiseaseFirestore] ❌ clearAllHistory error: '
          'code=${e.code} message="${e.message}"');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC METHOD 7 — Count total diagnoses
  // ══════════════════════════════════════════════════════════════════════════

  static Future<int> diagnosisCount() async {
    try {
      final result = await _diagnosesRef.count().get();
      final count  = result.count ?? 0;
      debugPrint('[DiseaseFirestore] 🔢 Diagnosis count: $count');
      return count;
    } on _AuthException {
      debugPrint('[DiseaseFirestore] ⚠️ diagnosisCount — user not signed in.');
      return 0;
    } catch (e) {
      debugPrint('[DiseaseFirestore] ❌ diagnosisCount error: $e');
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
        debugPrint('[DiseaseFirestore] 📊 Record count $count / $_maxHistoryRecords '
            '— within limit.');
        return;
      }
      debugPrint('[DiseaseFirestore] ⚠️ Record limit reached ($count). '
          'Deleting oldest record.');
      final oldest = await _diagnosesRef
          .orderBy('savedAt', descending: false)
          .limit(1)
          .get();
      if (oldest.docs.isNotEmpty) {
        final oldestId = oldest.docs.first.id;
        await oldest.docs.first.reference.delete();
        debugPrint('[DiseaseFirestore] 🗑 Oldest record "$oldestId" deleted.');
      }
    } on _AuthException {
      debugPrint('[DiseaseFirestore] ⚠️ _enforceRecordLimit — user not signed in.');
    } catch (e) {
      debugPrint('[DiseaseFirestore] ⚠️ Record limit check failed (non-critical): $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private exception
// ─────────────────────────────────────────────────────────────────────────────

class _AuthException implements Exception {
  const _AuthException();
  @override
  String toString() =>
      'DiseaseFirestoreService: No authenticated user. '
      'Ensure Firebase Auth is initialised and a user is signed in.';
}