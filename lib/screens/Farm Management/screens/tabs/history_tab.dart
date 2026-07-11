import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_cycle_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_cycle_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/cycle_stage_badge.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';

/// Past-cycle browsing scoped to this farm; replaces the old
/// `history_screen.dart`. Shows completed/archived cycles with their
/// stored rollup totals.
class HistoryTab extends StatelessWidget {
  final String farmId;

  const HistoryTab({super.key, required this.farmId});

  @override
  Widget build(BuildContext context) {
    return Consumer<FarmCycleProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: FarmTheme.primaryBrown),
          );
        }
        final List<FarmCycle> pastCycles = provider.pastCycles;
        if (pastCycles.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'No Past Cycles',
            message:
                'Completed or archived cycles for this farm will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(FarmTheme.spaceMd),
          itemCount: pastCycles.length,
          itemBuilder: (context, index) {
            final cycle = pastCycles[index];
            return Container(
              margin: const EdgeInsets.only(bottom: FarmTheme.spaceMd),
              padding: const EdgeInsets.all(FarmTheme.spaceMd),
              decoration: FarmTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${cycle.name} (${cycle.year})',
                          style: FarmTheme.cardTitle,
                        ),
                      ),
                      CycleStageBadge(stage: cycle.currentStage, compact: true),
                    ],
                  ),
                  const SizedBox(height: FarmTheme.spaceXs),
                  Text(
                    cycle.status.name[0].toUpperCase() +
                        cycle.status.name.substring(1),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: FarmTheme.spaceSm),
                  Wrap(
                    spacing: FarmTheme.spaceMd,
                    runSpacing: FarmTheme.spaceXs,
                    children: [
                      Text('Cost: ${cycle.totalCost.toStringAsFixed(0)}'),
                      Text('Revenue: ${cycle.totalRevenue.toStringAsFixed(0)}'),
                      Text(
                        'P/L: ${cycle.profitLoss.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: FarmTheme.colorForProfitLoss(cycle.profitLoss),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
