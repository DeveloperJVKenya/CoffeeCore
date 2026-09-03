import 'package:coffeecore/models/produce_confirmation_status.dart';
import 'package:flutter/material.dart';

/// Compact read-only indicator of a submission's farmer-confirmation
/// state, for the Market Manager/CoopAdmin/MainAdmin-facing tables — never
/// interactive here, since accepting/declining is the farmer's action
/// alone (see ProduceScreen). Renders nothing for a legacy submission with
/// no [ProduceConfirmationStatus] at all, so pre-feature history doesn't
/// pick up a stray "pending" badge it never actually went through.
class ProduceConfirmationChip extends StatelessWidget {
  final ProduceConfirmationStatus? status;

  const ProduceConfirmationChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) return const SizedBox.shrink();

    final (Color color, IconData icon) = switch (s) {
      ProduceConfirmationStatus.pending => (
          Colors.orange[800]!,
          Icons.schedule
        ),
      ProduceConfirmationStatus.accepted => (
          Colors.green[700]!,
          Icons.check_circle
        ),
      ProduceConfirmationStatus.declined => (Colors.red[700]!, Icons.cancel),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(s.label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
