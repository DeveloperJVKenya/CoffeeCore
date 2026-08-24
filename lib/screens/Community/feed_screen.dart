import 'package:coffeecore/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Community/feed_notifier.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';
import 'package:coffeecore/screens/Community/community_notification_service.dart';
import 'package:coffeecore/screens/Community/community_strings.dart';
import 'package:coffeecore/screens/Community/notifications_screen.dart';
import 'package:coffeecore/screens/Community/post.dart';
import 'package:coffeecore/screens/Community/filter_bar_widget.dart';
import 'package:coffeecore/screens/Community/post_card_widget.dart';
import 'package:coffeecore/screens/Community/fade_slide_in_widget.dart';
import 'package:coffeecore/screens/Community/providers.dart';
import 'package:coffeecore/screens/Community/smooth_page_route.dart';
import 'package:coffeecore/screens/Community/dm/direct_inbox_screen.dart';
import 'package:coffeecore/screens/Community/dm/direct_message_navigation.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';

/// Breakpoint above which the feed switches from a single column to a
/// responsive grid — tablets and unfolded foldables land above this.
const _tabletBreakpoint = 700.0;
const _kHeaderDark = Color(0xFF4E342E);
const _kHeaderLight = Color(0xFFA1785C);

class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() =>
      _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  final _scrollController = ScrollController();
  final Logger _logger = Logger(printer: PrettyPrinter());

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(communityFeedProvider.notifier).loadMore();
    }
  }

  // Always opens regardless of connectivity — CreatePostScreen itself is
  // responsible for surfacing a "you're offline" state and disabling only
  // the actual submit action, per the product requirement that drafting a
  // post should never be blocked by a missing Firebase connection.
  //
  // CreatePostScreen returns `true` when a post was successfully created,
  // so we only refresh the feed on that signal — a cancelled/backed-out
  // create flow shouldn't trigger a pointless reload.
  Future<void> _openCreatePost(BuildContext context) async {
    final created = await Navigator.push<bool>(
      context,
      smoothRoute(const CreatePostScreen()),
    );

    if (created == true && mounted) {
      ref.read(communityFeedProvider.notifier).refresh();
    }
  }

  Future<void> _vote(CommunityPost post, VoteDirection direction) async {
    try {
      await ref.read(communityFeedProvider.notifier).vote(post, direction);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not register your vote — try again.')));
      }
    }
  }

  Future<void> _openChatForPost(CommunityPost post) async {
    await openDirectChatFromPostContext(
      context: context,
      ref: ref,
      recipient: post.author,
      contextPost: post,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(communityFeedProvider);
    final strings = CommunityStrings.of(ref);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EE),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: feedAsync.when(
          loading: () => const Center(
              key: ValueKey('loading'), child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            _logFeedError(error, stackTrace);
            return _ErrorState(
              key: const ValueKey('error'),
              error: error,
              strings: strings,
              onRetry: () => ref.read(communityFeedProvider.notifier).refresh(),
            );
          },
          data: (state) => RefreshIndicator(
            key: const ValueKey('data'),
            onRefresh: () => ref.read(communityFeedProvider.notifier).refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: 130,
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: _kHeaderDark,
                  automaticallyImplyLeading: false,
                  iconTheme: const IconThemeData(color: Colors.white),
                  leading: InkResponse(
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomePage()),
                      (route) => false,
                    ),
                    radius: 20,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child:
                          Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding:
                        const EdgeInsets.only(left: 45, right: 20, bottom: 16),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.forum_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          strings.communityTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_kHeaderLight, _kHeaderDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -30,
                            top: -20,
                            child: Icon(Icons.local_cafe,
                                size: 180,
                                color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          Positioned(
                            left: 45,
                            bottom: 56,
                            child: Text(
                              'Grow together, ask, share, thrive',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    _LocaleToggleAction(),
                    _NotificationBellAction(),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DirectInboxScreen()),
                        );
                      },
                      icon: const Icon(Icons.mail_outline),
                      tooltip: strings.directMessages,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: FilterBarWidget(
                        sort: state.sort,
                        categoryFilter: state.categoryFilter,
                        cropFilter: state.cropFilter,
                        onSortChanged: (SortOption sort) => ref
                            .read(communityFeedProvider.notifier)
                            .updateSort(sort),
                        onCategoryChanged: (category) => ref
                            .read(communityFeedProvider.notifier)
                            .updateCategoryFilter(category),
                        onCropChanged: (crop) => ref
                            .read(communityFeedProvider.notifier)
                            .updateCropFilter(crop),
                      ),
                    ),
                  ),
                ),
                if (state.posts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _kHeaderLight.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.forum_outlined,
                                  size: 40, color: Colors.brown[400]),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              strings.noPostsYet,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.brown[700]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Be the first to share something with the community.',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  _ResponsivePostList(
                    posts: state.posts,
                    onVote: (post, direction) => _vote(post, direction),
                    onChat: _openChatForPost,
                  ),
                if (state.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreatePost(context),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          strings.newPost,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _LocaleToggleAction extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(communityLocaleProvider);
    return TextButton(
      onPressed: () => ref.read(communityLocaleProvider.notifier).toggle(),
      child: Text(
        locale == CommunityLocale.en ? 'SW' : 'EN',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _NotificationBellAction extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return IconButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
        icon: const Icon(Icons.notifications_outlined),
        tooltip: 'Notifications',
      );
    }

    return StreamBuilder<int>(
      stream: ref
          .read(communityNotificationServiceProvider)
          .watchUnreadCount(userId),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          icon: Badge(
            label: Text('$unread'),
            isLabelVisible: unread > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
          tooltip: 'Notifications',
        );
      },
    );
  }
}

