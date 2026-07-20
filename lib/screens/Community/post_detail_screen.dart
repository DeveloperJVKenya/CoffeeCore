import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coffeecore/screens/Community/post_detail_notifier.dart';
import 'package:coffeecore/screens/Community/providers.dart';
import 'package:coffeecore/screens/Community/comment.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';
import 'package:coffeecore/screens/Community/post.dart';
import 'package:coffeecore/screens/Community/relative_time.dart';
import 'package:coffeecore/screens/Community/comment_tile_widget.dart';
import 'package:coffeecore/screens/Community/community_more_menu.dart';
import 'package:coffeecore/screens/Community/community_strings.dart';
import 'package:coffeecore/screens/Community/report_dialog.dart';
import 'package:coffeecore/screens/Community/vote_button_widget.dart';
import 'package:coffeecore/screens/Community/dm/direct_inbox_screen.dart';
import 'package:coffeecore/screens/Community/dm/direct_message_navigation.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  String? _replyingToCommentId;
  String? _replyingToAuthorName;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _startReply(Comment comment) {
    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToAuthorName = comment.author.displayName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToAuthorName = null;
    });
  }

  Future<void> _votePost(VoteDirection direction) async {
    try {
      await ref
          .read(postDetailProvider(widget.postId).notifier)
          .votePost(direction);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(CommunityStrings.of(ref).couldNotVote)));
      }
    }
  }

  Future<void> _voteComment(Comment comment, VoteDirection direction) async {
    try {
      await ref
          .read(postDetailProvider(widget.postId).notifier)
          .voteComment(comment, direction);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(CommunityStrings.of(ref).couldNotVote)));
      }
    }
  }

  Future<void> _acceptSolution(Comment comment) async {
    try {
      await ref
          .read(postDetailProvider(widget.postId).notifier)
          .acceptSolution(comment);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(CommunityStrings.of(ref).couldNotAccept)));
      }
    }
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;

    final notifier = ref.read(postDetailProvider(widget.postId).notifier);
    _commentController.clear();
    final parentId = _replyingToCommentId;
    _cancelReply();

    try {
      await notifier.addComment(body: body, parentCommentId: parentId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(CommunityStrings.of(ref).couldNotPostComment)));
      }
    }
  }

  Future<void> _confirmDeletePost() async {
    final strings = CommunityStrings.of(ref);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deletePostTitle),
        content: Text(strings.deleteConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(postDetailProvider(widget.postId).notifier).deletePost();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.couldNotDeletePost)));
      }
    }
  }

  Future<void> _reportPost() async {
    final strings = CommunityStrings.of(ref);
    final reason = await showReportDialog(context);
    if (reason == null || !mounted) return;

    try {
      await ref
          .read(postDetailProvider(widget.postId).notifier)
          .reportPost(reason);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.reportSubmittedPost)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.couldNotSubmitReport)));
      }
    }
  }

  Future<void> _confirmDeleteComment(Comment comment) async {
    final strings = CommunityStrings.of(ref);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteCommentTitle),
        content: Text(strings.deleteConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(postDetailProvider(widget.postId).notifier)
          .deleteComment(comment.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.couldNotDeleteComment)));
      }
    }
  }

  Future<void> _reportComment(Comment comment) async {
    final strings = CommunityStrings.of(ref);
    final reason = await showReportDialog(context);
    if (reason == null || !mounted) return;

    try {
      await ref
          .read(postDetailProvider(widget.postId).notifier)
          .reportComment(commentId: comment.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.reportSubmittedComment)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.couldNotSubmitReport)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(postDetailProvider(widget.postId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final strings = CommunityStrings.of(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.discussionAppBarTitle),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DirectInboxScreen()),
              );
            },
            icon: const Icon(Icons.mail_outline),
            tooltip: strings.directMessages,
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.couldNotLoadPost),
              TextButton(
                onPressed: () => ref
                    .read(postDetailProvider(widget.postId).notifier)
                    .refresh(),
                child: Text(strings.retry),
              ),
            ],
          ),
        ),
        data: (state) {
          final isAuthor =
              currentUserId != null && currentUserId == state.post.author.uid;
          final canAccept = isAuthor && state.post.isQuestion;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Center a max-width column on wide screens so the
                    // detail view doesn't stretch uncomfortably on tablets.
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PostHeader(
                              post: state.post,
                              onChatWithAuthor: () =>
                                  openDirectChatFromPostContext(
                                context: context,
                                ref: ref,
                                recipient: state.post.author,
                                contextPost: state.post,
                              ),
                              isAuthor: isAuthor,
                              onDelete: _confirmDeletePost,
                              onReport: _reportPost,
                            ),
                            const SizedBox(height: 16),
                            VoteButtonWidget(
                              upvotes: state.post.upvotes,
                              downvotes: state.post.downvotes,
                              myVote: state.post.myVote,
                              compact: false,
                              onVote: _votePost,
                            ),
                            const SizedBox(height: 24),
                            if (state.acceptedComment != null) ...[
                              Text(strings.acceptedSolution,
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              CommentTileWidget(
                                comment: state.acceptedComment!,
                                canAcceptSolutions: false,
                                onVote: (VoteDirection d) =>
                                    _voteComment(state.acceptedComment!, d),
                                onReply: () =>
                                    _startReply(state.acceptedComment!),
                                onVoteReply: (reply, VoteDirection d) =>
                                    _voteComment(reply, d),
                                onChatWithAuthor: (targetComment) =>
                                    openDirectChatFromPostContext(
                                  context: context,
                                  ref: ref,
                                  recipient: targetComment.author,
                                  contextPost: state.post,
                                ),
                                currentUserId: currentUserId,
                                onDelete: _confirmDeleteComment,
                                onReport: _reportComment,
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              '${state.otherComments.length} ${state.post.isQuestion ? strings.answers : strings.comments}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            for (final comment in state.otherComments)
                              CommentTileWidget(
                                comment: comment,
                                canAcceptSolutions: canAccept,
                                onVote: (VoteDirection d) =>
                                    _voteComment(comment, d),
                                onAccept: () => _acceptSolution(comment),
                                onReply: () => _startReply(comment),
                                onVoteReply: (reply, VoteDirection d) =>
                                    _voteComment(reply, d),
                                onChatWithAuthor: (targetComment) =>
                                    openDirectChatFromPostContext(
                                  context: context,
                                  ref: ref,
                                  recipient: targetComment.author,
                                  contextPost: state.post,
                                ),
                                currentUserId: currentUserId,
                                onDelete: _confirmDeleteComment,
                                onReport: _reportComment,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _CommentComposer(
                controller: _commentController,
                replyingToAuthorName: _replyingToAuthorName,
                onCancelReply: _cancelReply,
                onSubmit: _submitComment,
                isSubmitting: state.isSubmittingComment,
                strings: strings,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onChatWithAuthor;
  final bool isAuthor;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const _PostHeader({
    required this.post,
    this.onChatWithAuthor,
    required this.isAuthor,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: post.author.avatarUrl != null
                  ? NetworkImage(post.author.avatarUrl!)
                  : null,
              child: post.author.avatarUrl == null
                  ? Text(post.author.displayName.isNotEmpty
                      ? post.author.displayName[0]
                      : '?')
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(post.author.displayName,
                  style: theme.textTheme.labelLarge),
            ),
            Text(timeAgo(post.createdAt), style: theme.textTheme.labelSmall),
            CommunityMoreMenu(
                isOwn: isAuthor, onDelete: onDelete, onReport: onReport),
          ],
        ),
        const SizedBox(height: 12),
        Text(post.title, style: theme.textTheme.headlineSmall),
        if (post.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: post.imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrls[index],
                  height: 200,
                  width: 260,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    width: 260,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (onChatWithAuthor != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: onChatWithAuthor,
              icon: const Icon(Icons.mail_outline, size: 16),
              label: const Text('Chat with Author'),
            ),
          ),
        const SizedBox(height: 8),
        Text(post.description, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final String? replyingToAuthorName;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;
  final bool isSubmitting;
  final CommunityStrings strings;

  const _CommentComposer({
    required this.controller,
    required this.replyingToAuthorName,
    required this.onCancelReply,
    required this.onSubmit,
    required this.isSubmitting,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyingToAuthorName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text('${strings.replyingTo} $replyingToAuthorName',
                        style: Theme.of(context).textTheme.labelSmall),
                    const Spacer(),
                    GestureDetector(
                      onTap: onCancelReply,
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: strings.shareYourInput,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.send), onPressed: onSubmit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
