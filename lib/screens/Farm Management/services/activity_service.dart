import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Farm%20Management/models/activity_model.dart';

/// Firestore CRUD for the `FarmActivities` collection, plus Storage upload
/// for activity photos following the same platform-branch pattern used by
/// `manuals_screen.dart` (path `farm_activities/{farmId}/{timestampMs}_{fileName}`).
class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _collection = 'FarmActivities';

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<FarmActivity>> activitiesForFarm(String farmId,
      {String? cycleId}) {
    if (_uid == null) {
      _log.w('ActivityService.activitiesForFarm: No authenticated user');
      return Stream.value([]);
    }
    Query<Map<String, dynamic>> query =
        _firestore.collection(_collection).where('farmId', isEqualTo: farmId);
    if (cycleId != null) {
      query = query.where('cycleId', isEqualTo: cycleId);
    }
    return query
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FarmActivity.fromFirestore(d)).toList())
        .handleError((Object e, StackTrace st) {
      _log.e('ActivityService.activitiesForFarm: Stream error – $e',
          stackTrace: st);
      return <FarmActivity>[];
    });
  }

  Future<String> addActivity(FarmActivity activity) async {
    try {
      final ref =
          await _firestore.collection(_collection).add(activity.toFirestore());
      _log.i('ActivityService.addActivity: Added activity ${ref.id}');
      return ref.id;
    } catch (e, st) {
      _log.e('ActivityService.addActivity: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateActivity(FarmActivity activity) async {
    if (activity.id == null) {
      throw ArgumentError(
          'ActivityService.updateActivity: activity.id is null');
    }
    try {
      await _firestore
          .collection(_collection)
          .doc(activity.id)
          .update(activity.toFirestore());
    } catch (e, st) {
      _log.e('ActivityService.updateActivity: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteActivity(String activityId) async {
    try {
      await _firestore.collection(_collection).doc(activityId).delete();
    } catch (e, st) {
      _log.e('ActivityService.deleteActivity: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  /// Uploads a single activity photo, following the manuals_screen.dart
  /// putData/putFile platform-branch pattern, and returns the download URL.
  Future<String> uploadActivityPhoto({
    required String farmId,
    required String fileName,
    required Uint8List? webBytes,
    required File? nativeFile,
  }) async {
    if (_uid == null) {
      throw StateError(
          'ActivityService.uploadActivityPhoto: No authenticated user');
    }
    final storageRef = FirebaseStorage.instance.ref().child(
        'farm_activities/$farmId/${DateTime.now().millisecondsSinceEpoch}_$fileName');

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'uploadedBy': _uid!, 'originalName': fileName},
    );

    late UploadTask uploadTask;
    if (kIsWeb) {
      if (webBytes == null) {
        throw ArgumentError(
            'ActivityService.uploadActivityPhoto: webBytes required on web');
      }
      uploadTask = storageRef.putData(webBytes, metadata);
    } else {
      if (nativeFile == null) {
        throw ArgumentError(
            'ActivityService.uploadActivityPhoto: nativeFile required on native platforms');
      }
      uploadTask = storageRef.putFile(nativeFile, metadata);
    }

    await uploadTask;
    final url = await storageRef.getDownloadURL();
    _log.i('ActivityService.uploadActivityPhoto: Uploaded $fileName -> $url');
    return url;
  }
}
