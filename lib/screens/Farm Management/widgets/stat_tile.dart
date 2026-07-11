import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Small stat card used across dashboards: icon + value + label.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color tileColor = color ?? FarmTheme.primaryBrown;
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tileColor, size: 22),
          const SizedBox(height: FarmTheme.spaceSm),
          Text(value, style: FarmTheme.statValue.copyWith(color: tileColor)),
          const SizedBox(height: FarmTheme.spaceXs),
          Text(label, style: FarmTheme.statLabel),
        ],
      ),
    );
  }
}
