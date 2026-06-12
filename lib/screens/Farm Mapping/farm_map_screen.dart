// ============================================================
// lib/screens/Farm Management/farm_map_screen.dart
// CoffeeCore – Farm Map & GPS Boundary Mapping Screen
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:coffeecore/screens/Farm%20Mapping/climate_satellite_service.dart';
import 'package:coffeecore/screens/Farm%20Mapping/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Mapping/farm_polygon_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'farm_detail_screen.dart';

class FarmMapScreen extends StatefulWidget {
  const FarmMapScreen({super.key});

  @override
  State<FarmMapScreen> createState() => _FarmMapScreenState();
}

class _FarmMapScreenState extends State<FarmMapScreen>
    with TickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────
  final FarmMappingService _mappingService = FarmMappingService();
  final ClimateSatelliteService _climateService = ClimateSatelliteService();
  final Logger _log = Logger(printer: PrettyPrinter());

  // ── Map ─────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  MapType _mapType = MapType.hybrid;
  bool _isMapReady = false;
  bool _isMapCrash = false; // <-- NEW: catches missing JS API

  // ── GPS / mapping state ─────────────────────────────────────
  StreamSubscription<Position>? _positionStreamSub;
  Position? _currentPosition;
  double _gpsAccuracy = 0.0;
  bool _isMappingActive = false;
  bool _isAutoCapture = true;
  final List<LatLng> _boundaryPoints = [];
  double _accumulatedDistance = 0.0;
  Position? _lastCapturedPosition;
  static const double _captureThresholdMeters = 5.0;
  static const double _minPointsForPolygon = 3;

  // ── Computed metrics ─────────────────────────────────────────
  double _areaHectares = 0.0;
  double _perimeterMeters = 0.0;

  // ── Map overlays ─────────────────────────────────────────────
  Set<Polygon> _polygons = {};
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // ── Saved farms stream ────────────────────────────────────────
  StreamSubscription<List<FarmPolygon>>? _farmsStreamSub;
  List<FarmPolygon> _userFarms = [];
  FarmPolygon? _selectedViewFarm;
  bool _isLoadingFarms = true;

  // ── UI state ──────────────────────────────────────────────────
  bool _isSaving = false;
  bool _isPermissionGranted = false;
  bool _locationServicesEnabled = false;
  final TextEditingController _farmNameCtrl = TextEditingController();

  // ── Animation for mapping pulse indicator ────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Theme shorthand ──────────────────────────────────────────
  static const Color _primary = Color(0xFF6D4C41);
  static const Color _cardBg = Color(0xFFF1ECEA);
  static const Color _accent = Color(0xFF4CAF50);
  static const Color _accentStop = Color(0xFFE53935);

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _log.i('FarmMapScreen: initState – initialising');

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2)
        .animate(_pulseController);

    _checkLocationPermissions();
    _subscribeToFarms();
  }

  @override
  void dispose() {
    _log.i('FarmMapScreen: dispose – cancelling subscriptions');
    _positionStreamSub?.cancel();
    _farmsStreamSub?.cancel();
    _mapController?.dispose();
    _farmNameCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // PERMISSIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> _checkLocationPermissions() async {
    _log.i('FarmMapScreen: Checking location permissions');
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _log.w('FarmMapScreen: Location services disabled');
        if (mounted) {
          setState(() => _locationServicesEnabled = false);
          _showLocationServicesDialog();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _log.i('FarmMapScreen: Requesting location permission');
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _log.e('FarmMapScreen: Location permission denied forever');
        if (mounted) {
          setState(() {
            _isPermissionGranted = false;
            _locationServicesEnabled = true;
          });
          _showPermissionDeniedDialog();
        }
        return;
      }

      if (permission == LocationPermission.denied) {
        _log.w('FarmMapScreen: Location permission denied');
        if (mounted) setState(() => _isPermissionGranted = false);
        return;
      }

      _log.i('FarmMapScreen: Location permission granted');
      if (mounted) {
        setState(() {
          _isPermissionGranted = true;
          _locationServicesEnabled = true;
        });
        _startPositionStream();
        _moveCameraToCurrentLocation();
      }
    } catch (e, st) {
      _log.e(
        'FarmMapScreen: Error checking permissions – $e',
        stackTrace: st,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GPS STREAM
  // ─────────────────────────────────────────────────────────────

  void _startPositionStream() {
    _log.i('FarmMapScreen: Starting GPS position stream');
    _positionStreamSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _onPositionUpdate,
      onError: (Object e, StackTrace st) {
        _log.e('FarmMapScreen: GPS stream error – $e', stackTrace: st);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS error: $e'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      },
    );
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _gpsAccuracy = position.accuracy;
    });

    _updateCurrentPositionMarker(position);

    if (_isMappingActive && _isAutoCapture) {
      if (_lastCapturedPosition != null) {
        final dist = Geolocator.distanceBetween(
          _lastCapturedPosition!.latitude,
          _lastCapturedPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _accumulatedDistance += dist;
      }

      if (_lastCapturedPosition == null ||
          _accumulatedDistance >= _captureThresholdMeters) {
        _addBoundaryPoint(
          LatLng(position.latitude, position.longitude),
          fromStream: true,
        );
        _lastCapturedPosition = position;
        _accumulatedDistance = 0.0;
      }
    }

    _updateMapOverlays();
  }

  // ─────────────────────────────────────────────────────────────
  // BOUNDARY POINT MANAGEMENT
  // ─────────────────────────────────────────────────────────────

  void _addBoundaryPoint(LatLng point, {bool fromStream = false}) {
    setState(() {
      _boundaryPoints.add(point);
      _areaHectares = _shoelaceAreaHectares(_boundaryPoints);
      _perimeterMeters = _haversinePerimeterMeters(_boundaryPoints);
    });
    _log.i(
      'FarmMapScreen: Boundary point #${_boundaryPoints.length} added '
      '(${point.latitude.toStringAsFixed(6)}, '
      '${point.longitude.toStringAsFixed(6)}) '
      '${fromStream ? "[auto]" : "[manual]"} | '
      'Area: ${_areaHectares.toStringAsFixed(4)} ha',
    );
  }

  void _undoLastPoint() {
    if (_boundaryPoints.isEmpty) return;
    setState(() {
      _boundaryPoints.removeLast();
      _areaHectares = _shoelaceAreaHectares(_boundaryPoints);
      _perimeterMeters = _haversinePerimeterMeters(_boundaryPoints);
    });
    _updateMapOverlays();
    _log.i(
      'FarmMapScreen: Undid last boundary point. '
      'Remaining: ${_boundaryPoints.length}',
    );
  }

  void _clearAllPoints() {
    setState(() {
      _boundaryPoints.clear();
      _areaHectares = 0;
      _perimeterMeters = 0;
    });
    _updateMapOverlays();
    _log.i('FarmMapScreen: All boundary points cleared');
  }

  // ─────────────────────────────────────────────────────────────
  // MAPPING SESSION CONTROL
  // ─────────────────────────────────────────────────────────────

  void _startMapping() {
    if (!_isPermissionGranted) {
      _checkLocationPermissions();
      return;
    }
    _log.i('FarmMapScreen: Mapping session started');
    setState(() {
      _isMappingActive = true;
      _lastCapturedPosition = null;
      _accumulatedDistance = 0.0;
    });

    if (_currentPosition != null) {
      _addBoundaryPoint(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        fromStream: false,
      );
      _lastCapturedPosition = _currentPosition;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.gps_fixed, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Walk your farm boundary – GPS is capturing'),
          ],
        ),
        backgroundColor: _accent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _stopMapping() {
    _log.i(
      'FarmMapScreen: Mapping session stopped. '
      '${_boundaryPoints.length} points captured. '
      'Area: ${_areaHectares.toStringAsFixed(4)} ha',
    );
    setState(() => _isMappingActive = false);
    _updateMapOverlays();
  }

  // ─────────────────────────────────────────────────────────────
  // MAP OVERLAYS
  // ─────────────────────────────────────────────────────────────

  void _updateCurrentPositionMarker(Position pos) {
    if (!mounted) return;
    final posLatLng = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _markers = _markers
          .where((m) => m.markerId.value != 'current_position')
          .toSet();
      _markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: posLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: 'Accuracy: ±${pos.accuracy.toStringAsFixed(0)} m',
          ),
          zIndexInt: 10, 
        ),
      );
    });
  }

  void _updateMapOverlays() {
    if (!mounted) return;

    final newPolygons = <Polygon>{};
    final newPolylines = <Polyline>{};
    final newMarkers =
        _markers.where((m) => m.markerId.value == 'current_position').toSet();

    if (_boundaryPoints.isNotEmpty) {
      if (_boundaryPoints.length >= 3) {
        newPolygons.add(
          Polygon(
            polygonId: const PolygonId('active_boundary'),
            points: _boundaryPoints,
            fillColor: _accent.withValues(alpha: 0.18),
            strokeColor: _accent,
            strokeWidth: 2,
          ),
        );
      } else {
        newPolylines.add(
          Polyline(
            polylineId: const PolylineId('boundary_preview'),
            points: _boundaryPoints,
            color: _accent,
            width: 3,
          ),
        );
      }

      if (_isMappingActive &&
          _currentPosition != null &&
          _boundaryPoints.isNotEmpty) {
        newPolylines.add(
          Polyline(
            polylineId: const PolylineId('live_preview'),
            points: [
              _boundaryPoints.last,
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            ],
            color: Colors.amber,
            width: 2,
            patterns: [PatternItem.dash(12), PatternItem.gap(6)],
          ),
        );
      }

      if (_boundaryPoints.length <= 50) {
        for (int i = 0; i < _boundaryPoints.length; i++) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('boundary_pt_$i'),
              position: _boundaryPoints[i],
              icon: BitmapDescriptor.defaultMarkerWithHue(
                i == 0
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueCyan,
              ),
              flat: true,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(
                title: i == 0 ? 'Start Point' : 'Point ${i + 1}',
                snippet: '${_boundaryPoints[i].latitude.toStringAsFixed(5)}, '
                    '${_boundaryPoints[i].longitude.toStringAsFixed(5)}',
              ),
              zIndexInt: 5,
            ),
          );
        }
      }
    }

    for (final farm in _userFarms) {
      if (farm.coordinates.length >= 3) {
        final isSelected = _selectedViewFarm?.farmId == farm.farmId;
        newPolygons.add(
          Polygon(
            polygonId: PolygonId('saved_${farm.farmId}'),
            points: farm.coordinates,
            fillColor: isSelected
                ? _primary.withValues(alpha: 0.30)
                : _primary.withValues(alpha: 0.12),
            strokeColor: isSelected ? _primary : _primary.withValues(alpha: 0.6),
            strokeWidth: isSelected ? 3 : 2,
            consumeTapEvents: true,
            onTap: () => _onSavedFarmTap(farm),
          ),
        );
        newMarkers.add(
          Marker(
            markerId: MarkerId('farm_label_${farm.farmId}'),
            position: farm.center,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: farm.farmName,
              snippet: farm.areaLabel,
              onTap: () => _navigateToFarmDetail(farm),
            ),
            zIndexInt: 8, 
          ),
        );
      }
    }

    setState(() {
      _polygons = newPolygons;
      _polylines = newPolylines;
      _markers = newMarkers;
    });
  }

  void _onSavedFarmTap(FarmPolygon farm) {
    _log.i('FarmMapScreen: Tapped saved farm "${farm.farmName}"');
    setState(() => _selectedViewFarm = farm);
    _updateMapOverlays();
    _zoomToFarm(farm);
    _showFarmQuickInfoSheet(farm);
  }

  void _zoomToFarm(FarmPolygon farm) {
    if (!_isMapReady || farm.coordinates.isEmpty) return;
    final bounds = _latLngBounds(farm.coordinates);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60.0),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SAVE FARM
  // ─────────────────────────────────────────────────────────────

  Future<void> _showSaveFarmDialog() async {
    if (_boundaryPoints.length < _minPointsForPolygon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 3 boundary points to save a farm.'),
        ),
      );
      return;
    }

    _farmNameCtrl.text =
        'Farm ${DateFormat('dd MMM yyyy').format(DateTime.now())}';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(Icons.terrain, color: Colors.brown[700]),
            const SizedBox(width: 8),
            const Text('Save Farm'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _farmNameCtrl,
              decoration: InputDecoration(
                labelText: 'Farm Name',
                hintText: 'e.g., Arabica Block A',
                prefixIcon:
                    Icon(Icons.edit, color: Colors.brown[700], size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.brown[700]!, width: 2),
                ),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.straighten, 'Boundary Points',
                '${_boundaryPoints.length}'),
            _buildInfoRow(Icons.crop_square, 'Area',
                _areaHecatraresLabel(_areaHectares)),
            _buildInfoRow(Icons.linear_scale, 'Perimeter',
                _perimeterLabel(_perimeterMeters)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _saveFarm();
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save Farm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFarm() async {
    final name = _farmNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a farm name.')),
      );
      return;
    }
    if (_boundaryPoints.length < _minPointsForPolygon) return;

    setState(() => _isSaving = true);
    _log.i(
      'FarmMapScreen: Saving farm "$name" with '
      '${_boundaryPoints.length} points, '
      'area=${_areaHectares.toStringAsFixed(4)} ha',
    );

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();

      final farm = FarmPolygon(
        userId: uid,
        farmName: name,
        coordinates: List<LatLng>.from(_boundaryPoints),
        areaHectares: _areaHectares,
        perimeterMeters: _perimeterMeters,
        createdAt: now,
        updatedAt: now,
      );

      final farmId = await _mappingService.saveFarm(farm);
      _log.i('FarmMapScreen: Farm saved with ID $farmId');

      if (farmId != null) {
        _registerAgroPolygonAsync(
          farmId: farmId,
          farmName: name,
          points: _boundaryPoints,
        );

        _fetchAndAttachClimateData(
          farmId: farmId,
          lat: farm.center.latitude,
          lng: farm.center.longitude,
        );
      }

      if (mounted) {
        setState(() {
          _isMappingActive = false;
          _boundaryPoints.clear();
          _areaHectares = 0;
          _perimeterMeters = 0;
          _lastCapturedPosition = null;
          _accumulatedDistance = 0;
          _isSaving = false;
        });
        _updateMapOverlays();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('"$name" saved successfully!'),
              ],
            ),
            backgroundColor: _accent,
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                if (_userFarms.isNotEmpty) {
                  _navigateToFarmDetail(_userFarms.first);
                }
              },
            ),
          ),
        );
      }
    } catch (e, st) {
      _log.e('FarmMapScreen: Error saving farm – $e', stackTrace: st);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving farm: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BACKGROUND TASKS (non-blocking)
  // ─────────────────────────────────────────────────────────────

  Future<void> _registerAgroPolygonAsync({
    required String farmId,
    required String farmName,
    required List<LatLng> points,
  }) async {
    try {
      final coords = points
          .map((p) => [p.longitude, p.latitude])
          .toList();
      final polyId = await _climateService.registerAgroPolygon(
        farmName: farmName,
        coordinates: coords,
      );
      if (polyId != null) {
        await _mappingService.setAgroMonitoringPolyId(farmId, polyId);
        _log.i(
          'FarmMapScreen._registerAgroPolygonAsync: '
          'Registered farm $farmId → AgroMonitoring polyId=$polyId',
        );
        _fetchAndAttachNdviData(farmId: farmId, agroPolyId: polyId);
      }
    } catch (e, st) {
      _log.e(
        'FarmMapScreen._registerAgroPolygonAsync: Error – $e',
        stackTrace: st,
      );
    }
  }

  Future<void> _fetchAndAttachClimateData({
    required String farmId,
    required double lat,
    required double lng,
  }) async {
    try {
      final climate =
          await _climateService.fetchCurrentClimate(lat: lat, lng: lng);
      if (climate != null) {
        await _mappingService.updateClimateData(farmId, climate);
        _log.i(
          'FarmMapScreen._fetchAndAttachClimateData: '
          'Climate data attached to farm $farmId',
        );
      }
    } catch (e, st) {
      _log.e(
        'FarmMapScreen._fetchAndAttachClimateData: Error – $e',
        stackTrace: st,
      );
    }
  }

  Future<void> _fetchAndAttachNdviData({
    required String farmId,
    required String agroPolyId,
  }) async {
    try {
      final satellite = await _climateService.fetchLatestNdvi(
        agroPolyId: agroPolyId,
      );
      if (satellite != null) {
        await _mappingService.updateSatelliteData(farmId, satellite);
        _log.i(
          'FarmMapScreen._fetchAndAttachNdviData: '
          'Satellite data attached to farm $farmId',
        );
      }
    } catch (e, st) {
      _log.e(
        'FarmMapScreen._fetchAndAttachNdviData: Error – $e',
        stackTrace: st,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FARMS STREAM
  // ─────────────────────────────────────────────────────────────

  void _subscribeToFarms() {
    _log.i('FarmMapScreen: Subscribing to user farms stream');
    _farmsStreamSub = _mappingService.userFarmsStream().listen(
      (farms) {
        if (mounted) {
          _log.i(
            'FarmMapScreen: Received ${farms.length} saved farm(s)',
          );
          setState(() {
            _userFarms = farms;
            _isLoadingFarms = false;
          });
          _updateMapOverlays();
        }
      },
      onError: (Object e, StackTrace st) {
        _log.e(
          'FarmMapScreen: Farms stream error – $e',
          stackTrace: st,
        );
        if (mounted) setState(() => _isLoadingFarms = false);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────

  void _navigateToFarmDetail(FarmPolygon farm) {
    _log.i(
      'FarmMapScreen: Navigating to FarmDetailScreen for '
      '"${farm.farmName}" (${farm.farmId})',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FarmDetailScreen(farm: farm),
      ),
    );
  }

  void _moveCameraToCurrentLocation() async {
    if (!_isMapReady) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 17.0,
          ),
        ),
      );
      _log.i(
        'FarmMapScreen: Camera moved to current location '
        '(${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})',
      );
    } catch (e) {
      _log.w('FarmMapScreen: Could not get current location – $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DIALOGS / SHEETS
  // ─────────────────────────────────────────────────────────────

  void _showLocationServicesDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'CoffeeCore needs GPS to map your farm boundary. '
          'Please enable location services in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'CoffeeCore requires location permission to capture GPS '
          'coordinates as you walk your farm boundary. '
          'Please grant permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }

  void _showFarmsListSheet() {
    _log.i(
      'FarmMapScreen: Opening farms list sheet '
      '(${_userFarms.length} farms)',
    );
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => _buildFarmsListSheetContent(scrollCtrl),
      ),
    );
  }

  void _showFarmQuickInfoSheet(FarmPolygon farm) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terrain, color: Colors.brown[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    farm.farmName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown[800],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow(
                Icons.crop_square, 'Area', farm.areaLabel),
            _buildInfoRow(
                Icons.linear_scale, 'Perimeter', farm.perimeterLabel),
            _buildInfoRow(
              Icons.calendar_today,
              'Mapped',
              DateFormat('dd MMM yyyy').format(farm.createdAt),
            ),
            if (farm.climateData != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.thermostat,
                'Temperature',
                '${farm.climateData!.temperatureCelsius.toStringAsFixed(1)}°C',
              ),
            ],
            if (farm.satelliteData != null) ...[
              _buildInfoRow(
                Icons.satellite_alt,
                'Vegetation',
                '${farm.satelliteData!.vegetationHealth} '
                    '(NDVI: ${farm.satelliteData!.ndviScore.toStringAsFixed(2)})',
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showDeleteConfirmDialog(farm);
                    },
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 18),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _navigateToFarmDetail(farm);
                    },
                    icon: const Icon(Icons.analytics, size: 18),
                    label: const Text('Full Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmDialog(FarmPolygon farm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Farm?'),
        content: Text(
          'Are you sure you want to delete "${farm.farmName}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && farm.farmId != null) {
      try {
        _log.i(
          'FarmMapScreen: Deleting farm "${farm.farmName}" (${farm.farmId})',
        );
        await _mappingService.deleteFarm(farm.farmId!);
        if (mounted) {
          setState(() {
            if (_selectedViewFarm?.farmId == farm.farmId) {
              _selectedViewFarm = null;
            }
          });
          _updateMapOverlays();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${farm.farmName}" deleted'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      } catch (e, st) {
        _log.e('FarmMapScreen: Error deleting farm – $e', stackTrace: st);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting farm: $e'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GEOMETRY CALCULATIONS
  // ─────────────────────────────────────────────────────────────

  double _shoelaceAreaHectares(List<LatLng> pts) {
    if (pts.length < 3) return 0.0;
    const R = 6371000.0;
    double area = 0.0;
    final n = pts.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final xi = pts[i].longitude *
          (math.pi / 180) *
          R *
          math.cos(pts[i].latitude * math.pi / 180);
      final yi = pts[i].latitude * (math.pi / 180) * R;
      final xj = pts[j].longitude *
          (math.pi / 180) *
          R *
          math.cos(pts[j].latitude * math.pi / 180);
      final yj = pts[j].latitude * (math.pi / 180) * R;
      area += xi * yj - xj * yi;
    }
    return (area.abs() / 2) / 10000;
  }

  double _haversinePerimeterMeters(List<LatLng> pts) {
    if (pts.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      total += _haversineDistance(pts[i], pts[i + 1]);
    }
    total += _haversineDistance(pts.last, pts.first);
    return total;
  }

  double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final aVal = sinDLat * sinDLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinDLng *
            sinDLng;
    return R * 2 * math.atan2(math.sqrt(aVal), math.sqrt(1 - aVal));
  }

  LatLngBounds _latLngBounds(List<LatLng> pts) {
    final lats = pts.map((p) => p.latitude);
    final lngs = pts.map((p) => p.longitude);
    return LatLngBounds(
      southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LABEL HELPERS
  // ─────────────────────────────────────────────────────────────

  String _areaHecatraresLabel(double ha) {
    if (ha >= 1.0) return '${ha.toStringAsFixed(2)} ha';
    return '${(ha * 10000).toStringAsFixed(0)} m²';
  }

  String _perimeterLabel(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(2)} km';
    return '${m.toStringAsFixed(0)} m';
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildGoogleMap(),
          _buildGpsStatusOverlay(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControlPanel(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_locate',
            onPressed: _moveCameraToCurrentLocation,
            backgroundColor: Colors.white,
            foregroundColor: Colors.brown[700],
            tooltip: 'My Location',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'fab_maptype',
            onPressed: () {
              setState(() {
                _mapType = _mapType == MapType.hybrid
                    ? MapType.normal
                    : MapType.hybrid;
              });
              _log.i(
                'FarmMapScreen: Map type toggled to '
                '${_mapType == MapType.hybrid ? "Hybrid/Satellite" : "Normal"}',
              );
            },
            backgroundColor: Colors.white,
            foregroundColor: Colors.brown[700],
            tooltip: 'Toggle Satellite View',
            child: Icon(
              _mapType == MapType.hybrid
                  ? Icons.map_outlined
                  : Icons.satellite_alt,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ── AppBar ──────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.brown[700],
      foregroundColor: Colors.white,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Farm Map',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          Text(
            'GPS Boundary Mapping',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.list, color: Colors.white),
          tooltip: 'My Farms',
          onPressed: _showFarmsListSheet,
        ),
      ],
    );
  }

  // ── Google Map ──────────────────────────────────────────────
  Widget _buildGoogleMap() {
    // WEB SAFETY: If the JS API failed to load, show a placeholder instead
    // of letting the platform view crash the whole tree.
    if (_isMapCrash) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Google Maps failed to load.\n'
                'Ensure Maps JavaScript API is enabled\n'
                'and the script is in web/index.html',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return GoogleMap(
      mapType: _mapType,
      initialCameraPosition: _currentPosition != null
          ? CameraPosition(
              target: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              zoom: 17.0,
            )
          : const CameraPosition(
              target: LatLng(-1.2921, 36.8219),
              zoom: 14.0,
            ),
      onMapCreated: (ctrl) {
        try {
          _mapController = ctrl;
          setState(() => _isMapReady = true);
          _log.i('FarmMapScreen: GoogleMap controller ready');
          if (_currentPosition != null) {
            _moveCameraToCurrentLocation();
          }
          _updateMapOverlays();
        } catch (e, st) {
          _log.e('FarmMapScreen: onMapCreated error – $e', stackTrace: st);
          if (mounted) setState(() => _isMapCrash = true);
        }
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      polygons: _polygons,
      polylines: _polylines,
      markers: _markers,
      onTap: (latLng) {
        if (_isMappingActive && !_isAutoCapture) {
          _addBoundaryPoint(latLng);
          _updateMapOverlays();
        }
        if (_selectedViewFarm != null) {
          setState(() => _selectedViewFarm = null);
          _updateMapOverlays();
        }
      },
      onLongPress: (latLng) {
        if (_isMappingActive) {
          _log.i(
            'FarmMapScreen: Manual long-press point at '
            '${latLng.latitude.toStringAsFixed(5)}, '
            '${latLng.longitude.toStringAsFixed(5)}',
          );
          _addBoundaryPoint(latLng);
          _updateMapOverlays();
        }
      },
    );
  }

  // ── GPS Status Overlay (top-centre) ────────────────────────
  Widget _buildGpsStatusOverlay() {
    if (_currentPosition == null) {
      return Positioned(
        top: 12,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Text('Acquiring GPS…',
                    style:
                        TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _isMappingActive
                ? _accent.withValues(alpha: 0.88)
                : Colors.black.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isMappingActive)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  ),
                  child: const Icon(Icons.fiber_manual_record,
                      color: Colors.white, size: 10),
                )
              else
                const Icon(Icons.gps_fixed, color: Colors.white, size: 12),
              const SizedBox(width: 6),
              Text(
                _isMappingActive
                    ? 'MAPPING  ±${_gpsAccuracy.toStringAsFixed(0)} m'
                    : 'GPS ±${_gpsAccuracy.toStringAsFixed(0)} m',
                style:
                    const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Control Panel (bottom card) ─────────────────────────────
  Widget _buildControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade500.withAlpha(128),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildStatChip(
                icon: Icons.push_pin,
                label: 'Points',
                value: '${_boundaryPoints.length}',
                color: _isMappingActive ? _accent : Colors.grey[600]!,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                icon: Icons.crop_square,
                label: 'Area',
                value: _areaHecatraresLabel(_areaHectares),
                color: Colors.brown[700]!,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                icon: Icons.linear_scale,
                label: 'Perimeter',
                value: _perimeterLabel(_perimeterMeters),
                color: Colors.brown[600]!,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isMappingActive) ...[
            Row(
              children: [
                Switch(
                  value: _isAutoCapture,
                  onChanged: (val) {
                    setState(() => _isAutoCapture = val);
                    _log.i(
                      'FarmMapScreen: Auto-capture '
                      '${val ? "enabled" : "disabled"}',
                    );
                  },
                  activeThumbColor: _accent,
                ),
                const SizedBox(width: 6),
                Text(
                  _isAutoCapture
                      ? 'Auto-capture every 5 m'
                      : 'Tap map / long-press to add points',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          if (!_isMappingActive) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !_locationServicesEnabled
                    ? _showLocationServicesDialog
                    : _isPermissionGranted
                        ? _startMapping
                        : _checkLocationPermissions,
                icon: Icon(
                  !_locationServicesEnabled
                      ? Icons.location_disabled
                      : Icons.gps_fixed,
                  size: 20,
                ),
                label: Text(
                  !_locationServicesEnabled
                      ? 'ENABLE LOCATION SERVICES'
                      : _isPermissionGranted
                          ? 'START MAPPING'
                          : 'GRANT LOCATION PERMISSION',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      !_locationServicesEnabled ? Colors.grey[600] : _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentPosition != null
                        ? () {
                            _addBoundaryPoint(LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ));
                            _updateMapOverlays();
                          }
                        : null,
                    icon: const Icon(Icons.add_location, size: 18),
                    label: const Text('ADD POINT',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: BorderSide(color: _accent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _boundaryPoints.isNotEmpty ? _undoLastPoint : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                    side: BorderSide(color: Colors.orange[700]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                  child: const Icon(Icons.undo, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopMapping,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('STOP',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentStop,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _clearAllPoints,
                    icon: Icon(Icons.clear_all,
                        size: 18, color: Colors.grey[600]),
                    label: Text('Clear All',
                        style: TextStyle(color: Colors.grey[600])),
                  ),
                ),
                if (_boundaryPoints.length >= _minPointsForPolygon) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _showSaveFarmDialog,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, size: 18),
                      label: Text(
                        _isSaving ? 'Saving…' : 'SAVE FARM',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Farms list bottom-sheet content ────────────────────────
  Widget _buildFarmsListSheetContent(ScrollController scrollCtrl) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.terrain, color: Colors.brown[700], size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'My Coffee Farms',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.brown[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_userFarms.length} farm(s)',
                        style: TextStyle(
                            fontSize: 12, color: Colors.brown[700]),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingFarms
                ? Center(
                    child: CircularProgressIndicator(
                        color: Colors.brown[700]))
                : _userFarms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.terrain_outlined,
                                size: 56, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No farms mapped yet',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap START MAPPING to capture your\nfarm boundary.',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _userFarms.length,
                        itemBuilder: (_, i) =>
                            _buildFarmListTile(_userFarms[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmListTile(FarmPolygon farm) {
    final isSelected = _selectedViewFarm?.farmId == farm.farmId;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected ? Colors.brown[50] : Colors.white,
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? BorderSide(color: Colors.brown[700]!, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Colors.brown[100],
          child: Icon(Icons.terrain, color: Colors.brown[700], size: 22),
        ),
        title: Text(
          farm.farmName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${farm.areaLabel}  •  ${farm.coordinates.length} pts',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (farm.satelliteData != null)
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: farm.satelliteData!.healthColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '● ${farm.satelliteData!.vegetationHealth}',
                      style: TextStyle(
                        fontSize: 11,
                        color: farm.satelliteData!.healthColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.map_outlined, color: Colors.brown[700], size: 20),
              tooltip: 'View on map',
              onPressed: () {
                Navigator.pop(context);
                _onSavedFarmTap(farm);
              },
            ),
            IconButton(
              icon:
                  const Icon(Icons.analytics_outlined, color: Colors.teal, size: 20),
              tooltip: 'Farm data',
              onPressed: () {
                Navigator.pop(context);
                _navigateToFarmDetail(farm);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Small reusable widgets ──────────────────────────────────
  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade500.withAlpha(80),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style:
                  TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.brown[600]),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}