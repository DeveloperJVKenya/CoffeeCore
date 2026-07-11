import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Displays a [ClimateData] snapshot. Never shows fabricated placeholder
/// numbers — callers should only render this once real data is available.
class ClimateCard extends StatelessWidget {
  final ClimateData climate;
  final VoidCallback? onRefresh;

  const ClimateCard({super.key, required this.climate, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.thermostat, color: FarmTheme.primaryBrownAlt),
              const SizedBox(width: FarmTheme.spaceSm),
              const Text('Current Conditions', style: FarmTheme.cardTitle),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRefresh,
                ),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Text(
            '${climate.temperatureCelsius.toStringAsFixed(1)}°C · ${climate.weatherDescription}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Wrap(
            spacing: FarmTheme.spaceMd,
            runSpacing: FarmTheme.spaceXs,
            children: [
              _metric(Icons.water_drop,
                  '${climate.humidity.toStringAsFixed(0)}% humidity'),
              _metric(Icons.grain,
                  '${climate.rainfallMm.toStringAsFixed(1)} mm rain'),
              _metric(Icons.air,
                  '${climate.windSpeedMs.toStringAsFixed(1)} m/s wind'),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceXs),
          Text(
            'Updated ${climate.fetchedAt.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}
