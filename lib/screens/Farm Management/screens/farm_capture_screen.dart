import 'dart:async';
import 'dart:math' as math;

import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

/// GPS boundary capture screen. Walk the perimeter of a farm and tap
/// "Add Point" at each corner (or long-press the map) to build a polygon,
/// then save it as a new [FarmPolygon].
class FarmCaptureScreen extends StatefulWidget {
  const FarmCaptureScreen({super.key});

  @override
  State<FarmCaptureScreen> createState() => _FarmCaptureScreenState();
}

class _FarmCaptureScreenState extends State<FarmCaptureScreen> {
  static final Logger _logger = Logger(printer: PrettyPrinter());
  static const double _earthRadiusMeters = 6371000.0;
  // Kept small so tightly-spaced corners on sub-hectare plots aren't
  // rejected as duplicates, while still filtering GPS noise from a single
  // stationary reading.
  static const double _minPointSpacingMeters = 0.5;
  // Wide enough to cover a single boundary side on a farm of thousands of
  // hectares (e.g. a 2,000 ha square farm has ~4.5km sides) while still
  // catching obviously erroneous GPS teleports (a bad fix jumping tens of
  // kilometers away).
  static const double _maxJumpMeters = 20000.0;
  static const int _minPointsForPolygon = 3;
  static const LatLng _defaultCenter = LatLng(-1.2921, 36.8219); // Nairobi

  final FarmMappingService _mappingService = FarmMappingService();
  final TextEditingController _farmNameCtrl = TextEditingController();

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStreamSub;

  final List<LatLng> _boundaryPoints = <LatLng>[];
  Position? _currentPosition;

  bool _isPermissionGranted = false;
  bool _locationServicesEnabled = true;
  bool _isMappingActive = false;
  bool _isAddingPoint = false;
  bool _isFetchingPosition = false;
  bool _isSaving = false;
  bool _isCheckingPermission = true;
  String? _permissionError;

