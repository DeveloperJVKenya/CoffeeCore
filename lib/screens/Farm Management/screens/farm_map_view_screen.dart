import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';

/// Full-screen, fully interactive view of a saved farm's mapped boundary:
/// pinch/scroll to zoom, drag to pan, and toggle between map types. Reached
/// by tapping the map card on the Overview tab.
class FarmMapViewScreen extends StatefulWidget {
  final FarmPolygon farm;

  const FarmMapViewScreen({super.key, required this.farm});

  @override
  State<FarmMapViewScreen> createState() => _FarmMapViewScreenState();
}

class _FarmMapViewScreenState extends State<FarmMapViewScreen> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.hybrid;

  void _cycleMapType() {
    setState(() {
      _mapType = switch (_mapType) {
        MapType.hybrid => MapType.normal,
        MapType.normal => MapType.satellite,
        _ => MapType.hybrid,
      };
    });
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final LatLng p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _fitToBoundary() {
    final GoogleMapController? controller = _controller;
    final List<LatLng> points = widget.farm.coordinates;
    if (controller == null || points.length < 2) return;
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFor(points), 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FarmPolygon farm = widget.farm;

    final Set<Marker> markers = <Marker>{
      for (int i = 0; i < farm.coordinates.length; i++)
        Marker(
          markerId: MarkerId('point_$i'),
          position: farm.coordinates[i],
          anchor: const Offset(0.5, 0.5),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueCyan,
          ),
        ),
    };

    final Set<Polygon> polygons = <Polygon>{
      if (farm.coordinates.length >= 3)
        Polygon(
          polygonId: PolygonId(farm.farmId ?? farm.farmName),
          points: farm.coordinates,
          fillColor: FarmTheme.secondaryGreen.withValues(alpha: 0.2),
          strokeColor: FarmTheme.secondaryGreen,
          strokeWidth: 3,
          geodesic: true,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(farm.farmName, style: FarmTheme.screenTitle),
        backgroundColor: FarmTheme.primaryBrown,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.layers),
            tooltip: 'Change map type',
            onPressed: _cycleMapType,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Fit boundary',
            onPressed: _fitToBoundary,
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          GoogleMap(
            mapType: _mapType,
            initialCameraPosition:
                CameraPosition(target: farm.center, zoom: 16),
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _fitToBoundary());
            },
            markers: markers,
            polygons: polygons,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: true,
            compassEnabled: true,
          ),
          Positioned(
            left: FarmTheme.spaceMd,
            right: FarmTheme.spaceMd,
            bottom: FarmTheme.spaceMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: FarmTheme.spaceMd,
                vertical: FarmTheme.spaceSm,
              ),
              decoration: FarmTheme.cardDecoration(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Text('Area: ${farm.areaLabel}', style: FarmTheme.statLabel),
                  Text('Perimeter: ${farm.perimeterLabel}',
                      style: FarmTheme.statLabel),
                  Text('Points: ${farm.coordinates.length}',
                      style: FarmTheme.statLabel),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
