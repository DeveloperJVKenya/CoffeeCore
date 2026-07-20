import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';

/// Compact horizontal vote control: up-arrow + count, down-arrow + count.
/// Used on PostCardWidget and CommentTileWidget.
class VoteButtonWidget extends StatelessWidget {
  final int upvotes;
  final int downvotes;
  final VoteDirection? myVote;
  final ValueChanged<VoteDirection> onVote;
  final bool compact;

  const VoteButtonWidget({
    super.key,
    required this.upvotes,
    required this.downvotes,
    required this.myVote,
    required this.onVote,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 18.0 : 22.0;
    final fontSize = compact ? 12.0 : 14.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VoteChip(
          icon: Icons.arrow_upward_rounded,
          count: upvotes,
          isActive: myVote == VoteDirection.up,
          activeColor: Colors.green.shade700,
          iconSize: iconSize,
          fontSize: fontSize,
          onTap: () => onVote(VoteDirection.up),
        ),
        SizedBox(width: compact ? 6 : 10),
        _VoteChip(
          icon: Icons.arrow_downward_rounded,
          count: downvotes,
          isActive: myVote == VoteDirection.down,
          activeColor: Colors.red.shade700,
          iconSize: iconSize,
          fontSize: fontSize,
          onTap: () => onVote(VoteDirection.down),
        ),
      ],
    );
  }
}

class _VoteChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final double iconSize;
  final double fontSize;
  final VoidCallback onTap;

  const _VoteChip({
    required this.icon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    required this.iconSize,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? activeColor : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 3),
            Text('$count',
                style: TextStyle(
                    fontSize: fontSize,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
