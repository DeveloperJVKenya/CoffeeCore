import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/ndvi_history_entry_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/planetek_analysis_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class FarmMappingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _collection = 'FarmPolygons';

  String? get _uid => _auth.currentUser?.uid;

  // ── CREATE ──────────────────────────────────────────────────

  Future<String?> saveFarm(FarmPolygon farm) async {
    if (_uid == null) {
      _log.e('FarmMappingService.saveFarm: No authenticated user');
      return null;
    }
    try {
      _log.i(
        'FarmMappingService.saveFarm: Saving "${farm.farmName}" '
        '(${farm.coordinates.length} pts, ${farm.areaLabel}) for user $_uid',
      );
      final ref =
          await _firestore.collection(_collection).add(farm.toFirestore());
      _log.i('FarmMappingService.saveFarm: Saved with ID ${ref.id}');
      return ref.id;
    } catch (e, st) {
      _log.e('FarmMappingService.saveFarm: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  // ── READ (stream) ───────────────────────────────────────────

  Stream<List<FarmPolygon>> userFarmsStream() {
    if (_uid == null) {
      _log.w('FarmMappingService.userFarmsStream: No authenticated user');
      return Stream.value([]);
    }
    _log.i(
      'FarmMappingService.userFarmsStream: Subscribing for user $_uid',
    );
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      _log.i(
        'FarmMappingService.userFarmsStream: '
        'Received ${snap.docs.length} farm(s)',
      );
      return snap.docs
          .map((d) => FarmPolygon.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    }).handleError((Object e, StackTrace st) {
      _log.e(
        'FarmMappingService.userFarmsStream: Stream error – $e',
        stackTrace: st,
      );
      return <FarmPolygon>[];
    });
  }

  // ── READ (all farms, all users – admin/export use only) ─────

  Future<List<FarmPolygon>> fetchAllFarms() async {
    try {
      _log.i('FarmMappingService.fetchAllFarms: Fetching all farms');
      final snap = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();
      final farms = snap.docs.map((d) => FarmPolygon.fromFirestore(d)).toList();
      _log.i(
          'FarmMappingService.fetchAllFarms: ${farms.length} farm(s) loaded');
      return farms;
    } catch (e, st) {
      _log.e('FarmMappingService.fetchAllFarms: Error – $e', stackTrace: st);
      return [];
    }
  }

  // ── READ (single fetch) ─────────────────────────────────────

  Future<FarmPolygon?> getFarmById(String farmId) async {
    try {
      _log.i('FarmMappingService.getFarmById: Fetching farm $farmId');
      final doc = await _firestore.collection(_collection).doc(farmId).get();
      if (!doc.exists) {
        _log.w('FarmMappingService.getFarmById: Farm $farmId not found');
        return null;
      }
      return FarmPolygon.fromFirestore(doc);
    } catch (e, st) {
      _log.e('FarmMappingService.getFarmById: Error – $e', stackTrace: st);
      return null;
    }
  }

  // ── UPDATE (full document) ──────────────────────────────────

  Future<void> updateFarm(FarmPolygon farm) async {
    if (farm.farmId == null) {
      throw ArgumentError('FarmMappingService.updateFarm: farmId is null');
    }
    try {
      _log.i(
        'FarmMappingService.updateFarm: Updating farm ${farm.farmId}',
      );
      final updated = farm.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_collection)
          .doc(farm.farmId)
          .update(updated.toFirestore());
      _log.i(
        'FarmMappingService.updateFarm: Farm ${farm.farmId} updated OK',
      );
    } catch (e, st) {
      _log.e('FarmMappingService.updateFarm: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  // ── UPDATE (partial – climate data) ────────────────────────

  Future<void> updateClimateData(String farmId, ClimateData climate) async {
    try {
      _log.i(
        'FarmMappingService.updateClimateData: '
        'Updating farm $farmId climate data',
      );
      await _firestore.collection(_collection).doc(farmId).update({
        'climateData': climate.toMap(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _log.i(
        'FarmMappingService.updateClimateData: Climate data updated '
        'for farm $farmId (${climate.temperatureCelsius}°C, '
        '${climate.humidity}% RH)',
      );
    } catch (e, st) {
      _log.e(
        'FarmMappingService.updateClimateData: Error – $e',
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── UPDATE (partial – satellite / NDVI data) ────────────────

  Future<void> updateSatelliteData(
      String farmId, SatelliteData satellite) async {
    try {
      _log.i(
        'FarmMappingService.updateSatelliteData: '
        'Updating farm $farmId satellite data',
      );
      await _firestore.collection(_collection).doc(farmId).update({
        'satelliteData': satellite.toMap(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _log.i(
        'FarmMappingService.updateSatelliteData: Satellite data updated '
        'for farm $farmId (NDVI: ${satellite.ndviScore.toStringAsFixed(3)}, '
        'Health: ${satellite.vegetationHealth})',
      );
    } catch (e, st) {
      _log.e(
        'FarmMappingService.updateSatelliteData: Error – $e',
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── UPDATE (partial – AgroMonitoring polygon ID) ────────────

  Future<void> setAgroMonitoringPolyId(String farmId, String polyId) async {
    try {
      _log.i(
        'FarmMappingService.setAgroMonitoringPolyId: '
        'Farm $farmId → AgroMonitoring polyId $polyId',
      );
      await _firestore.collection(_collection).doc(farmId).update({
        'agroMonitoringPolyId': polyId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e, st) {
      _log.e(
        'FarmMappingService.setAgroMonitoringPolyId: Error – $e',
        stackTrace: st,
      );
    }
  }

  // ── UPDATE (rename) ─────────────────────────────────────────

  Future<void> renameFarm(String farmId, String newName) async {
    try {
      _log.i(
        'FarmMappingService.renameFarm: '
        'Renaming farm $farmId to "$newName"',
      );
      await _firestore.collection(_collection).doc(farmId).update({
        'farmName': newName.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _log.i(
        'FarmMappingService.renameFarm: Farm $farmId renamed to "$newName"',
      );
    } catch (e, st) {
      _log.e('FarmMappingService.renameFarm: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  // ── UPDATE (partial – EUDR compliance data) ────────────────

  Future<void> updateEudrCompliance(
      String farmId, EudrComplianceData data) async {
    try {
      _log.i(
        'FarmMappingService.updateEudrCompliance: '
        'Updating farm $farmId EUDR status → ${data.isCompliant ? "COMPLIANT" : "NON-COMPLIANT"}',
      );
      await _firestore.collection(_collection).doc(farmId).update({
        'eudrCompliance': data.toMap(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _log.i(
        'FarmMappingService.updateEudrCompliance: '
        'EUDR data saved for farm $farmId (treeCover2000: ${data.treeCoverPercent2000.toStringAsFixed(1)}%)',
      );
    } catch (e, st) {
      _log.e(
        'FarmMappingService.updateEudrCompliance: Error – $e',
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── UPDATE (partial – Planetek certified EUDR analysis) ─────
  //
  // Independent of updateEudrCompliance above — stored as a separate
  // Firestore field (planetekAnalysis) alongside eudrCompliance, never
  // overwriting it, since the two are deliberately kept as two distinct
  // EUDR data sources (GFW screening vs. Planetek certified analysis).

  Future<void> updatePlanetekAnalysis(
      String farmId, PlanetekAnalysisData data) async {
    try {
      _log.i(
        'FarmMappingService.updatePlanetekAnalysis: '
        'Updating farm $farmId Planetek status → '
        'certified=${data.deforestationCertified}, '
        'signatureVerified=${data.signatureVerified}',
      );
      await _firestore.collection(_collection).doc(farmId).update({
        'planetekAnalysis': data.toMap(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _log.i(
        'FarmMappingService.updatePlanetekAnalysis: '
        'Planetek data saved for farm $farmId',
      );
    } catch (e, st) {
      _log.e(
        'FarmMappingService.updatePlanetekAnalysis: Error – $e',
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── UPDATE (partial – boundary overlap flags) ───────────────
  //
  // Two different farmers' polygons overlapping is a real EUDR
  // fraud/data-integrity signal (see BoundaryOverlapService) — kept as its
  // own field, independent of eudrCompliance/planetekAnalysis, since it's
  // a geometry check against sibling farms, not a deforestation check.

  Future<void> updateBoundaryOverlap(
      String farmId, List<String> overlappingFarmIds) async {
    try {
      _log.i(
        'FarmMappingService.updateBoundaryOverlap: '
        'Farm $farmId overlaps with ${overlappingFarmIds.length} other farm(s)',
      );
      await _firestore.collection(_collection).doc(farmId).update({
        'overlapsWithFarmIds': overlappingFarmIds,
        'overlapCheckedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e, st) {
      _log.e(
        'FarmMappingService.updateBoundaryOverlap: Error – $e',
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── NDVI/NDWI HISTORY (subcollection) ───────────────────────
  //
  // Each satellite refresh appends a snapshot here so trends (e.g. for the
  // Drought Risk Index) can be computed later. This is purely additive —
  // existing farms simply start with an empty subcollection.

  Future<void> appendNdviHistoryEntry(
      String farmId, NdviHistoryEntry entry) async {
    try {
      _log.i(
        'FarmMappingService.appendNdviHistoryEntry: '
        'Farm $farmId ← NDVI=${entry.ndvi.toStringAsFixed(3)}'
        '${entry.ndwi != null ? ", NDWI=${entry.ndwi!.toStringAsFixed(3)}" : ""}',
      );
      await _firestore
          .collection(_collection)
          .doc(farmId)
          .collection('ndviHistory')
          .add(entry.toMap());
    } catch (e, st) {
      _log.e(
        'FarmMappingService.appendNdviHistoryEntry: Error – $e',
        stackTrace: st,
      );
    }
  }

  Future<List<NdviHistoryEntry>> fetchRecentNdviHistory(
    String farmId, {
    int limit = 12,
  }) async {
    try {
      _log.i(
        'FarmMappingService.fetchRecentNdviHistory: '
        'Fetching last $limit entries for farm $farmId',
      );
      final snap = await _firestore
          .collection(_collection)
          .doc(farmId)
          .collection('ndviHistory')
          .orderBy('fetchedAt', descending: true)
          .limit(limit)
          .get();
      final entries = snap.docs
          .map((d) => NdviHistoryEntry.fromMap(d.data()))
          .toList()
          .reversed
          .toList();
      _log.i(
        'FarmMappingService.fetchRecentNdviHistory: '
        '${entries.length} entries loaded for farm $farmId',
      );
      return entries;
    } catch (e, st) {
      _log.e(
        'FarmMappingService.fetchRecentNdviHistory: Error – $e',
        stackTrace: st,
      );
      return [];
    }
  }

  // ── DELETE ──────────────────────────────────────────────────

  Future<void> deleteFarm(String farmId) async {
    try {
      _log.i('FarmMappingService.deleteFarm: Deleting farm $farmId');
      await _firestore.collection(_collection).doc(farmId).delete();
      _log.i(
        'FarmMappingService.deleteFarm: Farm $farmId deleted successfully',
      );
    } catch (e, st) {
      _log.e('FarmMappingService.deleteFarm: Error – $e', stackTrace: st);
      rethrow;
    }
  }
}
