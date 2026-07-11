import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/eudr_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/eudr_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/loading_error_view.dart';

/// EUDR Compliance tab: deforestation-risk verdict sourced live via
/// `EudrProvider`. Never fabricates a result — shows an explanatory empty
/// state with a manual "Run EUDR Check" action until real data exists.
class EudrComplianceTab extends StatelessWidget {
  const EudrComplianceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EudrProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(FarmTheme.spaceMd),
          child: LoadingErrorView(
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
          ),
        );
      },
    );
  }
}
