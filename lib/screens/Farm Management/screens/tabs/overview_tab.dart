import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_cycle_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_finance_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/cycle_stage_badge.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/farm_map_thumbnail.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/stat_tile.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/inventory_screen.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/yield_entry_screen.dart';

/// Overview tab: map thumbnail, active-cycle banner, quick stats and
/// quick-action shortcuts (Inventory / Log Yield). Reads the farm-scoped
/// providers supplied by `FarmDetailShellScreen`'s `MultiProvider`.
class OverviewTab extends StatelessWidget {
  final FarmPolygon farm;
  final String farmId;
  final void Function(int index)? onNavigateToTab;

  const OverviewTab({
    super.key,
    required this.farm,
    required this.farmId,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      children: [
        FarmMapThumbnail(farm: farm, height: 160),
        const SizedBox(height: FarmTheme.spaceMd),
        _buildCycleBanner(context),
        const SizedBox(height: FarmTheme.spaceMd),
        _buildStatsRow(context),
        const SizedBox(height: FarmTheme.spaceMd),
        _buildQuickActions(context),
      ],
    );
  }

  Widget _buildCycleBanner(BuildContext context) {
    return Consumer<FarmCycleProvider>(
      builder: (context, provider, _) {
        final activeCycle = provider.activeCycle;
        if (activeCycle == null) {
          return Container(
            decoration: FarmTheme.cardDecoration(),
            child: EmptyState(
              icon: Icons.eco_outlined,
              title: 'No Active Cycle',
              message: 'Start a growth cycle to begin tracking activities, '
                  'costs and yield for this farm.',
              actionLabel: 'Start a Cycle',
              onAction: () => onNavigateToTab?.call(1),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(FarmTheme.spaceMd),
          decoration: FarmTheme.cardDecoration(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activeCycle.name, style: FarmTheme.cardTitle),
                    const SizedBox(height: FarmTheme.spaceXs),
                    CycleStageBadge(stage: activeCycle.currentStage),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Consumer<FarmFinanceProvider>(
      builder: (context, provider, _) {
        final summary = provider.profitLoss;
        return Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.trending_down,
                value: summary.totalCost.toStringAsFixed(0),
                label: 'Total Cost',
                color: FarmTheme.primaryBrown,
              ),
            ),
            const SizedBox(width: FarmTheme.spaceSm),
            Expanded(
              child: StatTile(
                icon: Icons.trending_up,
                value: summary.totalRevenue.toStringAsFixed(0),
                label: 'Total Revenue',
                color: FarmTheme.secondaryGreen,
              ),
            ),
            const SizedBox(width: FarmTheme.spaceSm),
            Expanded(
              child: StatTile(
                icon: Icons.account_balance_wallet,
                value: summary.profitLoss.toStringAsFixed(0),
                label: 'Profit/Loss',
                color: FarmTheme.colorForProfitLoss(summary.profitLoss),
              ),
            ),
            const SizedBox(width: FarmTheme.spaceSm),
            Expanded(
              child: StatTile(
                icon: Icons.landscape,
                value: farm.areaLabel,
                label: 'Area',
                color: FarmTheme.primaryBrownAlt,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Consumer<FarmCycleProvider>(
      builder: (context, cycleProvider, _) {
        final activeCycle = cycleProvider.activeCycle;
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => InventoryScreen(farmId: farmId),
                  ),
                ),
                icon: const Icon(Icons.inventory_2),
                label: const Text('Inventory'),
              ),
            ),
            const SizedBox(width: FarmTheme.spaceSm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: activeCycle == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => YieldEntryScreen(
                              farmId: farmId,
                              cycleId: activeCycle.id!,
                            ),
                          ),
                        ),
                icon: const Icon(Icons.agriculture),
                label: const Text('Log Yield'),
              ),
            ),
          ],
        );
      },
    );
  }
}
