import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coffeecore/screens/Community/community_notification.dart';
import 'package:coffeecore/screens/Community/community_notification_service.dart';
import 'package:coffeecore/screens/Community/community_strings.dart';
import 'package:coffeecore/screens/Community/dm/direct_chat_screen.dart';
import 'package:coffeecore/screens/Community/providers.dart';
import 'package:coffeecore/screens/Community/post_detail_screen.dart';
import 'package:coffeecore/screens/Community/relative_time.dart';

/// In-app notification center — a Firestore-backed feed of replies,
/// accepted-solution alerts, and DM pings that updates live while the app is
/// open. This is not push: it won't wake the app when closed, same
/// trade-off as the existing DM unread badge (see [DirectInboxScreen]).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  Future<void> _markAllRead() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(communityNotificationServiceProvider).markAllRead(userId);
  }

  void _openNotification(CommunityNotification notification) {
    if (notification.roomId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DirectChatScreen(roomId: notification.roomId!)),
      );
      return;
    }
    if (notification.postId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: notification.postId!)),
      );
    }
  }

  IconData _iconFor(CommunityNotificationType type) {
    switch (type) {
      case CommunityNotificationType.replyToPost:
      case CommunityNotificationType.replyToComment:
        return Icons.mode_comment_outlined;
      case CommunityNotificationType.acceptedSolution:
        return Icons.check_circle_outline;
      case CommunityNotificationType.directMessage:
        return Icons.mail_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final strings = CommunityStrings.of(ref);

    return Scaffold(
      appBar: AppBar(title: Text(strings.notificationsTitle)),
      body: userId == null
          ? const Center(child: Text('Sign in to see your notifications.'))
          : StreamBuilder<List<CommunityNotification>>(
              stream: ref
                  .read(communityNotificationServiceProvider)
                  .watchNotifications(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(strings.couldNotLoadNotifications));
                }

                final notifications =
                    snapshot.data ?? const <CommunityNotification>[];
                if (notifications.isEmpty) {
                  return Center(child: Text(strings.noNotificationsYet));
                }

                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return ListTile(
                      leading: Icon(_iconFor(notification.type),
                          color: Colors.brown[700]),
                      title: Text(notification.actorName,
                          style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold)),
                      subtitle: Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(timeAgo(notification.createdAt),
                          style: Theme.of(context).textTheme.labelSmall),
                      onTap: () => _openNotification(notification),
                    );
                  },
                );
              },
            ),
    );
  }
}
