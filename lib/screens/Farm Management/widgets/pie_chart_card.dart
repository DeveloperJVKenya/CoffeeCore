import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cost_model.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Pie chart of cost-by-category, driven by
/// `FinanceService.computeProfitLoss(...).costByCategory`.
class PieChartCard extends StatelessWidget {
  final Map<CostCategory, double> costByCategory;

  const PieChartCard({super.key, required this.costByCategory});

  static const List<Color> _palette = [
    FarmTheme.primaryBrown,
    FarmTheme.secondaryGreen,
    FarmTheme.healthFair,
    FarmTheme.accentBad,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = costByCategory.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(FarmTheme.spaceMd),
        decoration: FarmTheme.cardDecoration(),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(FarmTheme.spaceLg),
            child: Text('No cost data yet for this cycle.'),
          ),
        ),
      );
    }
    final total = entries.fold<double>(0.0, (t, e) => t + e.value);
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cost Breakdown', style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceMd),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 32,
                sections: [
                  for (int i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value,
                      color: _palette[i % _palette.length],
                      title: total == 0
                          ? ''
                          : '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                      radius: 56,
                      titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FarmTheme.spaceMd),
          Wrap(
            spacing: FarmTheme.spaceMd,
            runSpacing: FarmTheme.spaceXs,
            children: [
              for (int i = 0; i < entries.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        color: _palette[i % _palette.length]),
                    const SizedBox(width: 4),
                    Text(
                        '${entries[i].key.label}: ${entries[i].value.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
