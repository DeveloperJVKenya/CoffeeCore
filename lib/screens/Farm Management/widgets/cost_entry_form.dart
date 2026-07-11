import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cost_model.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Reusable add-cost form used by `costs_subtab.dart`. Calls [onSubmit]
/// with the collected fields; the caller is responsible for persisting via
/// `FarmFinanceProvider.addCost`.
class CostEntryForm extends StatefulWidget {
  final void Function(CostCategory category, String description, double amount,
      DateTime date) onSubmit;

  const CostEntryForm({super.key, required this.onSubmit});

  @override
  State<CostEntryForm> createState() => _CostEntryFormState();
}

class _CostEntryFormState extends State<CostEntryForm> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  CostCategory _category = CostCategory.labour;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text);
    if (_descController.text.trim().isEmpty || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a description and a valid amount')),
      );
      return;
    }
    widget.onSubmit(_category, _descController.text.trim(), amount, _date);
    _descController.clear();
    _amountController.clear();
    setState(() => _date = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Cost', style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceSm),
          DropdownButtonFormField<CostCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: CostCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
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
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: FarmTheme.primaryBrown),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
