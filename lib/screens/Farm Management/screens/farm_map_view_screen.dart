import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/sentinel_hub_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/metric_gradient_legend.dart';

class FarmMapViewScreen extends StatefulWidget {
  final FarmPolygon farm;

  const FarmMapViewScreen({super.key, required this.farm});

  @override
  State<FarmMapViewScreen> createState() => _FarmMapViewScreenState();
}

class _FarmMapViewScreenState extends State<FarmMapViewScreen> {
  final SentinelHubService _sentinelHubService = SentinelHubService();

  GoogleMapController? _controller;
  MapType _mapType = MapType.hybrid;
  MapMetric? _metric;
  RasterOverlayData? _raster;
  bool _isLoadingRaster = false;
  String? _rasterError;
  int _rasterRequestId = 0;

  void _cycleMapType() {
    setState(() {
      _mapType = switch (_mapType) {
        MapType.hybrid => MapType.normal,
        MapType.normal => MapType.satellite,
        _ => MapType.hybrid,
      };
    });
  }

  Future<void> _onMetricSelected(MapMetric? metric) async {
    final int requestId = ++_rasterRequestId;
    setState(() {
      _metric = metric;
      _raster = null;
      _rasterError = null;
    });
    if (metric == null) return;

    setState(() => _isLoadingRaster = true);
    try {
      final raster = await _sentinelHubService.fetchColorizedRaster(
        coordinates: widget.farm.coordinates,
        metric: metric == MapMetric.ndvi ? 'ndvi' : 'ndwi',
      );
      if (!mounted || requestId != _rasterRequestId) return;
      setState(() => _raster = raster);
    } on ServiceUnavailableException catch (e) {
      if (!mounted || requestId != _rasterRequestId) return;
      setState(() => _rasterError = e.userMessage);
    } catch (e) {
      if (!mounted || requestId != _rasterRequestId) return;
      setState(() =>
          _rasterError = 'Something went wrong rendering the map overlay.');
    } finally {
      if (mounted && requestId == _rasterRequestId) {
        setState(() => _isLoadingRaster = false);
      }
    }
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

    final double? ndvi = farm.satelliteData?.ndviScore;
    final double? ndwi = farm.satelliteData?.ndwiScore;
    final bool overlayActive = _metric != null && _raster != null;
    // Once the colorized raster is showing, the polygon itself only needs a
    // boundary outline (the raster already carries the per-pixel color and
    // is clipped to the farm shape) — filling it too would just wash out
    // the raster underneath.
    final Color boundaryColor =
        overlayActive ? Colors.white : FarmTheme.secondaryGreen;

    final Set<Polygon> polygons = <Polygon>{
      if (farm.coordinates.length >= 3)
        Polygon(
          polygonId: PolygonId(farm.farmId ?? farm.farmName),
          points: farm.coordinates,
          fillColor: overlayActive
              ? Colors.transparent
              : FarmTheme.secondaryGreen.withValues(alpha: 0.2),
          strokeColor: boundaryColor,
          strokeWidth: 3,
          geodesic: true,
        ),
    };

    final Set<GroundOverlay> groundOverlays = <GroundOverlay>{
      if (_raster != null)
        GroundOverlay.fromBounds(
          groundOverlayId: const GroundOverlayId('metric_raster'),
          image: BytesMapBitmap(
            _raster!.pngBytes,
            bitmapScaling: MapBitmapScaling.none,
          ),
          bounds: _raster!.bounds,
          transparency: 0.05,
        ),
    };

    final double? legendValue = _metric == MapMetric.ndvi
        ? ndvi
        : _metric == MapMetric.ndwi
            ? ndwi
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(farm.farmName, style: FarmTheme.screenTitle),
        backgroundColor: FarmTheme.primaryBrown,
        foregroundColor: Colors.white,
        actions: <Widget>[
          PopupMenuButton<MapMetric?>(
            icon: const Icon(Icons.gradient),
            tooltip: 'NDVI/NDWI color overlay',
            initialValue: _metric,
            onSelected: _onMetricSelected,
            itemBuilder: (context) => <PopupMenuEntry<MapMetric?>>[
              const PopupMenuItem(value: null, child: Text('No overlay')),
              const PopupMenuItem(
                value: MapMetric.ndvi,
                child: Text('NDVI (vegetation)'),
              ),
              const PopupMenuItem(
                value: MapMetric.ndwi,
                child: Text('NDWI (moisture)'),
              ),
            ],
          ),
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
            groundOverlays: groundOverlays,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: true,
            compassEnabled: true,
          ),
          if (_isLoadingRaster)
            Positioned(
              top: FarmTheme.spaceMd,
              left: FarmTheme.spaceMd,
              right: FarmTheme.spaceMd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FarmTheme.spaceMd,
                  vertical: FarmTheme.spaceSm,
                ),
                decoration: FarmTheme.cardDecoration(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: FarmTheme.spaceSm),
                    Text('Rendering satellite overlay…',
                        style: FarmTheme.statLabel),
                  ],
                ),
              ),
            ),
          if (_rasterError != null)
            Positioned(
              top: FarmTheme.spaceMd,
              left: FarmTheme.spaceMd,
              right: FarmTheme.spaceMd,
              child: Container(
                padding: const EdgeInsets.all(FarmTheme.spaceSm),
                decoration: FarmTheme.cardDecoration(color: Colors.red[50]),
                child: Text(
                  _rasterError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ),
          Positioned(
            left: FarmTheme.spaceMd,
            right: FarmTheme.spaceMd,
            bottom: FarmTheme.spaceMd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_metric != null) ...[
                  MetricGradientLegend(
                    metric: _metric!,
                    currentValue: legendValue,
                  ),
                  const SizedBox(height: FarmTheme.spaceSm),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FarmTheme.spaceMd,
                    vertical: FarmTheme.spaceSm,
                  ),
                  decoration: FarmTheme.cardDecoration(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      Text('Area: ${farm.areaLabel}',
                          style: FarmTheme.statLabel),
                      Text('Perimeter: ${farm.perimeterLabel}',
                          style: FarmTheme.statLabel),
                      Text('Points: ${farm.coordinates.length}',
                          style: FarmTheme.statLabel),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
