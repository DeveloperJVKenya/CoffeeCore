import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cycle_stage.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_cycle_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/activity_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_cycle_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/activity_list_item.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/cycle_stage_badge.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/tabs/activity_form_screen.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/tabs/history_tab.dart';

/// Cycles & Activities tab: active-cycle card with "Advance Stage", a
/// "Start New Cycle" action, the activity list for the active cycle, and a
/// link to past-cycle history.
class CyclesActivitiesTab extends StatelessWidget {
  final String farmId;

  const CyclesActivitiesTab({super.key, required this.farmId});

  Future<void> _showAdvanceStageDialog(
      BuildContext context, FarmCycleProvider provider, FarmCycle cycle) async {
    final CycleStage? next = cycle.currentStage.next;
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This cycle is already at its final stage.')),
      );
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Advance Stage'),
        content: Text('Move "${cycle.name}" from ${cycle.currentStage.label} '
            'to ${next.label}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: FarmTheme.primaryBrown),
            child: const Text('Advance', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.advanceStage(cycle, next);
    }
  }

  Future<void> _showStartCycleDialog(
      BuildContext context, FarmCycleProvider provider) async {
    final nameController = TextEditingController();
    final yearController =
        TextEditingController(text: DateTime.now().year.toString());
    final varietyController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start New Cycle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Cycle Name'),
            ),
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year'),
            ),
            TextField(
              controller: varietyController,
              decoration: const InputDecoration(
                  labelText: 'Variety Planted (optional)'),
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
            child: const Text('Start', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final String name = nameController.text.trim();
    final int? year = int.tryParse(yearController.text.trim());
    if (name.isEmpty || year == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid name and year.')),
        );
      }
      return;
    }
    await provider.startNewCycle(
      name: name,
      year: year,
      varietyPlanted: varietyController.text.trim().isEmpty
          ? null
          : varietyController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FarmCycleProvider>(
      builder: (context, cycleProvider, _) {
        final FarmCycle? activeCycle = cycleProvider.activeCycle;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: activeCycle == null
              ? null
              : FloatingActionButton(
                  backgroundColor: FarmTheme.primaryBrown,
                  onPressed: () {
                    final ActivityProvider activityProvider =
                        context.read<ActivityProvider>();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ChangeNotifierProvider<ActivityProvider>.value(
                          value: activityProvider,
                          child: ActivityFormScreen(
                            farmId: farmId,
                            cycleId: activeCycle.id!,
                            stage: activeCycle.currentStage,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                ),
          body: ListView(
            padding: const EdgeInsets.all(FarmTheme.spaceMd),
            children: [
              _buildCycleCard(context, cycleProvider, activeCycle),
              const SizedBox(height: FarmTheme.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showStartCycleDialog(context, cycleProvider),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Start New Cycle'),
                    ),
                  ),
                  const SizedBox(width: FarmTheme.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final FarmCycleProvider provider =
                            context.read<FarmCycleProvider>();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ChangeNotifierProvider<FarmCycleProvider>.value(
                              value: provider,
                              child: Scaffold(
                                appBar: AppBar(
                                  title: const Text('Cycle History'),
                                  backgroundColor: FarmTheme.primaryBrown,
                                ),
                                body: HistoryTab(farmId: farmId),
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FarmTheme.spaceMd),
              const Text('Activities', style: FarmTheme.cardTitle),
              const SizedBox(height: FarmTheme.spaceSm),
              _buildActivityList(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCycleCard(
      BuildContext context, FarmCycleProvider provider, FarmCycle? cycle) {
    if (cycle == null) {
      return Container(
        decoration: FarmTheme.cardDecoration(),
        child: const EmptyState(
          icon: Icons.eco_outlined,
          title: 'No Active Cycle',
          message: 'Start a new cycle below to begin tracking this farm.',
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cycle.name, style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceXs),
          Text('Year ${cycle.year}'
              '${cycle.varietyPlanted != null ? ' · ${cycle.varietyPlanted}' : ''}'),
          const SizedBox(height: FarmTheme.spaceSm),
          CycleStageBadge(stage: cycle.currentStage),
          const SizedBox(height: FarmTheme.spaceSm),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _showAdvanceStageDialog(context, provider, cycle),
              style: ElevatedButton.styleFrom(
                  backgroundColor: FarmTheme.secondaryGreen),
              icon: const Icon(Icons.arrow_forward,
                  color: Colors.white, size: 16),
              label: const Text('Advance Stage',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList(BuildContext context) {
    return Consumer<ActivityProvider>(
      builder: (context, activityProvider, _) {
        if (activityProvider.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(FarmTheme.spaceLg),
            child: Center(
                child:
                    CircularProgressIndicator(color: FarmTheme.primaryBrown)),
          );
        }
        if (activityProvider.activities.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: FarmTheme.spaceLg),
            child: EmptyState(
              icon: Icons.checklist_outlined,
              title: 'No Activities Logged',
              message: 'Use the + button to log labour, mechanical, input or '
                  'observation activities for this cycle.',
            ),
          );
        }
        return Column(
          children: activityProvider.activities
              .map((activity) => ActivityListItem(
                    activity: activity,
                    onDelete: () =>
                        activityProvider.deleteActivity(activity.id!),
                  ))
              .toList(),
        );
      },
    );
  }
}
