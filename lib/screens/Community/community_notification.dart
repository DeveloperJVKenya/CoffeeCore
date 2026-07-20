import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityNotificationType {
  replyToPost,
  replyToComment,
  acceptedSolution,
  directMessage
}

CommunityNotificationType _typeFromName(String name) {
  return CommunityNotificationType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => CommunityNotificationType.replyToPost,
  );
}

/// A single entry in a user's in-app notification center — lives at
/// `user_notifications/{recipientUid}/items/{id}`. Written by the *other*
/// user's client as a side effect of commenting, replying, accepting a
/// solution, or sending a direct message (see CommunityRepositoryImpl and
/// DirectMessageController). This is an in-app-only feed, not push — it only
/// updates while the app is open, same as the existing DM unread badge.
class CommunityNotification {
  final String id;
  final CommunityNotificationType type;
  final String actorName;
  final String message;
  final String? postId;
  final String? commentId;
  final String? roomId;
  final bool isRead;
  final DateTime createdAt;

  const CommunityNotification({
    required this.id,
    required this.type,
    required this.actorName,
    required this.message,
    this.postId,
    this.commentId,
    this.roomId,
    required this.isRead,
    required this.createdAt,
  });

  factory CommunityNotification.fromJson(Map<String, dynamic> json, String id) {
    return CommunityNotification(
      id: id,
      type: _typeFromName(json['type'] as String? ?? ''),
      actorName: json['actor_name'] as String? ?? 'Someone',
      message: json['message'] as String? ?? '',
      postId: json['post_id'] as String?,
      commentId: json['comment_id'] as String?,
      roomId: json['room_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'actor_name': actorName,
      'message': message,
      'post_id': postId,
      'comment_id': commentId,
      'room_id': roomId,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
