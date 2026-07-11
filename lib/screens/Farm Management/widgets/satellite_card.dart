import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Displays a [SatelliteData] (NDVI) snapshot.
class SatelliteCard extends StatelessWidget {
  final SatelliteData satellite;
  final VoidCallback? onRefresh;

  const SatelliteCard({super.key, required this.satellite, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final Color healthColor =
        FarmTheme.colorForVegetationHealth(satellite.vegetationHealth);
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: FarmTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.satellite_alt, color: FarmTheme.primaryBrownAlt),
              const SizedBox(width: FarmTheme.spaceSm),
              const Text('Vegetation Health (NDVI)',
                  style: FarmTheme.cardTitle),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: onRefresh),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  satellite.vegetationHealth,
                  style: TextStyle(
                      color: healthColor, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: FarmTheme.spaceSm),
              Text('NDVI: ${satellite.ndviScore.toStringAsFixed(3)}'),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: satellite.ndviFraction,
              minHeight: 8,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(healthColor),
            ),
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Text(
              'Soil moisture index: ${satellite.soilMoistureIndex.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text('Source: ${satellite.dataSource}',
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ],
      ),
    );
  }
}
