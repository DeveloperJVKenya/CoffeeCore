import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/farm_map_thumbnail.dart';

/// Card representing a single farm in the hub list.
class FarmCard extends StatelessWidget {
  final FarmPolygon farm;
  final VoidCallback onTap;

  const FarmCard({super.key, required this.farm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FarmTheme.radiusCard),
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: FarmTheme.spaceMd, vertical: FarmTheme.spaceSm),
        decoration: FarmTheme.cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FarmMapThumbnail(farm: farm),
            Padding(
              padding: const EdgeInsets.all(FarmTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(farm.farmName, style: FarmTheme.cardTitle),
                  const SizedBox(height: FarmTheme.spaceXs),
                  Row(
                    children: [
                      const Icon(Icons.straighten,
                          size: 14, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(farm.areaLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      const SizedBox(width: FarmTheme.spaceMd),
                      const Icon(Icons.eco, size: 14, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        farm.satelliteData?.vegetationHealth ?? 'No data',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
