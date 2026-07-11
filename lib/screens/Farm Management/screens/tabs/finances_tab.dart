import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/tabs/costs_subtab.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/tabs/loans_subtab.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/tabs/profit_loss_subtab.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/tabs/revenue_subtab.dart';

/// Finances tab shell: nested TabBar for Costs / Revenue / P&L / Loans.
class FinancesTab extends StatelessWidget {
  const FinancesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: FarmTheme.cardBackground,
            child: const TabBar(
              labelColor: FarmTheme.primaryBrown,
              unselectedLabelColor: Colors.black54,
              indicatorColor: FarmTheme.primaryBrown,
              isScrollable: true,
              tabs: [
                Tab(text: 'Costs'),
                Tab(text: 'Revenue'),
                Tab(text: 'P&L'),
                Tab(text: 'Loans'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                CostsSubtab(),
                RevenueSubtab(),
                ProfitLossSubtab(),
                LoansSubtab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