  double _areaHectares = 0;
  double _perimeterMeters = 0;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _farmNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermissions() async {
    setState(() {
      _isCheckingPermission = true;
      _permissionError = null;
    });

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _locationServicesEnabled = false;
        _isCheckingPermission = false;
        _permissionError = 'Location services are turned off on this device.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isPermissionGranted = false;
        _locationServicesEnabled = true;
        _isCheckingPermission = false;
        _permissionError =
            'Location permission was permanently denied. Please enable it '
            'from app settings to map a farm.';
      });
      return;
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        _isPermissionGranted = false;
        _isCheckingPermission = false;
        _permissionError = 'Location permission is required to map a farm.';
      });
      return;
    }

    setState(() {
      _isPermissionGranted = true;
      _locationServicesEnabled = true;
      _isCheckingPermission = false;
    });
    _startPositionStream();
  }

  void _startPositionStream() {
    _positionStreamSub?.cancel();
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      _onPositionUpdate,
      onError: (Object e, StackTrace st) {
        _logger.e('Position stream error', error: e, stackTrace: st);
      },
    );
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    final bool firstFix = _currentPosition == null;
    setState(() => _currentPosition = position);
    if (firstFix) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          17,
        ),
      );
    }
  }

  // ── Boundary point math ──────────────────────────────────────

  double _haversineDistance(LatLng a, LatLng b) {
    final double dLat = (b.latitude - a.latitude) * math.pi / 180;
    final double dLng = (b.longitude - a.longitude) * math.pi / 180;
    final double sinDLat = math.sin(dLat / 2);
    final double sinDLng = math.sin(dLng / 2);
    final double aVal = sinDLat * sinDLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinDLng *
            sinDLng;
    return _earthRadiusMeters *
        2 *
        math.atan2(
          math.sqrt(aVal),
          math.sqrt(1 - aVal),
        );
  }

  double _shoelaceAreaHectares(List<LatLng> pts) {
    if (pts.length < 3) return 0.0;
    double area = 0.0;
    final int n = pts.length;
    for (int i = 0; i < n; i++) {
      final int j = (i + 1) % n;
      final double xi = pts[i].longitude *
          (math.pi / 180) *
          _earthRadiusMeters *
          math.cos(pts[i].latitude * math.pi / 180);
      final double yi = pts[i].latitude * (math.pi / 180) * _earthRadiusMeters;
      final double xj = pts[j].longitude *
          (math.pi / 180) *
          _earthRadiusMeters *
          math.cos(pts[j].latitude * math.pi / 180);
      final double yj = pts[j].latitude * (math.pi / 180) * _earthRadiusMeters;
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

  /// Mirrors [FarmPolygon.areaLabel]: sub-hectare plots read far more
  /// clearly in m² than as "0.00 ha" or "0.01 ha".
  String _areaLabel(double hectares) {
    if (hectares >= 1.0) return '${hectares.toStringAsFixed(2)} ha';
    return '${(hectares * 10000).toStringAsFixed(0)} m²';
  }

  /// Mirrors [FarmPolygon.perimeterLabel]: keeps large-farm perimeters
  /// readable in km instead of a long raw meter count.
  String _perimeterLabel(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  /// Attempts to add [point] to the boundary. Returns null on success, or a
  /// reason the point was rejected so the caller can surface it to the user
  /// — previously these rejections were silent, which made the UI look
  /// "stuck" on the second point whenever the fresh reading was too close
  /// to (or too far from) the last accepted one.
  _PointRejection? _addBoundaryPoint(LatLng point) {
    if (_isAddingPoint) return null;
    _isAddingPoint = true;
    try {
      if (_boundaryPoints.isNotEmpty) {
        final LatLng last = _boundaryPoints.last;
        final double dist = _haversineDistance(last, point);
        if (dist < _minPointSpacingMeters) {
          _logger.w('Point rejected (too close): ${dist.toStringAsFixed(2)}m '
              'from previous point (min ${_minPointSpacingMeters}m). '
              'Candidate: (${point.latitude}, ${point.longitude})');
          return _PointRejection.tooClose;
        }
        if (dist > _maxJumpMeters) {
          _logger.w('Point rejected (too far): ${dist.toStringAsFixed(1)}m '
              'from previous point (max ${_maxJumpMeters}m). '
              'Candidate: (${point.latitude}, ${point.longitude})');
          return _PointRejection.tooFar;
        }
        _logger.i('Point ${_boundaryPoints.length + 1} accepted at '
            '(${point.latitude}, ${point.longitude}), '
            '${dist.toStringAsFixed(2)}m from previous point.');
      } else {
        _logger.i('Point 1 (start) accepted at '
            '(${point.latitude}, ${point.longitude}).');
      }
      setState(() {
        _boundaryPoints.add(point);
        _areaHectares = _shoelaceAreaHectares(_boundaryPoints);
        _perimeterMeters = _haversinePerimeterMeters(_boundaryPoints);
      });
      _logger.i('Boundary now ${_boundaryPoints.length} point(s), '
          'area ${_areaHectares.toStringAsFixed(4)} ha, '
          'perimeter ${_perimeterMeters.toStringAsFixed(1)} m.');
      return null;
    } finally {
      _isAddingPoint = false;
    }
  }

  void _reportRejection(_PointRejection? rejection) {
    if (rejection == null) return;
    final String message = switch (rejection) {
      _PointRejection.tooClose => 'Too close to the last point — move at least '
          '${_minPointSpacingMeters.toStringAsFixed(1)}m before adding the '
          'next one.',
      _PointRejection.tooFar => 'That reading jumped more than '
          '${(_maxJumpMeters / 1000).toStringAsFixed(0)}km from the last '
          'point — GPS may be inaccurate here. Try again.',
    };
    _logger.w('Point rejection shown to user: $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Fetches a brand-new GPS fix and attempts to add it as the next
  /// boundary point. A fresh reading is requested here rather than reusing
  /// the passive position-stream's cached value, because that stream only
  /// emits on ~1m movement — if the device hasn't moved since the last
  /// point, "ADD POINT" would otherwise keep resubmitting the exact same
  /// coordinates and get silently rejected as "too close", which is what
  /// made the second point appear to hang.
  Future<void> _onAddPointPressed() async {
    if (_isFetchingPosition || _isAddingPoint) return;
    setState(() => _isFetchingPosition = true);
    try {
      final Position fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _logger.i('Fresh GPS fix: (${fresh.latitude}, ${fresh.longitude}), '
          '±${fresh.accuracy.toStringAsFixed(1)}m accuracy.');
      if (!mounted) return;
      setState(() => _currentPosition = fresh);
      _reportRejection(
        _addBoundaryPoint(LatLng(fresh.latitude, fresh.longitude)),
      );
      // A fix worse than the minimum corner spacing can't reliably place a
      // point precisely enough to matter, most noticeable on small plots.
      if (fresh.accuracy > _minPointSpacingMeters * 10 && mounted) {
        final String warning = 'GPS accuracy is low (±'
            '${fresh.accuracy.toStringAsFixed(0)}m) — the point was still '
            'added, but wait for a stronger signal for a more precise '
            'boundary, especially on smaller plots.';
        _logger.w(warning);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(warning)));
      }
    } catch (e, st) {
      _logger.e('Failed to fetch a fresh GPS position',
          error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get a GPS reading. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isFetchingPosition = false);
    }
  }

  void _undoLastPoint() {
    if (_boundaryPoints.isEmpty) return;
    setState(() {
      _boundaryPoints.removeLast();
      _areaHectares = _shoelaceAreaHectares(_boundaryPoints);
      _perimeterMeters = _haversinePerimeterMeters(_boundaryPoints);
    });
  }

  void _clearBoundary() {
    setState(() {
      _boundaryPoints.clear();
      _areaHectares = 0;
      _perimeterMeters = 0;
    });
  }

  // ── Save flow ─────────────────────────────────────────────────

  void _showSaveFarmDialog() {
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

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Save Farm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _farmNameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Farm name'),
              ),
              const SizedBox(height: FarmTheme.spaceMd),
              Text('Points: ${_boundaryPoints.length}'),
              Text('Area: ${_areaLabel(_areaHectares)}'),
              Text('Perimeter: ${_perimeterLabel(_perimeterMeters)}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _saveFarm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FarmTheme.secondaryGreen,
              ),
              child: const Text('Save Farm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveFarm() async {
    final String name = _farmNameCtrl.text.trim();
    if (name.isEmpty || _boundaryPoints.length < _minPointsForPolygon) return;

    setState(() => _isSaving = true);
    try {
      final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final DateTime now = DateTime.now();
      final FarmPolygon farm = FarmPolygon(
        userId: uid,
        farmName: name,
        coordinates: List<LatLng>.from(_boundaryPoints),
        areaHectares: _areaHectares,
        perimeterMeters: _perimeterMeters,
        createdAt: now,
        updatedAt: now,
      );
      await _mappingService.saveFarm(farm);
      _logger.i('Farm "$name" saved: ${_boundaryPoints.length} points, '
          '${_areaHectares.toStringAsFixed(4)} ha, '
          '${_perimeterMeters.toStringAsFixed(1)} m perimeter.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Farm "$name" saved successfully.')),
      );
      Navigator.of(context).pop();
    } on ServiceUnavailableException catch (e) {
      _logger.e('Failed to save farm', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userMessage)),
      );
    } catch (e, st) {
      _logger.e('Failed to save farm', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save farm. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmTheme.cardBackground,
      appBar: AppBar(
        title: const Text('Map Your Farm', style: FarmTheme.screenTitle),
        backgroundColor: FarmTheme.primaryBrown,
        foregroundColor: Colors.white,
      ),
      body: _isCheckingPermission
          ? const Center(child: CircularProgressIndicator())
          : (!_isPermissionGranted || !_locationServicesEnabled)
              ? _buildPermissionError()
              : _buildMapCapture(),
    );
  }

  Widget _buildPermissionError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FarmTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.location_off,
                size: 64, color: FarmTheme.accentBad),
            const SizedBox(height: FarmTheme.spaceMd),
            Text(
              _permissionError ?? 'Location access is required to map a farm.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: FarmTheme.spaceLg),
            ElevatedButton(
              onPressed: _checkLocationPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: FarmTheme.secondaryGreen,
              ),
              child: const Text('Try Again'),
            ),
            if (!_locationServicesEnabled) ...<Widget>[
              const SizedBox(height: FarmTheme.spaceSm),
              TextButton(
                onPressed: () => Geolocator.openLocationSettings(),
                child: const Text('Open Location Settings'),
              ),
            ] else ...<Widget>[
              const SizedBox(height: FarmTheme.spaceSm),
              TextButton(
                onPressed: () => Geolocator.openAppSettings(),
                child: const Text('Open App Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapCapture() {
    final Set<Marker> markers = <Marker>{
      for (int i = 0; i < _boundaryPoints.length; i++)
        Marker(
          markerId: MarkerId('point_$i'),
          position: _boundaryPoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueCyan,
          ),
          anchor: const Offset(0.5, 0.5),
        ),
      if (_currentPosition != null)
        Marker(
          markerId: const MarkerId('current_position'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
    };

    final Set<Polygon> polygons = <Polygon>{};
    final Set<Polyline> polylines = <Polyline>{};
    if (_boundaryPoints.length >= _minPointsForPolygon) {
      polygons.add(
        Polygon(
          polygonId: const PolygonId('active_boundary'),
          points: _boundaryPoints,
          fillColor: FarmTheme.accentGood.withValues(alpha: 0.18),
          strokeColor: FarmTheme.accentGood,
          strokeWidth: 2,
          geodesic: true,
        ),
      );
    } else if (_boundaryPoints.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('boundary_preview'),
          points: _boundaryPoints,
          color: FarmTheme.accentGood,
          width: 3,
          geodesic: true,
        ),
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: GoogleMap(
            mapType: MapType.hybrid,
            initialCameraPosition: _currentPosition != null
                ? CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 17,
                  )
                : const CameraPosition(target: _defaultCenter, zoom: 14),
            onMapCreated: (GoogleMapController ctrl) => _mapController = ctrl,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            markers: markers,
            polygons: polygons,
            polylines: polylines,
            onLongPress: (LatLng latLng) {
              if (_isMappingActive) {
                _reportRejection(_addBoundaryPoint(latLng));
              }
            },
          ),
        ),
        _buildControlPanel(),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black26, blurRadius: 6, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Text('Points: ${_boundaryPoints.length}'),
              Text('Area: ${_areaLabel(_areaHectares)}'),
              Text('Perimeter: ${_perimeterLabel(_perimeterMeters)}'),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          if (!_isMappingActive)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isMappingActive = true),
                icon: const Icon(Icons.play_arrow),
                label: const Text('START MAPPING'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmTheme.secondaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentPosition != null &&
                            !_isAddingPoint &&
                            !_isFetchingPosition
                        ? _onAddPointPressed
                        : null,
                    icon: _isFetchingPosition
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_location, size: 18),
                    label: Text(
                      _isFetchingPosition ? 'LOCATING...' : 'ADD POINT',
                    ),
                  ),
                ),
                const SizedBox(width: FarmTheme.spaceSm),
                IconButton(
                  onPressed: _boundaryPoints.isEmpty ? null : _undoLastPoint,
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo last point',
                ),
                IconButton(
                  onPressed: _boundaryPoints.isEmpty ? null : _clearBoundary,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear all points',
                ),
              ],
            ),
          if (_isMappingActive) ...<Widget>[
            const SizedBox(height: FarmTheme.spaceSm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _showSaveFarmDialog,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'SAVING...' : 'FINISH & SAVE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmTheme.primaryBrown,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Why a candidate boundary point was rejected by [_addBoundaryPoint].
enum _PointRejection { tooClose, tooFar }
