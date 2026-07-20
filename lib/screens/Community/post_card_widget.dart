import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';
import 'package:coffeecore/screens/Community/post.dart';
import 'package:coffeecore/screens/Community/relative_time.dart';
import 'vote_button_widget.dart';

class PostCardWidget extends StatelessWidget {
  final CommunityPost post;
  final ValueChanged<VoteDirection> onVote;
  final VoidCallback onTap;
  final VoidCallback? onChatWithAuthor;

  const PostCardWidget({
    super.key,
    required this.post,
    required this.onVote,
    required this.onTap,
    this.onChatWithAuthor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: post.author.avatarUrl != null
                        ? NetworkImage(post.author.avatarUrl!)
                        : null,
                    child: post.author.avatarUrl == null
                        ? Text(
                            post.author.displayName.isNotEmpty
                                ? post.author.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.author.displayName,
                      style: theme.textTheme.labelMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(timeAgo(post.createdAt),
                      style: theme.textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Pill(label: post.category.label, color: post.category.color),
                  if (post.cropCategory != null)
                    _Pill(
                        label: post.cropCategory!.label,
                        color: theme.colorScheme.secondary),
                  if (post.isQuestion)
                    _Pill(
                      label: post.isAnswered ? 'Solved' : 'Question',
                      color: post.isAnswered
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                      icon: post.isAnswered
                          ? Icons.check_circle
                          : Icons.help_outline,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                post.description,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (post.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    post.imageUrls.first,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    loadingBuilder: (context, child, progress) => progress ==
                            null
                        ? child
                        : Container(
                            height: 140,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                  ),
                ),
                if (post.imageUrls.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${post.imageUrls.length - 1} more photo${post.imageUrls.length > 2 ? 's' : ''}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  VoteButtonWidget(
                    upvotes: post.upvotes,
                    downvotes: post.downvotes,
                    myVote: post.myVote,
                    onVote: onVote,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.mode_comment_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}',
                      style: theme.textTheme.labelMedium),
                  const Spacer(),
                  if (onChatWithAuthor != null)
                    TextButton.icon(
                      onPressed: onChatWithAuthor,
                      icon: const Icon(Icons.mail_outline, size: 16),
                      label: const Text(
                        'Chat with Author',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
