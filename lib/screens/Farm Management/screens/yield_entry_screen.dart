import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/yield_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/yield_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/services/yield_service.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/loading_error_view.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/stat_tile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Yield record list + entry form for a specific farm cycle, reachable from
/// the Cycles & Activities tab during the Harvest / Post-Harvest stages.
class YieldEntryScreen extends StatelessWidget {
  final String farmId;
  final String cycleId;

  const YieldEntryScreen({
    super.key,
    required this.farmId,
    required this.cycleId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<YieldProvider>(
      create: (_) => YieldProvider(farmId: farmId)..updateCycle(cycleId),
      child: _YieldEntryView(farmId: farmId, cycleId: cycleId),
    );
  }
}

class _YieldEntryView extends StatelessWidget {
  final String farmId;
  final String cycleId;

  const _YieldEntryView({required this.farmId, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    final YieldProvider provider = context.watch<YieldProvider>();
    final YieldStats stats = provider.stats;

    return Scaffold(
      backgroundColor: FarmTheme.cardBackground,
      appBar: AppBar(
        title: const Text('Yield Records', style: FarmTheme.screenTitle),
        backgroundColor: FarmTheme.primaryBrown,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: FarmTheme.secondaryGreen,
        onPressed: () => _showAddRecordDialog(context, provider),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: LoadingErrorView(
        isLoading: provider.isLoading,
        errorMessage: provider.error,
        builder: (BuildContext context) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(FarmTheme.spaceMd),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: StatTile(
                        icon: Icons.scale,
                        value: '${stats.totalKg.toStringAsFixed(1)} kg',
                        label: 'Total Harvested',
                        color: FarmTheme.secondaryGreen,
                      ),
                    ),
                    const SizedBox(width: FarmTheme.spaceSm),
                    Expanded(
                      child: StatTile(
                        icon: Icons.water_drop,
                        value: '${stats.averageMoisture.toStringAsFixed(1)}%',
                        label: 'Avg Moisture',
                        color: FarmTheme.primaryBrownAlt,
                      ),
                    ),
                    const SizedBox(width: FarmTheme.spaceSm),
                    Expanded(
                      child: StatTile(
                        icon: Icons.receipt_long,
                        value: '${stats.recordCount}',
                        label: 'Records',
                        color: FarmTheme.primaryBrown,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.records.isEmpty
                    ? const EmptyState(
                        icon: Icons.grass,
                        title: 'No yield records yet',
                        message:
                            'Log harvested cherry weight, grade and moisture '
                            'content as you pick.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FarmTheme.spaceMd,
                        ),
                        itemCount: provider.records.length,
                        itemBuilder: (BuildContext context, int index) {
                          final YieldRecord record = provider.records[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: FarmTheme.spaceSm,
                            ),
                            child: Container(
                              decoration: FarmTheme.cardDecoration(),
                              child: ListTile(
                                title: Text(
                                  '${record.kgHarvested.toStringAsFixed(1)} kg'
                                  '${record.grade != null ? " · Grade ${record.grade}" : ""}',
                                  style: FarmTheme.cardTitle,
                                ),
                                subtitle: Text(
                                  '${DateFormat('dd MMM yyyy').format(record.date)}'
                                  '${record.moistureContent != null ? " · Moisture ${record.moistureContent!.toStringAsFixed(1)}%" : ""}'
                                  '${record.notes != null && record.notes!.isNotEmpty ? "\n${record.notes}" : ""}',
                                ),
                                isThreeLine: record.notes != null &&
                                    record.notes!.isNotEmpty,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: FarmTheme.accentBad),
                                  onPressed: () {
                                    if (record.id != null) {
                                      provider.deleteRecord(record.id!);
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddRecordDialog(BuildContext context, YieldProvider provider) {
    final TextEditingController kgCtrl = TextEditingController();
    final TextEditingController gradeCtrl = TextEditingController();
    final TextEditingController moistureCtrl = TextEditingController();
    final TextEditingController notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add Yield Record'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    TextField(
                      controller: kgCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Kg harvested'),
                    ),
                    TextField(
                      controller: gradeCtrl,
                      decoration: const InputDecoration(labelText: 'Grade'),
                    ),
                    TextField(
                      controller: moistureCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Moisture content (%)'),
                    ),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes'),
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
                    final double? kg = double.tryParse(kgCtrl.text);
                    if (kg == null || kg <= 0) return;
                    provider.addRecord(
                      YieldRecord(
                        farmId: farmId,
                        cycleId: cycleId,
                        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                        date: selectedDate,
                        kgHarvested: kg,
                        grade: gradeCtrl.text.trim().isEmpty
                            ? null
                            : gradeCtrl.text.trim(),
                        moistureContent: double.tryParse(moistureCtrl.text),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        createdAt: DateTime.now(),
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
}
