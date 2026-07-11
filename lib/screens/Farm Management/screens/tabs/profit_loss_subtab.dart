import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_finance_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/pie_chart_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/stat_tile.dart';

/// Profit & Loss sub-tab: cost-breakdown pie chart plus a stat row for
/// total cost / total revenue / profit-loss.
class ProfitLossSubtab extends StatelessWidget {
  const ProfitLossSubtab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FarmFinanceProvider>(
      builder: (context, financeProvider, _) {
        final summary = financeProvider.profitLoss;
        return ListView(
          padding: const EdgeInsets.all(FarmTheme.spaceMd),
          children: [
            Row(
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
              ],
            ),
            const SizedBox(height: FarmTheme.spaceMd),
            PieChartCard(costByCategory: summary.costByCategory),
          ],
        );
      },
    );
  }
}
