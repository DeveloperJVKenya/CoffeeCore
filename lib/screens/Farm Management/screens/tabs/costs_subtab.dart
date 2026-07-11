import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cost_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_cycle_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_finance_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/cost_entry_form.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';

/// Costs sub-tab: add-cost form + list of `CostEntry` rows for the active
/// cycle, with delete.
class CostsSubtab extends StatelessWidget {
  const CostsSubtab({super.key});

  @override
  Widget build(BuildContext context) {
    final String? activeCycleId =
        context.watch<FarmCycleProvider>().activeCycleId;
    if (activeCycleId == null) {
      return const EmptyState(
        icon: Icons.attach_money,
        title: 'No Active Cycle',
        message: 'Start a cycle first to record costs.',
      );
    }

    return Consumer<FarmFinanceProvider>(
      builder: (context, financeProvider, _) {
        return ListView(
          padding: const EdgeInsets.all(FarmTheme.spaceMd),
          children: [
            CostEntryForm(
              onSubmit: (category, description, amount, date) {
                final User? user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                financeProvider.addCost(
                  CostEntry(
                    farmId: financeProvider.farmId,
                    cycleId: activeCycleId,
                    userId: user.uid,
                    category: category,
                    description: description,
                    amount: amount,
                    date: date,
                    createdAt: DateTime.now(),
                  ),
                );
              },
            ),
            const SizedBox(height: FarmTheme.spaceMd),
            if (financeProvider.costs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: FarmTheme.spaceLg),
                child: EmptyState(
                  icon: Icons.receipt_long,
                  title: 'No Costs Yet',
                  message: 'Costs you add above will appear here.',
                ),
              )
            else
              ...financeProvider.costs.map(
                (cost) => Card(
                  margin: const EdgeInsets.only(bottom: FarmTheme.spaceXs),
                  child: ListTile(
                    title: Text(cost.description),
                    subtitle: Text(
                      '${cost.category.label} · ${cost.date.toIso8601String().substring(0, 10)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cost.amount.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: FarmTheme.accentBad),
                          onPressed: () => financeProvider.deleteCost(cost.id!),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
