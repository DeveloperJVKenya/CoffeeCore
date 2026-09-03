import 'package:flutter/material.dart';

/// Circular tinted icon button for table row actions (view submissions,
/// edit, reprint tag, track stage, …) — used in place of a bare `IconButton`
/// across the produce/traceability tables so every action across those
/// screens reads as the same tappable "chip" rather than a loose icon
/// floating in a cell, and so a disabled action is visually greyed out
/// instead of just not responding to taps.
class TableActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  const TableActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = const Color(0xFF5D4037), // Colors.brown[700]
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null ? Colors.grey : color;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: effectiveColor),
        ),
      ),
    );
  }
}
