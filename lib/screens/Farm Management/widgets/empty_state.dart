import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Generic empty-state placeholder (no data yet) with an optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FarmTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.black26),
            const SizedBox(height: FarmTheme.spaceMd),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: FarmTheme.spaceSm),
              Text(
                message!,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: FarmTheme.spaceMd),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                    backgroundColor: FarmTheme.primaryBrown),
                child: Text(actionLabel!,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
