import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/legacy_migration_service.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// One-time prompt shown when the user has legacy `FarmData/{uid}` cycles
/// that haven't been migrated onto the new per-farm schema yet. Lets the
/// user pick a target farm and migrate, or dismiss the prompt for good.
class LegacyMigrationScreen extends StatefulWidget {
  const LegacyMigrationScreen({super.key});

  @override
  State<LegacyMigrationScreen> createState() => _LegacyMigrationScreenState();
}

class _LegacyMigrationScreenState extends State<LegacyMigrationScreen> {
  static final Logger _logger = Logger(printer: PrettyPrinter());

  final LegacyMigrationService _legacyService = LegacyMigrationService();
  final FarmMappingService _mappingService = FarmMappingService();

  bool _isLoadingNames = true;
  List<String> _legacyCycleNames = <String>[];
  String? _selectedFarmId;
  bool _isMigrating = false;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _loadLegacyCycleNames();
  }

  Future<void> _loadLegacyCycleNames() async {
    try {
      final List<String> names = await _legacyService.legacyCycleNames();
      if (!mounted) return;
      setState(() {
        _legacyCycleNames = names;
        _isLoadingNames = false;
      });
    } catch (e, st) {
      _logger.e('Failed to load legacy cycle names', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _isLoadingNames = false);
    }
  }

  Future<void> _migrate() async {
    final String? farmId = _selectedFarmId;
    if (farmId == null) return;
    setState(() => _isMigrating = true);
    try {
      final int count = await _legacyService.migrateAllCycles(farmId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Migrated $count cycle(s) successfully.')),
      );
      Navigator.of(context).pop();
    } catch (e, st) {
      _logger.e('Failed to migrate legacy cycles', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _isMigrating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Migration failed. Please try again.')),
      );
    }
  }

  Future<void> _skip() async {
    setState(() => _isDismissing = true);
    try {
      await _legacyService.dismissMigrationPrompt();
    } catch (e, st) {
      _logger.e('Failed to dismiss migration prompt', error: e, stackTrace: st);
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmTheme.cardBackground,
      appBar: AppBar(
        title:
            const Text('Migrate Old Farm Data', style: FarmTheme.screenTitle),
        backgroundColor: FarmTheme.primaryBrown,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(FarmTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(FarmTheme.spaceMd),
              decoration: FarmTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('We found older farm cycle records',
                      style: FarmTheme.cardTitle),
                  const SizedBox(height: FarmTheme.spaceSm),
                  Text(
                    _isLoadingNames
                        ? 'Checking for legacy cycles...'
                        : '${_legacyCycleNames.length} legacy cycle(s) found: '
                            '${_legacyCycleNames.join(", ")}',
                  ),
                  const SizedBox(height: FarmTheme.spaceMd),
                  const Text(
                    'Your account has cycle data from before farms were '
                    'mapped individually. You can convert these old cycles '
                    'into the new per-farm format by assigning them to one '
                    'of your mapped farms below. Your original data will be '
                    'kept as a backup and will not be deleted.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FarmTheme.spaceLg),
            const Text('Select target farm', style: FarmTheme.cardTitle),
            const SizedBox(height: FarmTheme.spaceSm),
            StreamBuilder<List<FarmPolygon>>(
              stream: _mappingService.userFarmsStream(),
              builder: (BuildContext context,
                  AsyncSnapshot<List<FarmPolygon>> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<FarmPolygon> farms = snapshot.data!;
                if (farms.isEmpty) {
                  return const Text('No farms available to migrate into.');
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedFarmId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Farm',
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final FarmPolygon farm in farms)
                      if (farm.farmId != null)
                        DropdownMenuItem<String>(
                          value: farm.farmId,
                          child: Text(farm.farmName),
                        ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _selectedFarmId = value),
                );
              },
            ),
            const SizedBox(height: FarmTheme.spaceLg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_selectedFarmId == null || _isMigrating) ? null : _migrate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmTheme.secondaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isMigrating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Migrate'),
              ),
            ),
            const SizedBox(height: FarmTheme.spaceSm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isDismissing ? null : _skip,
                child: const Text('Not Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
