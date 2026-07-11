import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/loan_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_cycle_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_finance_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';

/// Loans sub-tab: loan cards with computed interest/balance, a "New Loan"
/// dialog, and per-loan "Record Payment" + repayment history.
class LoansSubtab extends StatelessWidget {
  const LoansSubtab({super.key});

  Future<void> _showNewLoanDialog(BuildContext context,
      FarmFinanceProvider financeProvider, String cycleId) async {
    final sourceController = TextEditingController();
    final principalController = TextEditingController();
    final rateController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Loan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sourceController,
              decoration:
                  const InputDecoration(labelText: 'Source (e.g. bank, SACCO)'),
            ),
            TextField(
              controller: principalController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Principal'),
            ),
            TextField(
              controller: rateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Interest Rate (%)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: FarmTheme.primaryBrown),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final double? principal = double.tryParse(principalController.text.trim());
    final double? rate = double.tryParse(rateController.text.trim());
    if (sourceController.text.trim().isEmpty ||
        principal == null ||
        rate == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please enter a valid source, principal and rate.')),
        );
      }
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    financeProvider.addLoan(
      LoanRecord(
        farmId: financeProvider.farmId,
        cycleId: cycleId,
        userId: user.uid,
        source: sourceController.text.trim(),
        principal: principal,
        interestRate: rate,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _showRecordPaymentDialog(BuildContext context,
      FarmFinanceProvider financeProvider, LoanRecord loan) async {
    final amountController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record Payment'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'Amount (balance: ${loan.remainingBalance.toStringAsFixed(2)})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: FarmTheme.primaryBrown),
            child: const Text('Record', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final double? amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid payment amount.')),
        );
      }
      return;
    }
    financeProvider.recordRepayment(loan, amount);
  }

  @override
  Widget build(BuildContext context) {
    final String? activeCycleId =
        context.watch<FarmCycleProvider>().activeCycleId;
    if (activeCycleId == null) {
      return const EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'No Active Cycle',
        message: 'Start a cycle first to record loans.',
      );
    }

    return Consumer<FarmFinanceProvider>(
      builder: (context, financeProvider, _) {
        return ListView(
          padding: const EdgeInsets.all(FarmTheme.spaceMd),
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  _showNewLoanDialog(context, financeProvider, activeCycleId),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('New Loan'),
            ),
            const SizedBox(height: FarmTheme.spaceMd),
            if (financeProvider.loans.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: FarmTheme.spaceLg),
                child: EmptyState(
                  icon: Icons.request_quote_outlined,
                  title: 'No Loans Recorded',
                  message:
                      'Loans you add will appear here with balance tracking.',
                ),
              )
            else
              ...financeProvider.loans.map(
                (loan) => _buildLoanCard(context, financeProvider, loan),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLoanCard(BuildContext context,
      FarmFinanceProvider financeProvider, LoanRecord loan) {
    return Container(
      margin: const EdgeInsets.only(bottom: FarmTheme.spaceMd),
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(loan.source, style: FarmTheme.cardTitle)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (loan.isPaidOff
                          ? FarmTheme.accentGood
                          : FarmTheme.accentBad)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  loan.isPaidOff ? 'Paid Off' : 'Active',
                  style: TextStyle(
                    color: loan.isPaidOff
                        ? FarmTheme.accentGood
                        : FarmTheme.accentBad,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Text('Principal: ${loan.principal.toStringAsFixed(2)}'),
          Text('Interest (${loan.interestRate.toStringAsFixed(1)}%): '
              '${loan.interest.toStringAsFixed(2)}'),
          Text('Total Repayment: ${loan.totalRepayment.toStringAsFixed(2)}'),
          Text(
            'Remaining Balance: ${loan.remainingBalance.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (loan.repayments.isNotEmpty) ...[
            const SizedBox(height: FarmTheme.spaceSm),
            const Text('Repayment History',
                style: TextStyle(fontWeight: FontWeight.w600)),
            for (final repayment in loan.repayments)
              Text(
                '${repayment.date.toIso8601String().substring(0, 10)}: '
                '${repayment.amount.toStringAsFixed(2)} '
                '(balance: ${repayment.remainingBalanceAfter.toStringAsFixed(2)})',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
          const SizedBox(height: FarmTheme.spaceSm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: loan.isPaidOff
                  ? null
                  : () =>
                      _showRecordPaymentDialog(context, financeProvider, loan),
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Record Payment'),
            ),
          ),
        ],
      ),
    );
  }
}
