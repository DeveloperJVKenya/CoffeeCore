import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/climate_satellite_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/climate_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/drought_risk_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/forecast_strip.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/loading_error_view.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/satellite_card.dart';

/// Climate & Satellite tab: current conditions, 5-day forecast and NDVI
/// vegetation health, all sourced live via `ClimateSatelliteProvider`.
/// Never fabricates data — shows a fetch button / error state instead.
class ClimateSatelliteTab extends StatefulWidget {
  const ClimateSatelliteTab({super.key});

  @override
  State<ClimateSatelliteTab> createState() => _ClimateSatelliteTabState();
}

class _ClimateSatelliteTabState extends State<ClimateSatelliteTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ClimateSatelliteProvider>();
      if (provider.climate == null) provider.refreshClimate();
      if (provider.forecast.isEmpty) provider.refreshForecast();
      if (provider.activeSatellite == null) provider.refreshActiveSatellite();
      provider.loadNdviHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClimateSatelliteProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(FarmTheme.spaceMd),
          children: [
            LoadingErrorView(
              isLoading: provider.isLoadingClimate,
              errorMessage: provider.climateError,
              onRetry: provider.refreshClimate,
              builder: (context) {
                if (provider.climate == null) {
                  return _fetchButton(
                      'Fetch Climate Data', provider.refreshClimate);
                }
                return ClimateCard(
                  climate: provider.climate!,
                  onRefresh: provider.refreshClimate,
                );
              },
            ),
            const SizedBox(height: FarmTheme.spaceMd),
            LoadingErrorView(
              isLoading: provider.isLoadingForecast,
              errorMessage: provider.forecastError,
              onRetry: provider.refreshForecast,
              builder: (context) {
                if (provider.forecast.isEmpty) {
                  return _fetchButton(
                      'Load 5-Day Forecast', provider.refreshForecast);
                }
                return ForecastStrip(days: provider.forecast);
              },
            ),
            const SizedBox(height: FarmTheme.spaceMd),
            _satelliteSourceToggle(provider),
            const SizedBox(height: FarmTheme.spaceSm),
            LoadingErrorView(
              isLoading: provider.isLoadingActiveSatellite,
              errorMessage: provider.activeSatelliteError,
              onRetry: provider.refreshActiveSatellite,
              builder: (context) {
                if (provider.activeSatellite == null) {
                  return _fetchButton(
                      'Fetch Satellite Data', provider.refreshActiveSatellite);
                }
                return SatelliteCard(
                  satellite: provider.activeSatellite!,
                  onRefresh: provider.refreshActiveSatellite,
                  onRefreshNdwi:
                      provider.selectedSource == SatelliteSource.agroMonitoring
                          ? provider.refreshNdwi
                          : null,
                  isLoadingNdwi: provider.isLoadingNdwi,
                );
              },
            ),
            if (provider.ndwiError != null) ...[
              const SizedBox(height: FarmTheme.spaceSm),
              Text(provider.ndwiError!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: FarmTheme.spaceMd),
            if (provider.satellite == null)
              Container(
                padding: const EdgeInsets.all(FarmTheme.spaceMd),
                decoration: FarmTheme.cardDecoration(),
                child: const Text(
                  'Fetch satellite data above to see the Drought Risk Index.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              )
            else
              DroughtRiskCard(
                result: provider.droughtRisk!,
                onRefresh: () {
                  provider.refreshSatellite();
                  provider.refreshForecast();
                  provider.refreshClimate();
                },
              ),
          ],
        );
      },
    );
  }

  /// Lets the two satellite providers be selected and compared without
  /// either one being removed. Switching fetches the newly-selected
  /// source only if it hasn't been loaded yet — already-loaded data for
  /// either source stays cached so flipping back and forth is instant.
  Widget _satelliteSourceToggle(ClimateSatelliteProvider provider) {
    return SegmentedButton<SatelliteSource>(
      segments: const [
        ButtonSegment(
          value: SatelliteSource.agroMonitoring,
          label: Text('AgroMonitoring'),
          icon: Icon(Icons.satellite_alt, size: 16),
        ),
        ButtonSegment(
          value: SatelliteSource.sentinelHub,
          label: Text('Sentinel Hub'),
          icon: Icon(Icons.satellite, size: 16),
        ),
      ],
      selected: {provider.selectedSource},
      onSelectionChanged: (selection) {
        final source = selection.first;
        provider.setSatelliteSource(source);
        if (provider.activeSatellite == null &&
            !provider.isLoadingActiveSatellite) {
          provider.refreshActiveSatellite();
        }
      },
    );
  }

  Widget _fetchButton(String label, VoidCallback onPressed) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FarmTheme.spaceLg),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style:
              ElevatedButton.styleFrom(backgroundColor: FarmTheme.primaryBrown),
          icon: const Icon(Icons.cloud_download, color: Colors.white),
          label: Text(label, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
