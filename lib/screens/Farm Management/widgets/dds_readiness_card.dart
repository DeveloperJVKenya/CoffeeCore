import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/dds_readiness_model.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Synthesizes the GFW screening, Planetek certified analysis, and
/// boundary-overlap check above into one suggested next action for this
/// plot's EUDR Due Diligence Statement — see dds_readiness_model.dart.
class DdsReadinessCard extends StatelessWidget {
  final DdsReadiness readiness;

  const DdsReadinessCard({super.key, required this.readiness});

  Color _statusColor() {
    switch (readiness.status) {
      case DdsReadinessStatus.readyNegligibleRisk:
        return FarmTheme.accentGood;
      case DdsReadinessStatus.notYetChecked:
        return Colors.black45;
      case DdsReadinessStatus.boundaryOverlap:
      case DdsReadinessStatus.signatureNotVerified:
        return Colors.orange;
      case DdsReadinessStatus.nonNegligibleRisk:
        return FarmTheme.accentBad;
    }
  }

  IconData _statusIcon() {
    switch (readiness.status) {
      case DdsReadinessStatus.readyNegligibleRisk:
        return Icons.task_alt;
      case DdsReadinessStatus.notYetChecked:
        return Icons.help_outline;
      case DdsReadinessStatus.boundaryOverlap:
        return Icons.report_gmailerrorred;
      case DdsReadinessStatus.signatureNotVerified:
        return Icons.gpp_maybe_outlined;
      case DdsReadinessStatus.nonNegligibleRisk:
        return Icons.block;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon(), color: color),
              const SizedBox(width: FarmTheme.spaceSm),
              Expanded(
                child: Text(
                  readiness.headline,
                  style: FarmTheme.cardTitle.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Text(readiness.explanation, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: FarmTheme.spaceXs),
          const Text(
            'Suggestion only — not a legal determination. Confirm land-use '
            'legality documentation separately before filing a DDS.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
