import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/activity_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cycle_stage.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Single row for a [FarmActivity] inside the cycles/activities tab.
class ActivityListItem extends StatelessWidget {
  final FarmActivity activity;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ActivityListItem(
      {super.key, required this.activity, this.onTap, this.onDelete});

  IconData get _icon {
    switch (activity.type) {
      case ActivityType.labour:
        return Icons.people;
      case ActivityType.mechanical:
        return Icons.build;
      case ActivityType.input:
        return Icons.science;
      case ActivityType.miscellaneous:
        return Icons.receipt_long;
      case ActivityType.observation:
        return Icons.visibility;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: FarmTheme.spaceMd, vertical: FarmTheme.spaceXs),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: FarmTheme.primaryBrown.withValues(alpha: 0.1),
          child: Icon(_icon, color: FarmTheme.primaryBrown, size: 20),
        ),
        title: Text(activity.description),
        subtitle: Text(
          '${activity.type.label} · ${activity.stage.label} · '
          '${activity.date.toIso8601String().substring(0, 10)}'
          '${activity.cost > 0 ? ' · ${activity.cost.toStringAsFixed(2)}' : ''}',
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: FarmTheme.accentBad),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
