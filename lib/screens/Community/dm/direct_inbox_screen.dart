import 'package:coffeecore/screens/Community/dm/direct_chat_screen.dart';
import 'package:coffeecore/screens/Community/dm/direct_message_controller.dart';
import 'package:coffeecore/screens/Community/dm/direct_message_models.dart';
import 'package:coffeecore/screens/Community/dm/dm_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class DirectInboxScreen extends ConsumerWidget {
  const DirectInboxScreen({super.key});

  static final Logger _logger = Logger(printer: PrettyPrinter());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(directMessageControllerProvider);
    final currentUserId = controller.currentUserId;

    return Scaffold(
      backgroundColor: CoffeeCoreDm.canvas,
      appBar: AppBar(
        backgroundColor: CoffeeCoreDm.mocha,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text('Direct Messages',
            style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<DirectMessageRoom>>(
        stream: controller.watchInboxRooms(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: CoffeeCoreDm.mocha),
            );
          }
          if (snapshot.hasError) {
            _logFirebaseFailure(
              'watchInboxRooms',
              snapshot.error ?? StateError('Unknown inbox error'),
              snapshot.stackTrace ?? StackTrace.current,
            );
            return const Center(
                child: Text('Could not load your direct messages.'));
          }

          final rooms = snapshot.data ?? const <DirectMessageRoom>[];
          if (rooms.isEmpty) {
            return const Center(
              child: Text('No active chats yet. Start from a post or comment.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final peerId = room.participants.firstWhere(
                (participantId) => participantId != currentUserId,
                orElse: () => currentUserId,
              );
              final peerName = room.participantDisplayNames[peerId]?.trim();
              final peerAvatarUrl = room.participantAvatarUrls[peerId]?.trim();
              final hasUnread = room.lastMessageSenderId != null &&
                  room.lastMessageSenderId != currentUserId &&
                  room.lastMessageIsRead == false;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PressableScale(
                  borderRadius: BorderRadius.circular(CoffeeCoreDm.cardRadius),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DirectChatScreen(roomId: room.roomId),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(CoffeeCoreDm.cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: CoffeeCoreDm.espresso.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'dm_avatar_${room.roomId}',
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                CoffeeCoreDm.latte.withValues(alpha: 0.25),
                            backgroundImage: (peerAvatarUrl != null &&
                                    peerAvatarUrl.isNotEmpty)
                                ? NetworkImage(peerAvatarUrl)
                                : null,
                            child: (peerAvatarUrl == null ||
                                    peerAvatarUrl.isEmpty)
                                ? Text(
                                    (peerName != null && peerName.isNotEmpty)
                                        ? peerName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: CoffeeCoreDm.brew,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      peerName == null || peerName.isEmpty
                                          ? 'Unknown user'
                                          : peerName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: CoffeeCoreDm.espresso,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTimestamp(room.lastMessageTimestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: CoffeeCoreDm.mocha
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      room.lastMessage?.trim().isNotEmpty ==
                                              true
                                          ? room.lastMessage!
                                          : 'No messages yet',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: hasUnread
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: hasUnread
                                            ? CoffeeCoreDm.espresso
                                            : CoffeeCoreDm.mocha
                                                .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                  if (hasUnread) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: const BoxDecoration(
                                        color: CoffeeCoreDm.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return '';
    }
    final now = DateTime.now();
    final isToday = now.year == timestamp.year &&
        now.month == timestamp.month &&
        now.day == timestamp.day;
    if (isToday) {
      return DateFormat('h:mm a').format(timestamp);
    }
    return DateFormat('MMM d').format(timestamp);
  }

  void _logFirebaseFailure(
      String operation, Object error, StackTrace stackTrace) {
    if (error is FirebaseException) {
      _logger.e(
        'Direct inbox $operation failed with FirebaseException code=${error.code}, message=${error.message}',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _logger.e(
      'Direct inbox $operation failed with ${error.runtimeType}: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
