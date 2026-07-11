import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/climate_satellite_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/climate_card.dart';
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
      if (provider.satellite == null) provider.refreshSatellite();
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
            LoadingErrorView(
              isLoading: provider.isLoadingSatellite,
              errorMessage: provider.satelliteError,
              onRetry: provider.refreshSatellite,
              builder: (context) {
                if (provider.satellite == null) {
                  return _fetchButton(
                      'Fetch Satellite Data', provider.refreshSatellite);
                }
                return SatelliteCard(
                  satellite: provider.satellite!,
                  onRefresh: provider.refreshSatellite,
                );
              },
            ),
          ],
        );
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
