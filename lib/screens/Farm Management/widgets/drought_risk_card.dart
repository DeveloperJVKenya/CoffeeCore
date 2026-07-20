import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/drought_risk_model.dart';

/// Displays a [DroughtRiskResult]: overall score/band badge, a breakdown of
/// each contributing factor, and the plain-language explanation — so the
/// score is never a black box.
class DroughtRiskCard extends StatelessWidget {
  final DroughtRiskResult result;
  final VoidCallback? onRefresh;

  const DroughtRiskCard({super.key, required this.result, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final Color riskColor = FarmTheme.colorForDroughtRisk(result.score);
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: FarmTheme.primaryBrownAlt),
              const SizedBox(width: FarmTheme.spaceSm),
              const Text('Drought Risk Index', style: FarmTheme.cardTitle),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: onRefresh),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result.band,
                  style:
                      TextStyle(color: riskColor, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: FarmTheme.spaceSm),
              Text('${result.score.toStringAsFixed(0)} / 100'),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceMd),
          _factorRow(
              context, 'Vegetation (NDVI) trend', result.ndviFactor, riskColor),
          _factorRow(context, 'Moisture (NDWI)', result.ndwiFactor, riskColor),
          _factorRow(
              context, 'Rainfall outlook', result.rainfallFactor, riskColor),
          _factorRow(context, 'Heat / humidity stress',
              result.climateStressFactor, riskColor),
          const SizedBox(height: FarmTheme.spaceSm),
          Text(result.explanation,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _factorRow(
      BuildContext context, String label, double? value, Color riskColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FarmTheme.spaceXs),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: FarmTheme.statLabel),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value == null ? 0 : value / 100,
                minHeight: 6,
                backgroundColor: Colors.black12,
                valueColor: AlwaysStoppedAnimation(
                    value == null ? Colors.black26 : riskColor),
              ),
            ),
          ),
          const SizedBox(width: FarmTheme.spaceSm),
          SizedBox(
            width: 36,
            child: Text(
              value == null ? 'n/a' : value.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
