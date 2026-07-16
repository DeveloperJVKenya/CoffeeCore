import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/farm_hub_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/farm_capture_remote_screen.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/farm_capture_screen.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/farm_detail_shell_screen.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/legacy_migration_screen.dart';
import 'package:coffeecore/screens/Farm%20Management/services/legacy_migration_service.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/farm_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/loading_error_view.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

/// Unified entry point for the Farm Management section.
///
/// Lists every farm the user has mapped, offers a floating action button
/// that lets the user choose between capturing a new farm by walking its
/// boundary with live GPS or mapping it remotely from satellite imagery,
/// and — on first load — checks for unmigrated legacy `FarmData` cycles
/// and, if found, offers to migrate them onto one of the user's existing
/// farms.
class FarmManagementHomeScreen extends StatelessWidget {
  const FarmManagementHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FarmHubProvider>(
      create: (_) => FarmHubProvider(),
      child: const _FarmManagementHomeView(),
    );
  }
}

class _FarmManagementHomeView extends StatefulWidget {
  const _FarmManagementHomeView();

  @override
  State<_FarmManagementHomeView> createState() =>
      _FarmManagementHomeViewState();
}

class _FarmManagementHomeViewState extends State<_FarmManagementHomeView> {
  static final Logger _logger = Logger(printer: PrettyPrinter());

  final LegacyMigrationService _legacyService = LegacyMigrationService();
  bool _checkedLegacyMigration = false;

  @override
  Widget build(BuildContext context) {
    final FarmHubProvider hubProvider = context.watch<FarmHubProvider>();

    if (!_checkedLegacyMigration && hubProvider.farms.isNotEmpty) {
      _checkedLegacyMigration = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybePromptLegacyMigration());
    }

    return Scaffold(
      backgroundColor: FarmTheme.cardBackground,
      appBar: AppBar(
        title: const Text('Farm Management', style: FarmTheme.screenTitle),
        backgroundColor: FarmTheme.primaryBrown,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: FarmTheme.secondaryGreen,
        onPressed: () => _showCaptureModePicker(context),
        tooltip: 'Map a new farm',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: LoadingErrorView(
        isLoading: hubProvider.isLoading,
        errorMessage: hubProvider.error,
        onRetry: () => setState(() {}),
        builder: (BuildContext context) {
          if (hubProvider.farms.isEmpty) {
            return EmptyState(
              icon: Icons.landscape,
              title: 'No farms yet',
              message: 'Map your first farm boundary to start tracking cycles, '
                  'costs, yield and compliance.',
              actionLabel: 'Map Your First Farm',
              onAction: () => _showCaptureModePicker(context),
            );
          }
          return RefreshIndicator(
            color: FarmTheme.secondaryGreen,
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(FarmTheme.spaceMd),
              itemCount: hubProvider.farms.length,
              itemBuilder: (BuildContext context, int index) {
                final farm = hubProvider.farms[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: FarmTheme.spaceMd),
                  child: FarmCard(
                    farm: farm,
                    onTap: () {
                      if (farm.farmId == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FarmDetailShellScreen(farmId: farm.farmId!),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showCaptureModePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.my_location,
                    color: FarmTheme.secondaryGreen),
                title: const Text('Map Live Location'),
                subtitle: const Text('Walk the boundary with GPS'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openLiveCaptureScreen(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.satellite_alt,
                    color: FarmTheme.primaryBrown),
                title: const Text('Map From Remote'),
                subtitle:
                    const Text('Zoom, pan and tap using satellite imagery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openRemoteCaptureScreen(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openLiveCaptureScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FarmCaptureScreen(),
      ),
    );
  }

  void _openRemoteCaptureScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FarmCaptureRemoteScreen(),
      ),
    );
  }

  Future<void> _maybePromptLegacyMigration() async {
    if (!mounted) return;
    try {
      final bool hasLegacy = await _legacyService.hasUnmigratedLegacyData();
      if (!hasLegacy || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LegacyMigrationScreen(),
        ),
      );
    } catch (e, st) {
      _logger.e('Failed to check legacy migration status',
          error: e, stackTrace: st);
    }
  }
}
