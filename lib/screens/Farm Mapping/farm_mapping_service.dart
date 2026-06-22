import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Farm%20Mapping/farm_polygon_model.dart';
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
      final ref = await _firestore
          .collection(_collection)
          .add(farm.toFirestore());
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

  Future<void> updateClimateData(
      String farmId, ClimateData climate) async {
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

  Future<void> setAgroMonitoringPolyId(
      String farmId, String polyId) async {
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