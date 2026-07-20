import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Community/community_notification.dart';
import 'package:coffeecore/screens/Community/community_notification_service.dart';
import 'package:coffeecore/screens/Community/dm/direct_message_models.dart';
import 'package:coffeecore/screens/Community/user_mini_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final directMessageControllerProvider =
    Provider<DirectMessageController>((ref) {
  return DirectMessageController(
      FirebaseFirestore.instance, FirebaseAuth.instance);
});

class DirectMessageController {
  DirectMessageController(this._firestore, this._auth)
      : _notifications = CommunityNotificationService(_firestore, _auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final CommunityNotificationService _notifications;
  final Logger _logger = Logger(printer: PrettyPrinter());
  final Set<String> _roomsBeingMarkedRead = <String>{};

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('chat_rooms');

  String get currentUserId {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('Must be signed in to use direct messages.');
    }
    return userId;
  }

  static String buildRoomId(String userA, String userB) {
    final sorted = <String>[userA, userB]..sort();
    return '${sorted.first}__${sorted.last}';
  }

  Stream<List<DirectMessageRoom>> watchInboxRooms(String userId) {
    return _rooms
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DirectMessageRoom.fromDoc(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Stream<DirectMessageRoom?> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return DirectMessageRoom.fromDoc(doc.id, doc.data()!);
    });
  }

  Stream<List<DirectMessage>> watchMessages(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DirectMessage.fromDoc(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<String> openOrCreateRoom({
    required UserMiniProfile recipient,
    DirectMessageContext? context,
  }) async {
    final sender = _auth.currentUser;
    if (sender == null) {
      throw StateError('Must be signed in to start a chat.');
    }
    if (sender.uid == recipient.uid) {
      throw StateError('You cannot create a direct chat with yourself.');
    }

    final roomId = buildRoomId(sender.uid, recipient.uid);
    final roomRef = _rooms.doc(roomId);
    final senderProfile = UserMiniProfile(
      uid: sender.uid,
      displayName: sender.displayName ?? 'Anonymous Farmer',
      avatarUrl: sender.photoURL,
    );

    try {
      _logger.i('Opening or creating direct chat room: $roomId');

      await _firestore.runTransaction((tx) async {
        final existingRoom = await tx.get(roomRef);

        final base = <String, dynamic>{
          'roomId': roomId,
          'participants': <String>[sender.uid, recipient.uid],
          'participantDisplayNames': <String, String>{
            senderProfile.uid: senderProfile.displayName,
            recipient.uid: recipient.displayName,
          },
          'participantAvatarUrls': <String, String>{
            senderProfile.uid: senderProfile.avatarUrl ?? '',
            recipient.uid: recipient.avatarUrl ?? '',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (!existingRoom.exists) {
          tx.set(roomRef, <String, dynamic>{
            ...base,
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': null,
            'lastMessageSenderId': null,
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'lastMessageIsRead': true,
            'contextPostId': context?.postId,
            'contextPostTitle': context?.title,
            'contextPostSnippet': context?.snippet,
            'contextThumbnailUrl': context?.thumbnailUrl,
          });
          return;
        }

        final updates = <String, dynamic>{...base};
        if (context != null) {
          updates.addAll(<String, dynamic>{
            'contextPostId': context.postId,
            'contextPostTitle': context.title,
            'contextPostSnippet': context.snippet,
            'contextThumbnailUrl': context.thumbnailUrl,
          });
        }
        tx.update(roomRef, updates);
      });

      _logger.i('Direct chat room ready: $roomId');
    } catch (error, stackTrace) {
      _logFirebaseFailure(
        operation: 'openOrCreateRoom',
        roomId: roomId,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    return roomId;
  }

  Future<void> sendMessage({
    required String roomId,
    required String text,
  }) async {
    final senderId = currentUserId;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw StateError('Message cannot be empty.');
    }

    final roomRef = _rooms.doc(roomId);
    final messageRef = roomRef.collection('messages').doc();
    final batch = _firestore.batch();

    batch.set(messageRef, <String, dynamic>{
      'messageId': messageRef.id,
      'senderId': senderId,
      'text': trimmed,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    batch.update(roomRef, <String, dynamic>{
      'lastMessage': trimmed,
      'lastMessageSenderId': senderId,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageIsRead': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      _logger.i('Sending direct message to room: $roomId');
      await batch.commit();
      _logger.i('Direct message sent to room: $roomId');
    } catch (error, stackTrace) {
      _logFirebaseFailure(
        operation: 'sendMessage',
        roomId: roomId,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    await _notifyRecipient(
        roomId: roomId, senderId: senderId, preview: trimmed);
  }

  Future<void> _notifyRecipient({
    required String roomId,
    required String senderId,
    required String preview,
  }) async {
    try {
      final roomSnap = await _rooms.doc(roomId).get();
      final participants = List<String>.from(
          roomSnap.data()?['participants'] as List<dynamic>? ?? const []);
      final recipientId =
          participants.firstWhere((id) => id != senderId, orElse: () => '');
      if (recipientId.isEmpty) return;

      await _notifications.notify(
        recipientId: recipientId,
        type: CommunityNotificationType.directMessage,
        message: preview,
        roomId: roomId,
      );
    } catch (error, stackTrace) {
      _logger.e('Failed to send DM notification',
          error: error, stackTrace: stackTrace);
    }
  }

  Future<void> markRoomMessagesAsRead(String roomId) async {
    final userId = currentUserId;
    if (_roomsBeingMarkedRead.contains(roomId)) {
      return;
    }

    _roomsBeingMarkedRead.add(roomId);
    try {
      final roomRef = _rooms.doc(roomId);
      final unreadSnapshot = await roomRef
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final batch = _firestore.batch();
      var hasIncomingUnread = false;

      for (final doc in unreadSnapshot.docs) {
        final data = doc.data();
        if ((data['senderId'] as String?) == userId) {
          continue;
        }
        hasIncomingUnread = true;
        batch.update(doc.reference, <String, dynamic>{'isRead': true});
      }

      if (hasIncomingUnread) {
        batch.update(roomRef, <String, dynamic>{
          'lastMessageIsRead': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
      }
      _logger.i('Marked direct messages read for room: $roomId');
    } catch (error, stackTrace) {
      _logFirebaseFailure(
        operation: 'markRoomMessagesAsRead',
        roomId: roomId,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      _roomsBeingMarkedRead.remove(roomId);
    }
  }

  DirectMessageContext contextFromPost({
    required String postId,
    required String title,
    required String description,
    String? thumbnailUrl,
  }) {
    return DirectMessageContext(
      postId: postId,
      title: title,
      snippet: _buildSnippet(description),
      thumbnailUrl: thumbnailUrl,
    );
  }

  String _buildSnippet(String description) {
    const maxLength = 140;
    if (description.length <= maxLength) {
      return description;
    }
    return '${description.substring(0, maxLength)}...';
  }

  void _logFirebaseFailure({
    required String operation,
    required String roomId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (error is FirebaseException) {
      _logger.e(
        'Direct message $operation failed for roomId=$roomId with FirebaseException code=${error.code}, message=${error.message}',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _logger.e(
      'Direct message $operation failed for roomId=$roomId with ${error.runtimeType}: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
