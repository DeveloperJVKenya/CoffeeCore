import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/climate_satellite_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_cycle_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_finance_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/services/report_export_service.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';

/// Reports tab: Excel + PDF export of the active cycle's cost/revenue/P&L
/// data, via `ReportExportService`.
class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final activeCycle = context.watch<FarmCycleProvider>().activeCycle;
    final String farmName =
        context.watch<ClimateSatelliteProvider>().farm.farmName;

    if (activeCycle == null) {
      return const EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: 'No Active Cycle',
        message:
            'Start a cycle and record costs/revenue before exporting a report.',
      );
    }

    return Consumer<FarmFinanceProvider>(
      builder: (context, financeProvider, _) {
        final bool hasData = financeProvider.costs.isNotEmpty ||
            financeProvider.revenues.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.all(FarmTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export "${activeCycle.name}" Report',
                  style: FarmTheme.cardTitle),
              const SizedBox(height: FarmTheme.spaceSm),
              const Text(
                'Generate a cost/revenue/profit-loss report for the active cycle.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: FarmTheme.spaceLg),
              ElevatedButton.icon(
                onPressed: !hasData
                    ? null
                    : () => ReportExportService().exportCostsRevenueExcel(
                          context: context,
                          farmName: farmName,
                          cycleName: activeCycle.name,
                          costs: financeProvider.costs,
                          revenues: financeProvider.revenues,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmTheme.secondaryGreen,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.table_chart, color: Colors.white),
                label: const Text('Export Excel',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: FarmTheme.spaceMd),
              ElevatedButton.icon(
                onPressed: !hasData
                    ? null
                    : () => ReportExportService().exportProfitLossPdf(
                          context: context,
                          farmName: farmName,
                          cycleName: activeCycle.name,
                          costs: financeProvider.costs,
                          revenues: financeProvider.revenues,
                          summary: financeProvider.profitLoss,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmTheme.primaryBrown,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text('Export PDF',
                    style: TextStyle(color: Colors.white)),
              ),
              if (!hasData) ...[
                const SizedBox(height: FarmTheme.spaceMd),
                const Text(
                  'Add at least one cost or revenue entry before exporting.',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
