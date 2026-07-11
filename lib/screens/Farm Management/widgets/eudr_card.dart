import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Displays an [EudrComplianceData] verdict with explanation/recommendation.
class EudrCard extends StatelessWidget {
  final EudrComplianceData data;
  final VoidCallback? onRefresh;

  const EudrCard({super.key, required this.data, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        data.isCompliant ? FarmTheme.accentGood : FarmTheme.accentBad;
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                data.isCompliant ? Icons.verified : Icons.warning_amber_rounded,
                color: statusColor,
              ),
              const SizedBox(width: FarmTheme.spaceSm),
              Expanded(
                child: Text(
                  data.isCompliant
                      ? 'EUDR Compliant'
                      : 'EUDR Non-Compliant Risk',
                  style: FarmTheme.cardTitle.copyWith(color: statusColor),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: onRefresh),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Text(
            'Tree cover (2000 baseline): ${data.treeCoverPercent2000.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 13),
          ),
          if (data.treeCoverLossAreaHa > 0.01)
            Text(
              'Tree cover lost before 2020: ${data.treeCoverLossAreaHa.toStringAsFixed(2)} ha',
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: FarmTheme.spaceSm),
          Text(data.explanation, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: FarmTheme.spaceSm),
          Text(
            data.recommendation,
            style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black54),
          ),
          const SizedBox(height: FarmTheme.spaceXs),
          Text('Source: ${data.dataSource}',
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ],
      ),
    );
  }
}
