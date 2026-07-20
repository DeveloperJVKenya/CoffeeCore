import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coffeecore/screens/Community/community_notification.dart';

final communityNotificationServiceProvider =
    Provider<CommunityNotificationService>((ref) {
  return CommunityNotificationService(
      FirebaseFirestore.instance, FirebaseAuth.instance);
});

class CommunityNotificationService {
  CommunityNotificationService(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _itemsFor(String userId) =>
      _firestore
          .collection('user_notifications')
          .doc(userId)
          .collection('items');

  /// No-op if [recipientId] is the current user (never notify yourself for
  /// your own comment/reply/DM).
  Future<void> notify({
    required String recipientId,
    required CommunityNotificationType type,
    required String message,
    String? postId,
    String? commentId,
    String? roomId,
  }) async {
    final actor = _auth.currentUser;
    if (actor == null || actor.uid == recipientId) return;

    await _itemsFor(recipientId).add({
      'type': type.name,
      'actor_name': actor.displayName ?? 'Anonymous Farmer',
      'message': message,
      'post_id': postId,
      'comment_id': commentId,
      'room_id': roomId,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CommunityNotification>> watchNotifications(String userId) {
    return _itemsFor(userId)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommunityNotification.fromJson(doc.data(), doc.id))
            .toList(growable: false));
  }

  Stream<int> watchUnreadCount(String userId) {
    return _itemsFor(userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAllRead(String userId) async {
    final unread =
        await _itemsFor(userId).where('is_read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }
}