class _ResponsivePostList extends ConsumerWidget {
  final List<CommunityPost> posts;
  final void Function(CommunityPost post, VoteDirection direction) onVote;
  final ValueChanged<CommunityPost> onChat;

  const _ResponsivePostList({
    required this.posts,
    required this.onVote,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final isTablet = width >= _tabletBreakpoint;
        final crossAxisCount = width >= 1100 ? 3 : (isTablet ? 2 : 1);

        if (crossAxisCount == 1) {
          return SliverList.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return FadeSlideIn(
                index: index,
                child: PostCardWidget(
                  post: post,
                  onVote: (VoteDirection direction) => onVote(post, direction),
                  onTap: () => _openDetail(context, ref, post.id),
                  onChatWithAuthor: () => onChat(post),
                ),
              );
            },
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: 230,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = posts[index];
                return FadeSlideIn(
                  index: index,
                  child: PostCardWidget(
                    post: post,
                    onVote: (VoteDirection direction) =>
                        onVote(post, direction),
                    onTap: () => _openDetail(context, ref, post.id),
                    onChatWithAuthor: () => onChat(post),
                  ),
                );
              },
              childCount: posts.length,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDetail(
      BuildContext context, WidgetRef ref, String postId) async {
    final deleted = await Navigator.push<bool>(
      context,
      smoothRoute(PostDetailScreen(postId: postId)),
    );
    if (deleted == true) {
      ref.read(communityFeedProvider.notifier).refresh();
    }
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final CommunityStrings strings;

  const _ErrorState({
    super.key,
    required this.error,
    required this.onRetry,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 32),
            const SizedBox(height: 12),
            Text(strings.couldNotLoadFeed, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              _friendlyErrorMessage(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: Text(strings.retry)),
          ],
        ),
      ),
    );
  }

  static String _friendlyErrorMessage(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Firebase security rules blocked this feed request. Check read access for community_posts and related queries.';
      }
      if (error.code == 'unavailable') {
        return 'Firebase is unavailable right now. Check connectivity and Firebase status.';
      }
      return 'Firebase error: ${error.code}${error.message == null ? '' : ' - ${error.message}'}';
    }

    return error.toString();
  }
}

extension on _CommunityFeedScreenState {
  void _logFeedError(Object error, StackTrace stackTrace) {
    if (error is FirebaseException) {
      _logger.e(
        'Community feed failed with FirebaseException code=${error.code}, message=${error.message}',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _logger.e(
      'Community feed failed with ${error.runtimeType}: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
