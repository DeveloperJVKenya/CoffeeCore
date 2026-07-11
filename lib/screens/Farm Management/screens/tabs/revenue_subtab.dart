import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/revenue_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_cycle_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_finance_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';

/// Revenue sub-tab: add-revenue form (variety, kg, grade, price/kg — amount
/// computed automatically) + list of `RevenueEntry` rows, with delete.
class RevenueSubtab extends StatefulWidget {
  const RevenueSubtab({super.key});

  @override
  State<RevenueSubtab> createState() => _RevenueSubtabState();
}

class _RevenueSubtabState extends State<RevenueSubtab> {
  final TextEditingController _varietyController = TextEditingController();
  final TextEditingController _kgController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _varietyController.dispose();
    _kgController.dispose();
    _gradeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit(FarmFinanceProvider financeProvider, String cycleId) {
    final double? kg = double.tryParse(_kgController.text.trim());
    final double? pricePerKg = double.tryParse(_priceController.text.trim());
    if (_varietyController.text.trim().isEmpty ||
        kg == null ||
        pricePerKg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter variety, kg and price per kg.')),
      );
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    financeProvider.addRevenue(
      RevenueEntry(
        farmId: financeProvider.farmId,
        cycleId: cycleId,
        userId: user.uid,
        variety: _varietyController.text.trim(),
        kg: kg,
        grade: _gradeController.text.trim().isEmpty
            ? null
            : _gradeController.text.trim(),
        pricePerKg: pricePerKg,
        amount: kg * pricePerKg,
        date: _date,
        createdAt: DateTime.now(),
      ),
    );
    _varietyController.clear();
    _kgController.clear();
    _gradeController.clear();
    _priceController.clear();
    setState(() => _date = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final String? activeCycleId =
        context.watch<FarmCycleProvider>().activeCycleId;
    if (activeCycleId == null) {
      return const EmptyState(
        icon: Icons.sell_outlined,
        title: 'No Active Cycle',
        message: 'Start a cycle first to record revenue.',
      );
    }

    return Consumer<FarmFinanceProvider>(
      builder: (context, financeProvider, _) {
        final double? kg = double.tryParse(_kgController.text.trim());
        final double? pricePerKg =
            double.tryParse(_priceController.text.trim());
        final double computedAmount = (kg ?? 0) * (pricePerKg ?? 0);
        return ListView(
          padding: const EdgeInsets.all(FarmTheme.spaceMd),
          children: [
            Container(
              padding: const EdgeInsets.all(FarmTheme.spaceMd),
              decoration: FarmTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Revenue', style: FarmTheme.cardTitle),
                  const SizedBox(height: FarmTheme.spaceSm),
                  TextField(
                    controller: _varietyController,
                    decoration: const InputDecoration(labelText: 'Variety'),
                  ),
                  TextField(
                    controller: _kgController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Kilograms'),
                    onChanged: (_) => setState(() {}),
                  ),
                  TextField(
                    controller: _gradeController,
                    decoration:
                        const InputDecoration(labelText: 'Grade (optional)'),
                  ),
                  TextField(
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Price per Kg'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: FarmTheme.spaceSm),
                  Text('Amount: ${computedAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: FarmTheme.spaceSm),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_date.toIso8601String().substring(0, 10)),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            _submit(financeProvider, activeCycleId),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: FarmTheme.primaryBrown),
                        child: const Text('Add',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: FarmTheme.spaceMd),
            if (financeProvider.revenues.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: FarmTheme.spaceLg),
                child: EmptyState(
                  icon: Icons.sell_outlined,
                  title: 'No Revenue Yet',
                  message: 'Sales you add above will appear here.',
                ),
              )
            else
              ...financeProvider.revenues.map(
                (revenue) => Card(
                  margin: const EdgeInsets.only(bottom: FarmTheme.spaceXs),
                  child: ListTile(
                    title: Text(
                      '${revenue.variety}${revenue.grade != null ? ' (${revenue.grade})' : ''}',
                    ),
                    subtitle: Text(
                      '${revenue.kg.toStringAsFixed(1)} kg @ ${revenue.pricePerKg.toStringAsFixed(2)} · '
                      '${revenue.date.toIso8601String().substring(0, 10)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          revenue.amount.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: FarmTheme.accentBad),
                          onPressed: () =>
                              financeProvider.deleteRevenue(revenue.id!),
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
