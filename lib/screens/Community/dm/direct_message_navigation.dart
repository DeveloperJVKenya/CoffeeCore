import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Community/post.dart';
import 'package:coffeecore/screens/Community/user_mini_profile.dart';
import 'package:coffeecore/screens/Community/dm/direct_chat_screen.dart';
import 'package:coffeecore/screens/Community/dm/direct_message_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger(printer: PrettyPrinter());

Future<void> openDirectChatFromPostContext({
  required BuildContext context,
  required WidgetRef ref,
  required UserMiniProfile recipient,
  required CommunityPost contextPost,
}) async {
  final controller = ref.read(directMessageControllerProvider);

  if (controller.currentUserId == recipient.uid) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You cannot chat with yourself.')),
    );
    return;
  }

  final String roomId;
  try {
    roomId = await controller.openOrCreateRoom(
      recipient: recipient,
      context: controller.contextFromPost(
        postId: contextPost.id,
        title: contextPost.title,
        description: contextPost.description,
        thumbnailUrl: contextPost.imageUrls.isNotEmpty
            ? contextPost.imageUrls.first
            : null,
      ),
    );
  } on FirebaseException catch (error) {
    _logger.e(
      'Unable to open direct chat for postId=${contextPost.id} with FirebaseException code=${error.code}, message=${error.message}',
      error: error,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Unable to open chat: ${error.message ?? error.code}')),
      );
    }
    return;
  } on StateError catch (error) {
    _logger.w('Unable to open direct chat: ${error.message}');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
    return;
  }

  if (!context.mounted) {
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DirectChatScreen(roomId: roomId),
    ),
  );
}
