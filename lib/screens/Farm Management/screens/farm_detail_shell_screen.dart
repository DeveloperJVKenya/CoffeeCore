import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/activity_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/climate_satellite_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/eudr_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_cycle_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_finance_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/inventory_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/yield_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'tabs/climate_satellite_tab.dart';
import 'tabs/cycles_activities_tab.dart';
import 'tabs/eudr_compliance_tab.dart';
import 'tabs/finances_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/reports_tab.dart';

/// Per-farm scaffold: fetches the [FarmPolygon] for [farmId], then hosts a
/// six-tab `TabBarView` wrapped in a `MultiProvider` of farm-scoped
/// providers (cycles, activities, finances, inventory, yield, climate &
/// satellite, EUDR compliance).
class FarmDetailShellScreen extends StatefulWidget {
  final String farmId;

  const FarmDetailShellScreen({super.key, required this.farmId});

  @override
  State<FarmDetailShellScreen> createState() => _FarmDetailShellScreenState();
}

class _FarmDetailShellScreenState extends State<FarmDetailShellScreen> {
  static final Logger _logger = Logger(printer: PrettyPrinter());

  final FarmMappingService _mappingService = FarmMappingService();

  bool _isLoading = true;
  String? _error;
  FarmPolygon? _farm;

  @override
  void initState() {
    super.initState();
    _loadFarm();
  }

  Future<void> _loadFarm() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final FarmPolygon? farm =
          await _mappingService.getFarmById(widget.farmId);
      if (!mounted) return;
      setState(() {
        _farm = farm;
        _isLoading = false;
        _error = farm == null ? 'Farm not found.' : null;
      });
    } catch (e, st) {
      _logger.e('Failed to load farm', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load farm. Please try again.';
      });
    }
  }

  Future<void> _renameFarm() async {
    final FarmPolygon? farm = _farm;
    if (farm == null) return;
    final TextEditingController controller =
        TextEditingController(text: farm.farmName);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Rename Farm'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Farm name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newName == null || newName.isEmpty || !mounted) return;
    try {
      await _mappingService.renameFarm(widget.farmId, newName);
      if (!mounted) return;
      setState(() => _farm = farm.copyWith(farmName: newName));
    } catch (e, st) {
      _logger.e('Failed to rename farm', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to rename farm.')),
      );
    }
  }

  Future<void> _deleteFarm() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Farm'),
          content: const Text(
            'This will permanently delete this farm and its boundary data. '
            'This action cannot be undone. Continue?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: FarmTheme.accentBad,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await _mappingService.deleteFarm(widget.farmId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      _logger.e('Failed to delete farm', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete farm.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final FarmPolygon? farm = _farm;
    if (_error != null || farm == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: FarmTheme.primaryBrown,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(FarmTheme.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline,
                    size: 48, color: FarmTheme.accentBad),
                const SizedBox(height: FarmTheme.spaceMd),
                Text(_error ?? 'Farm not found.'),
                const SizedBox(height: FarmTheme.spaceMd),
                ElevatedButton(
                  onPressed: _loadFarm,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final String farmId = widget.farmId;

    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<FarmCycleProvider>(
          create: (_) => FarmCycleProvider(farmId: farmId),
        ),
        ChangeNotifierProxyProvider<FarmCycleProvider, ActivityProvider>(
          create: (_) => ActivityProvider(farmId: farmId),
          update: (_, FarmCycleProvider cycleProvider,
                  ActivityProvider? previous) =>
              (previous ?? ActivityProvider(farmId: farmId))
                ..updateCycle(cycleProvider.activeCycleId),
        ),
        ChangeNotifierProxyProvider<FarmCycleProvider, FarmFinanceProvider>(
          create: (_) => FarmFinanceProvider(farmId: farmId),
          update: (_, FarmCycleProvider cycleProvider,
                  FarmFinanceProvider? previous) =>
              (previous ?? FarmFinanceProvider(farmId: farmId))
                ..updateCycle(cycleProvider.activeCycleId),
        ),
        ChangeNotifierProxyProvider<FarmCycleProvider, YieldProvider>(
          create: (_) => YieldProvider(farmId: farmId),
          update:
              (_, FarmCycleProvider cycleProvider, YieldProvider? previous) =>
                  (previous ?? YieldProvider(farmId: farmId))
                    ..updateCycle(cycleProvider.activeCycleId),
        ),
        ChangeNotifierProvider<InventoryProvider>(
          create: (_) => InventoryProvider(farmId: farmId),
        ),
        ChangeNotifierProvider<ClimateSatelliteProvider>(
          create: (_) => ClimateSatelliteProvider(farm: farm),
        ),
        ChangeNotifierProvider<EudrProvider>(
          create: (_) => EudrProvider(farm: farm),
        ),
      ],
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          backgroundColor: FarmTheme.cardBackground,
          appBar: AppBar(
            title: Text(farm.farmName, style: FarmTheme.screenTitle),
            backgroundColor: FarmTheme.primaryBrown,
            foregroundColor: Colors.white,
            actions: <Widget>[
              PopupMenuButton<String>(
                onSelected: (String value) {
                  if (value == 'rename') _renameFarm();
                  if (value == 'delete') _deleteFarm();
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'rename',
                    child: Text('Rename Farm'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete Farm'),
                  ),
                ],
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: <Widget>[
                Tab(text: 'Overview'),
                Tab(text: 'Cycles & Activities'),
                Tab(text: 'Finances'),
                Tab(text: 'Climate & Satellite'),
                Tab(text: 'EUDR Compliance'),
                Tab(text: 'Reports'),
              ],
            ),
          ),
          body: TabBarView(
            children: <Widget>[
              OverviewTab(farm: farm, farmId: farmId),
              CyclesActivitiesTab(farmId: farmId),
              const FinancesTab(),
              const ClimateSatelliteTab(),
              const EudrComplianceTab(),
              const ReportsTab(),
            ],
          ),
        ),
      ),
    );
  }
}
