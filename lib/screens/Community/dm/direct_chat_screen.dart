import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Community/dm/direct_message_controller.dart';
import 'package:coffeecore/screens/Community/dm/direct_message_models.dart';
import 'package:coffeecore/screens/Community/dm/dm_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  final String roomId;

  const DirectChatScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Logger _logger = Logger(printer: PrettyPrinter());
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await ref.read(directMessageControllerProvider).sendMessage(
            roomId: widget.roomId,
            text: text,
          );
      _messageController.clear();
      _scrollToBottom();
    } catch (error, stackTrace) {
      _logFirebaseFailure('sendMessage', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyMessage(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(directMessageControllerProvider);
    final currentUserId = controller.currentUserId;

    return StreamBuilder<DirectMessageRoom?>(
      stream: controller.watchRoom(widget.roomId),
      builder: (context, roomSnapshot) {
        if (roomSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (roomSnapshot.hasError || roomSnapshot.data == null) {
          if (roomSnapshot.hasError) {
            _logFirebaseFailure(
                'watchRoom',
                roomSnapshot.error ?? StateError('Unknown room error'),
                roomSnapshot.stackTrace ?? StackTrace.current);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Direct Chat')),
            body: const Center(
              child: Text('Chat room could not be loaded.'),
            ),
          );
        }

        final room = roomSnapshot.data!;
        final peerId = room.participants.firstWhere(
          (participantId) => participantId != currentUserId,
          orElse: () => currentUserId,
        );
        final peerName = room.participantDisplayNames[peerId]?.trim();
        final peerAvatarUrl = room.participantAvatarUrls[peerId]?.trim();

        return Scaffold(
          backgroundColor: CoffeeCoreDm.canvas,
          appBar: AppBar(
            backgroundColor: CoffeeCoreDm.mocha,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            titleSpacing: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            title: Row(
              children: [
                Hero(
                  tag: 'dm_avatar_${widget.roomId}',
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    backgroundImage:
                        (peerAvatarUrl != null && peerAvatarUrl.isNotEmpty)
                            ? NetworkImage(peerAvatarUrl)
                            : null,
                    child: (peerAvatarUrl == null || peerAvatarUrl.isEmpty)
                        ? Text(
                            (peerName != null && peerName.isNotEmpty)
                                ? peerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    peerName == null || peerName.isEmpty
                        ? 'Direct Chat'
                        : peerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              if (room.contextPostId != null) _ContextBanner(room: room),
              Expanded(
                child: StreamBuilder<List<DirectMessage>>(
                  stream: controller.watchMessages(widget.roomId),
                  builder: (context, messageSnapshot) {
                    if (messageSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (messageSnapshot.hasError) {
                      _logFirebaseFailure(
                        'watchMessages',
                        messageSnapshot.error ??
                            StateError('Unknown messages error'),
                        messageSnapshot.stackTrace ?? StackTrace.current,
                      );
                      return const Center(
                        child: Text('Could not load messages.'),
                      );
                    }

                    final messages =
                        messageSnapshot.data ?? const <DirectMessage>[];
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());
                    unawaited(controller.markRoomMessagesAsRead(widget.roomId));

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text('No messages yet. Say hello!'),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUserId;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? CoffeeCoreDm.mocha : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(
                                    CoffeeCoreDm.bubbleRadius),
                                topRight: const Radius.circular(
                                    CoffeeCoreDm.bubbleRadius),
                                bottomLeft: Radius.circular(
                                    isMe ? CoffeeCoreDm.bubbleRadius : 6),
                                bottomRight: Radius.circular(
                                    isMe ? 6 : CoffeeCoreDm.bubbleRadius),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: CoffeeCoreDm.espresso
                                      .withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  message.text,
                                  style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : CoffeeCoreDm.espresso),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('h:mm a')
                                      .format(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : CoffeeCoreDm.mocha
                                            .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          decoration: BoxDecoration(
                            color: CoffeeCoreDm.canvas,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                                color:
                                    CoffeeCoreDm.latte.withValues(alpha: 0.3)),
                          ),
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            style:
                                const TextStyle(color: CoffeeCoreDm.espresso),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                  color: CoffeeCoreDm.mocha
                                      .withValues(alpha: 0.5)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _isSending
                          ? const SizedBox(
                              width: 44,
                              height: 44,
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: CoffeeCoreDm.mocha),
                              ),
                            )
                          : PressableScale(
                              onTap: _sendMessage,
                              borderRadius: BorderRadius.circular(24),
                              splashColor: Colors.white,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: CoffeeCoreDm.mocha,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.send_rounded,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _logFirebaseFailure(
      String operation, Object error, StackTrace stackTrace) {
    if (error is FirebaseException) {
      _logger.e(
        'Direct chat $operation failed with FirebaseException code=${error.code}, message=${error.message}',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _logger.e(
      'Direct chat $operation failed with ${error.runtimeType}: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _friendlyMessage(Object error) {
    if (error is FirebaseException) {
      return error.message ?? error.code;
    }
    return error.toString();
  }
}

class _ContextBanner extends StatelessWidget {
  final DirectMessageRoom room;

  const _ContextBanner({required this.room});

  @override
  Widget build(BuildContext context) {
    // Implicit fade + slide entrance when the screen opens.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * -12),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CoffeeCoreDm.cardRadius),
            border:
                Border.all(color: CoffeeCoreDm.latte.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContextThumbnail(thumbnailUrl: room.contextThumbnailUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.contextPostTitle ?? 'Community post',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: CoffeeCoreDm.espresso,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      room.contextPostSnippet ??
                          'Context from community discussion',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: CoffeeCoreDm.mocha.withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextThumbnail extends StatelessWidget {
  final String? thumbnailUrl;

  const _ContextThumbnail({required this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: CoffeeCoreDm.latte.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.article_outlined,
          color: CoffeeCoreDm.brew, size: 20),
    );

    if (thumbnailUrl == null || thumbnailUrl!.isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        thumbnailUrl!,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
