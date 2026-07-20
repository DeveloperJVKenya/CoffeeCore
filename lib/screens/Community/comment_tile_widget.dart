import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Community/comment.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';
import 'package:coffeecore/screens/Community/community_more_menu.dart';
import 'package:coffeecore/screens/Community/relative_time.dart';
import 'vote_button_widget.dart';

class CommentTileWidget extends StatelessWidget {
  final Comment comment;
  final bool
      canAcceptSolutions; // true only if current user authored the post AND it's a question
  final ValueChanged<VoteDirection> onVote;
  final VoidCallback? onAccept;
  final VoidCallback onReply;
  final void Function(Comment reply, VoteDirection direction) onVoteReply;
  final ValueChanged<Comment>? onChatWithAuthor;
  final String? currentUserId;
  final ValueChanged<Comment>? onDelete;
  final ValueChanged<Comment>? onReport;

  const CommentTileWidget({
    super.key,
    required this.comment,
    required this.canAcceptSolutions,
    required this.onVote,
    this.onAccept,
    required this.onReply,
    required this.onVoteReply,
    this.onChatWithAuthor,
    this.currentUserId,
    this.onDelete,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: comment.isAcceptedSolution
            ? Colors.green.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: comment.isAcceptedSolution
            ? Border.all(color: Colors.green.shade400)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comment.isAcceptedSolution)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Accepted Solution',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundImage: comment.author.avatarUrl != null
                    ? NetworkImage(comment.author.avatarUrl!)
                    : null,
                child: comment.author.avatarUrl == null
                    ? Text(
                        comment.author.displayName.isNotEmpty
                            ? comment.author.displayName[0]
                            : '?',
                        style: const TextStyle(fontSize: 10))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(comment.author.displayName,
                    style: theme.textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(timeAgo(comment.createdAt),
                  style: theme.textTheme.labelSmall),
              if (onChatWithAuthor != null)
                IconButton(
                  onPressed: () => onChatWithAuthor!(comment),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  tooltip: 'Chat with author',
                  visualDensity: VisualDensity.compact,
                ),
              if (onDelete != null && onReport != null)
                CommunityMoreMenu(
                  isOwn: currentUserId != null &&
                      currentUserId == comment.author.uid,
                  onDelete: () => onDelete!(comment),
                  onReport: () => onReport!(comment),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(comment.body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              VoteButtonWidget(
                upvotes: comment.upvotes,
                downvotes: comment.downvotes,
                myVote: comment.myVote,
                onVote: onVote,
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: onReply,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                child: const Text('Reply', style: TextStyle(fontSize: 12)),
              ),
              if (canAcceptSolutions && !comment.isAcceptedSolution) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                  label: const Text('Accept', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    foregroundColor: Colors.green.shade700,
                  ),
                ),
              ],
            ],
          ),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Column(
                children: [
                  for (final reply in comment.replies)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _ReplyTile(
                        reply: reply,
                        onVote: (direction) => onVoteReply(reply, direction),
                        onChatWithAuthor: onChatWithAuthor == null
                            ? null
                            : () => onChatWithAuthor!(reply),
                        currentUserId: currentUserId,
                        onDelete:
                            onDelete == null ? null : () => onDelete!(reply),
                        onReport:
                            onReport == null ? null : () => onReport!(reply),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A lighter-weight tile for one-level-deep replies — no further "Reply" or
/// "Accept" affordance, keeping the nesting intentionally shallow.
class _ReplyTile extends StatelessWidget {
  final Comment reply;
  final ValueChanged<VoteDirection> onVote;
  final VoidCallback? onChatWithAuthor;
  final String? currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  const _ReplyTile({
    required this.reply,
    required this.onVote,
    this.onChatWithAuthor,
    this.currentUserId,
    this.onDelete,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundImage: reply.author.avatarUrl != null
                    ? NetworkImage(reply.author.avatarUrl!)
                    : null,
                child: reply.author.avatarUrl == null
                    ? Text(
                        reply.author.displayName.isNotEmpty
                            ? reply.author.displayName[0]
                            : '?',
                        style: const TextStyle(fontSize: 9))
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(reply.author.displayName,
                    style: theme.textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(timeAgo(reply.createdAt), style: theme.textTheme.labelSmall),
              if (onChatWithAuthor != null)
                IconButton(
                  onPressed: onChatWithAuthor,
                  icon: const Icon(Icons.mail_outline, size: 16),
                  tooltip: 'Chat with author',
                  visualDensity: VisualDensity.compact,
                ),
              if (onDelete != null && onReport != null)
                CommunityMoreMenu(
                  isOwn: currentUserId != null &&
                      currentUserId == reply.author.uid,
                  onDelete: onDelete!,
                  onReport: onReport!,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(reply.body, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          VoteButtonWidget(
            upvotes: reply.upvotes,
            downvotes: reply.downvotes,
            myVote: reply.myVote,
            onVote: onVote,
            compact: true,
          ),
        ],
      ),
    );
  }
}
