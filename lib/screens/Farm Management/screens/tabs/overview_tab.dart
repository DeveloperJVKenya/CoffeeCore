import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/climate_satellite_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_cycle_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_finance_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/yield_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/cycle_stage_badge.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/farm_map_thumbnail.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/stat_tile.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/farm_map_view_screen.dart';
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
        _buildMapCard(context),
        const SizedBox(height: FarmTheme.spaceMd),
        _buildCycleBanner(context),
        const SizedBox(height: FarmTheme.spaceMd),
        _buildStatsRow(context),
        _buildHarvestReconciliationNotice(context),
        const SizedBox(height: FarmTheme.spaceMd),
        _buildQuickActions(context),
      ],
    );
  }

  Widget _buildMapCard(BuildContext context) {
    // Reads the live satellite/NDVI/NDWI snapshot from ClimateSatelliteProvider
    // instead of the plain `farm` prop, which is fetched once in
    // FarmDetailShellScreen's initState and never refreshed — without this,
    // fetching new NDVI/NDWI data in the Climate & Satellite tab would never
    // be reflected on the map until the farm detail screen was reopened.
    return Consumer<ClimateSatelliteProvider>(
      builder: (context, climateProvider, _) {
        final liveFarm =
            farm.copyWith(satelliteData: climateProvider.satellite);
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FarmMapViewScreen(farm: liveFarm),
            ),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(FarmTheme.radiusCard),
                child: FarmMapThumbnail(farm: liveFarm, height: 160),
              ),
              Positioned(
                right: FarmTheme.spaceSm,
                bottom: FarmTheme.spaceSm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FarmTheme.spaceSm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(FarmTheme.spaceSm),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'View full map',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  // Harvested kg (Yield tab) and sold kg (Revenue entries feeding this
  // Overview's P&L) are logged independently with no cross-check, so they
  // can silently diverge — e.g. 500 kg harvested but only 200 kg logged as
  // sold, with the missing 300 kg going unnoticed. This surfaces that gap
  // rather than fixing it automatically, since a gap can be legitimate
  // (unsold stock still in storage) — it's a prompt to check, not an error.
  Widget _buildHarvestReconciliationNotice(BuildContext context) {
    return Consumer2<YieldProvider, FarmFinanceProvider>(
      builder: (context, yieldProvider, financeProvider, _) {
        final double harvestedKg = yieldProvider.stats.totalKg;
        final double soldKg = financeProvider.revenues
            .fold<double>(0.0, (total, r) => total + r.kg);
        final double unaccountedKg = harvestedKg - soldKg;

        // Only worth flagging once there's a meaningful harvest on record —
        // avoids noise while a cycle is brand new and both are near zero.
        if (harvestedKg <= 0 || unaccountedKg <= 0.5) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: FarmTheme.spaceMd),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: FarmTheme.spaceMd,
              vertical: FarmTheme.spaceSm,
            ),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(FarmTheme.radiusCard),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: Colors.amber.shade800),
                const SizedBox(width: FarmTheme.spaceSm),
                Expanded(
                  child: Text(
                    '${unaccountedKg.toStringAsFixed(1)} kg harvested has '
                    'not been logged as sold yet — check the Revenue tab if '
                    "that's unexpected.",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.amber.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                              cycleStartDate: activeCycle.startDate,
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
