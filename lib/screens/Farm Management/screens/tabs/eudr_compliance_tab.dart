import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/eudr_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/planetek_eudr_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/eudr_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/planetek_analysis_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/loading_error_view.dart';

/// EUDR Compliance tab: two independent deforestation-risk sources shown
/// side by side —
///   1. GFW tree-cover screening, sourced live via `EudrProvider`.
///   2. Planetek's signed, certified deforestation analysis, sourced live
///      via `PlanetekEudrProvider`.
/// Neither ever fabricates a result — each shows its own explanatory empty
/// state with a manual "Run" action until real data exists, and each fails
/// independently without hiding the other's result.
class EudrComplianceTab extends StatelessWidget {
  const EudrComplianceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GFW Screening', style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceSm),
          Consumer<EudrProvider>(
            builder: (context, provider, _) {
              return LoadingErrorView(
                isLoading: provider.isLoading,
                errorMessage: provider.error,
                onRetry: provider.refreshCompliance,
                builder: (context) {
                  if (provider.compliance == null) {
                    return EmptyState(
                      icon: Icons.forest_outlined,
                      title: 'No EUDR Check Yet',
                      message: 'Run an EU Deforestation Regulation compliance '
                          'check against this farm\'s boundary using satellite '
                          'tree-cover data.',
                      actionLabel: 'Run EUDR Check',
                      onAction: provider.refreshCompliance,
                    );
                  }
                  return EudrCard(
                    data: provider.compliance!,
                    onRefresh: provider.refreshCompliance,
                  );
                },
              );
            },
          ),
          const SizedBox(height: FarmTheme.spaceLg),
          const Divider(),
          const SizedBox(height: FarmTheme.spaceSm),
          Text('Certified Analysis (Planetek)', style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceSm),
          Consumer<PlanetekEudrProvider>(
            builder: (context, provider, _) {
              return LoadingErrorView(
                isLoading: provider.isLoading,
                errorMessage: provider.error,
                onRetry: provider.refreshAnalysis,
                builder: (context) {
                  if (provider.analysis == null) {
                    return EmptyState(
                      icon: Icons.verified_outlined,
                      title: 'No Certified Analysis Yet',
                      message: 'Run Planetek\'s digitally-signed EUDR '
                          'deforestation analysis against this farm\'s '
                          'boundary. This is a second, independent check '
                          'alongside the GFW screening above.',
                      actionLabel: 'Run Certified Analysis',
                      onAction: provider.refreshAnalysis,
                    );
                  }
                  return PlanetekAnalysisCard(
                    data: provider.analysis!,
                    onRefresh: provider.refreshAnalysis,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
