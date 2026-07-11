import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cycle_stage.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Small pill showing the current [CycleStage] with its icon.
class CycleStageBadge extends StatelessWidget {
  final CycleStage stage;
  final bool compact;

  const CycleStageBadge({super.key, required this.stage, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? FarmTheme.spaceSm : FarmTheme.spaceMd,
        vertical: FarmTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: FarmTheme.secondaryGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: FarmTheme.secondaryGreen.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stage.icon, size: 14, color: FarmTheme.secondaryGreen),
          const SizedBox(width: 4),
          Text(
            stage.label,
            style: const TextStyle(
              color: FarmTheme.secondaryGreen,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
