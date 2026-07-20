import 'package:cloud_firestore/cloud_firestore.dart';

class DirectMessageContext {
  final String postId;
  final String title;
  final String snippet;
  final String? thumbnailUrl;

  const DirectMessageContext({
    required this.postId,
    required this.title,
    required this.snippet,
    this.thumbnailUrl,
  });
}

class DirectMessageRoom {
  final String roomId;
  final List<String> participants;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTimestamp;
  final bool lastMessageIsRead;
  final String? contextPostId;
  final String? contextPostTitle;
  final String? contextPostSnippet;
  final String? contextThumbnailUrl;
  final Map<String, String> participantDisplayNames;
  final Map<String, String> participantAvatarUrls;

  const DirectMessageRoom({
    required this.roomId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageTimestamp,
    required this.lastMessageIsRead,
    required this.contextPostId,
    required this.contextPostTitle,
    required this.contextPostSnippet,
    required this.contextThumbnailUrl,
    required this.participantDisplayNames,
    required this.participantAvatarUrls,
  });

  factory DirectMessageRoom.fromDoc(
    String roomId,
    Map<String, dynamic> data,
  ) {
    final rawNames = data['participantDisplayNames'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final rawAvatars = data['participantAvatarUrls'] as Map<String, dynamic>? ??
        <String, dynamic>{};

    return DirectMessageRoom(
      roomId: roomId,
      participants: List<String>.from(
          data['participants'] as List<dynamic>? ?? const <String>[]),
      lastMessage: data['lastMessage'] as String?,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      lastMessageTimestamp:
          (data['lastMessageTimestamp'] as Timestamp?)?.toDate(),
      lastMessageIsRead: data['lastMessageIsRead'] as bool? ?? true,
      contextPostId: data['contextPostId'] as String?,
      contextPostTitle: data['contextPostTitle'] as String?,
      contextPostSnippet: data['contextPostSnippet'] as String?,
      contextThumbnailUrl: data['contextThumbnailUrl'] as String?,
      participantDisplayNames: {
        for (final entry in rawNames.entries)
          entry.key: (entry.value ?? '').toString(),
      },
      participantAvatarUrls: {
        for (final entry in rawAvatars.entries)
          entry.key: (entry.value ?? '').toString(),
      },
    );
  }
}

class DirectMessage {
  final String messageId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  const DirectMessage({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isRead,
  });

  factory DirectMessage.fromDoc(String messageId, Map<String, dynamic> data) {
    return DirectMessage(
      messageId: messageId,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }
}
