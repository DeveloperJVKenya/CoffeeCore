import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Small non-interactive Google Map preview of a farm's boundary polygon,
/// used inside [FarmCard] and the overview tab.
class FarmMapThumbnail extends StatelessWidget {
  final FarmPolygon farm;
  final double height;

  const FarmMapThumbnail({super.key, required this.farm, this.height = 140});

  @override
  Widget build(BuildContext context) {
    if (farm.coordinates.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: FarmTheme.cardBackground,
          borderRadius: BorderRadius.circular(FarmTheme.radiusCard),
        ),
        child: const Center(
            child: Icon(Icons.map_outlined, color: Colors.black38)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(FarmTheme.radiusCard),
      child: SizedBox(
        height: height,
        child: IgnorePointer(
          child: GoogleMap(
            initialCameraPosition:
                CameraPosition(target: farm.center, zoom: 15),
            liteModeEnabled: true,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            polygons: {
              Polygon(
                polygonId: PolygonId(farm.farmId ?? farm.farmName),
                points: farm.coordinates,
                strokeColor: FarmTheme.secondaryGreen,
                strokeWidth: 2,
                fillColor: FarmTheme.secondaryGreen.withValues(alpha: 0.25),
              ),
            },
          ),
        ),
      ),
    );
  }
}
