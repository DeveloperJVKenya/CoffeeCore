import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/inventory_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/inventory_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/loading_error_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Farm inventory (fertilizer, pesticide, tools, seedlings, etc.) list and
/// stock-transaction recorder, reachable from the Overview tab's quick
/// actions.
class InventoryScreen extends StatelessWidget {
  final String farmId;

  const InventoryScreen({super.key, required this.farmId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InventoryProvider>(
      create: (_) => InventoryProvider(farmId: farmId),
      child: const _InventoryView(),
    );
  }
}

class _InventoryView extends StatelessWidget {
  const _InventoryView();

  @override
  Widget build(BuildContext context) {
    final InventoryProvider provider = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: FarmTheme.cardBackground,
      appBar: AppBar(
        title: const Text('Inventory', style: FarmTheme.screenTitle),
        backgroundColor: FarmTheme.primaryBrown,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: FarmTheme.secondaryGreen,
        onPressed: () => _showAddItemDialog(context, provider),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: LoadingErrorView(
        isLoading: provider.isLoading,
        errorMessage: provider.error,
        builder: (BuildContext context) {
          if (provider.items.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2,
              title: 'No inventory items yet',
              message:
                  'Add fertilizer, tools, seedlings and more to track stock.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(FarmTheme.spaceMd),
            itemCount: provider.items.length,
            itemBuilder: (BuildContext context, int index) {
              final InventoryItem item = provider.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: FarmTheme.spaceSm),
                child: Container(
                  decoration: FarmTheme.cardDecoration(),
                  child: ListTile(
                    onTap: () => _showTransactionSheet(context, provider, item),
                    title: Text(item.name, style: FarmTheme.cardTitle),
                    subtitle: Text(
                      '${item.category.label} · '
                      '${item.quantityOnHand.toStringAsFixed(1)} ${item.unit}',
                    ),
                    trailing: item.isLowStock
                        ? const Chip(
                            label: Text('Low stock'),
                            backgroundColor: FarmTheme.accentBad,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, InventoryProvider provider) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController unitCtrl = TextEditingController();
    final TextEditingController quantityCtrl = TextEditingController(text: '0');
    final TextEditingController reorderCtrl = TextEditingController(text: '0');
    InventoryCategory category = InventoryCategory.fertilizer;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add Inventory Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Item name'),
                    ),
                    DropdownButtonFormField<InventoryCategory>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: <DropdownMenuItem<InventoryCategory>>[
                        for (final InventoryCategory c
                            in InventoryCategory.values)
                          DropdownMenuItem<InventoryCategory>(
                            value: c,
                            child: Text(c.label),
                          ),
                      ],
                      onChanged: (InventoryCategory? value) {
                        if (value != null) {
                          setDialogState(() => category = value);
                        }
                      },
                    ),
                    TextField(
                      controller: unitCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Unit (e.g. kg, L)'),
                    ),
                    TextField(
                      controller: quantityCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Initial quantity'),
                    ),
                    TextField(
                      controller: reorderCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Reorder level'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String name = nameCtrl.text.trim();
                    final String unit = unitCtrl.text.trim();
                    if (name.isEmpty || unit.isEmpty) return;
                    final DateTime now = DateTime.now();
                    provider.addItem(
                      InventoryItem(
                        farmId: provider.farmId,
                        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                        name: name,
                        category: category,
                        unit: unit,
                        quantityOnHand: double.tryParse(quantityCtrl.text) ?? 0,
                        reorderLevel: double.tryParse(reorderCtrl.text) ?? 0,
                        createdAt: now,
                        updatedAt: now,
                      ),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTransactionSheet(
    BuildContext context,
    InventoryProvider provider,
    InventoryItem item,
  ) {
    final TextEditingController quantityCtrl = TextEditingController();
    InventoryTransactionType type = InventoryTransactionType.stockIn;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: FarmTheme.spaceMd,
                right: FarmTheme.spaceMd,
                top: FarmTheme.spaceMd,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    FarmTheme.spaceMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.name, style: FarmTheme.cardTitle),
                  Text(
                    'Current stock: ${item.quantityOnHand.toStringAsFixed(1)} ${item.unit}',
                  ),
                  const SizedBox(height: FarmTheme.spaceMd),
                  SegmentedButton<InventoryTransactionType>(
                    segments: const <ButtonSegment<InventoryTransactionType>>[
                      ButtonSegment<InventoryTransactionType>(
                        value: InventoryTransactionType.stockIn,
                        label: Text('Stock In'),
                      ),
                      ButtonSegment<InventoryTransactionType>(
                        value: InventoryTransactionType.stockOut,
                        label: Text('Stock Out'),
                      ),
                    ],
                    selected: <InventoryTransactionType>{type},
                    onSelectionChanged:
                        (Set<InventoryTransactionType> selection) {
                      setSheetState(() => type = selection.first);
                    },
                  ),
                  const SizedBox(height: FarmTheme.spaceMd),
                  TextField(
                    controller: quantityCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: 'Quantity (${item.unit})'),
                  ),
                  const SizedBox(height: FarmTheme.spaceMd),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final double? quantity =
                            double.tryParse(quantityCtrl.text);
                        if (quantity == null || quantity <= 0) return;
                        provider.recordTransaction(
                          item: item,
                          type: type,
                          quantity: quantity,
                        );
                        Navigator.of(sheetContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FarmTheme.secondaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
