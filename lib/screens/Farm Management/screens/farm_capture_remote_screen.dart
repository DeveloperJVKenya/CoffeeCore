import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';
import 'package:coffeecore/screens/Farm%20Management/utils/geo_math.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

/// Remote boundary capture screen. Rather than walking the perimeter with a
/// live GPS fix, the user pans/zooms satellite imagery and long-presses to
/// drop each corner, then long-presses (taps) an existing corner to remove
/// or reposition it before saving as a new [FarmPolygon].
class FarmCaptureRemoteScreen extends StatefulWidget {
  const FarmCaptureRemoteScreen({super.key});

  @override
  State<FarmCaptureRemoteScreen> createState() =>
      _FarmCaptureRemoteScreenState();
}

class _FarmCaptureRemoteScreenState extends State<FarmCaptureRemoteScreen> {
  static final Logger _logger = Logger(printer: PrettyPrinter());
  // Only guards against registering the same long-press twice — remote taps
  // aren't GPS noise, so unlike the live-capture screen there's no upper
  // jump distance to enforce; points are expected to be far apart as the
  // user pans/zooms across the farm.
  static const double _minPointSpacingMeters = 0.5;
  static const int _minPointsForPolygon = 3;
  static const LatLng _defaultCenter = LatLng(-1.2921, 36.8219); // Nairobi

  final FarmMappingService _mappingService = FarmMappingService();
  final TextEditingController _farmNameCtrl = TextEditingController();

  final List<LatLng> _boundaryPoints = <LatLng>[];
  LatLng _initialCameraTarget = _defaultCenter;

  /// Index of the point awaiting a new location, or null when not
  /// repositioning. While set, a map tap moves that point instead of
  /// starting a new one.
  int? _repositioningIndex;

  bool _isSaving = false;
  bool _isLocatingInitialView = true;

  double _areaHectares = 0;
  double _perimeterMeters = 0;

  @override
  void initState() {
    super.initState();
    _centerOnLastKnownLocation();
  }

  @override
  void dispose() {
    _farmNameCtrl.dispose();
    super.dispose();
  }

  /// Best-effort: centers the initial camera on the device's last known
  /// location so the user isn't starting from a Nairobi default every time.
  /// This is a one-shot convenience, not a live tracking feed — remote
  /// mapping doesn't require location permission at all, so failures here
  /// are silently ignored and the map just opens at the default center.
  Future<void> _centerOnLastKnownLocation() async {
    try {
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _initialCameraTarget = LatLng(last.latitude, last.longitude);
        });
      }
    } catch (e) {
      _logger.w('No last-known position available for initial camera: $e');
    } finally {
      if (mounted) setState(() => _isLocatingInitialView = false);
    }
  }

  // ── Boundary point editing ──────────────────────────────────────

  void _recomputeGeometry() {
    _areaHectares = GeoMath.shoelaceAreaHectares(_boundaryPoints);
    _perimeterMeters = GeoMath.haversinePerimeterMeters(_boundaryPoints);
  }

  void _onMapLongPress(LatLng point) {
    if (_repositioningIndex != null) {
      // A long-press elsewhere while repositioning is treated as a normal
      // reposition target, same as a tap — see _onMapTap.
      _applyReposition(point);
      return;
    }
    if (_boundaryPoints.isNotEmpty) {
      final double dist =
          GeoMath.haversineDistanceMeters(_boundaryPoints.last, point);
      if (dist < _minPointSpacingMeters) {
        _logger.w('Point rejected (duplicate long-press): '
            '${dist.toStringAsFixed(2)}m from previous point.');
        return;
      }
    }
    setState(() {
      _boundaryPoints.add(point);
      _recomputeGeometry();
    });
    _logger.i('Remote point ${_boundaryPoints.length} added at '
        '(${point.latitude}, ${point.longitude}).');
  }

  void _onMapTap(LatLng point) {
    if (_repositioningIndex == null) return;
    _applyReposition(point);
  }

  void _applyReposition(LatLng point) {
    final int index = _repositioningIndex!;
    setState(() {
      _boundaryPoints[index] = point;
      _repositioningIndex = null;
      _recomputeGeometry();
    });
    _logger.i('Point $index repositioned to '
        '(${point.latitude}, ${point.longitude}).');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Point repositioned.')),
    );
  }

  void _cancelRepositioning() {
    setState(() => _repositioningIndex = null);
  }

  void _removePoint(int index) {
    setState(() {
      _boundaryPoints.removeAt(index);
      _recomputeGeometry();
    });
  }

  /// Corner markers only support onTap (google_maps_flutter has no marker
  /// long-press), so tapping a placed point opens this action sheet rather
  /// than the raw map long-press used to add new points.
  void _showPointActions(int index) {
    if (_repositioningIndex != null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.open_with),
                title: const Text('Reposition point'),
                subtitle: const Text('Tap or long-press the new location'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _repositioningIndex = index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: FarmTheme.accentBad),
                title: const Text('Remove point'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _removePoint(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearBoundary() {
    setState(() {
      _boundaryPoints.clear();
      _repositioningIndex = null;
      _recomputeGeometry();
    });
  }

  // ── Save flow ─────────────────────────────────────────────────

  Future<void> _showSaveFarmDialog() async {
    if (_boundaryPoints.length < _minPointsForPolygon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 3 boundary points to save a farm.'),
        ),
      );
      return;
    }
    _farmNameCtrl.text = await _suggestFarmName();
    if (!mounted) return;

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
              Text('Area: ${GeoMath.areaLabel(_areaHectares)}'),
              Text('Perimeter: ${GeoMath.perimeterLabel(_perimeterMeters)}'),
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

  /// Defaults the farm name to the mapped place (reverse-geocoded from the
  /// boundary centroid) so the user can accept it as-is or edit it before
  /// saving. Falls back to a date-based name if reverse geocoding is
  /// unavailable (offline, no geocoder on device, etc).
  Future<String> _suggestFarmName() async {
    final String fallback =
        'Farm ${DateFormat('dd MMM yyyy').format(DateTime.now())}';
    try {
      final LatLng center = GeoMath.centroid(_boundaryPoints);
      final List<geocoding.Placemark> placemarks =
          await geocoding.placemarkFromCoordinates(
        center.latitude,
        center.longitude,
      );
      if (placemarks.isEmpty) return fallback;
      final geocoding.Placemark place = placemarks.first;
      final String place1 = place.locality?.trim().isNotEmpty == true
          ? place.locality!.trim()
          : (place.subAdministrativeArea?.trim() ?? '');
      final String place2 = place.administrativeArea?.trim() ?? '';
      final String label =
          <String>[place1, place2].where((String s) => s.isNotEmpty).join(', ');
      return label.isEmpty ? fallback : 'Farm - $label';
    } catch (e) {
      _logger.w('Reverse geocoding failed, using default farm name: $e');
      return fallback;
    }
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
      _logger.i('Remote-mapped farm "$name" saved: '
          '${_boundaryPoints.length} points, '
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
        title: const Text('Map From Remote', style: FarmTheme.screenTitle),
        backgroundColor: FarmTheme.primaryBrown,
        foregroundColor: Colors.white,
      ),
      body: _isLocatingInitialView
          ? const Center(child: CircularProgressIndicator())
          : _buildMapCapture(),
    );
  }

  Widget _buildMapCapture() {
    final Set<Marker> markers = <Marker>{
      for (int i = 0; i < _boundaryPoints.length; i++)
        Marker(
          markerId: MarkerId('point_$i'),
          position: _boundaryPoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == _repositioningIndex
                ? BitmapDescriptor.hueOrange
                : i == 0
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueCyan,
          ),
          anchor: const Offset(0.5, 0.5),
          onTap: () => _showPointActions(i),
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
        if (_repositioningIndex != null) _buildRepositioningBanner(),
        Expanded(
          child: GoogleMap(
            mapType: MapType.hybrid,
            initialCameraPosition: CameraPosition(
              target: _initialCameraTarget,
              zoom: 15,
            ),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            markers: markers,
            polygons: polygons,
            polylines: polylines,
            onLongPress: _onMapLongPress,
            onTap: _onMapTap,
          ),
        ),
        _buildControlPanel(),
      ],
    );
  }

  Widget _buildRepositioningBanner() {
    return Container(
      width: double.infinity,
      color: FarmTheme.primaryBrown,
      padding: const EdgeInsets.symmetric(
        horizontal: FarmTheme.spaceMd,
        vertical: FarmTheme.spaceSm,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.open_with, color: Colors.white, size: 18),
          const SizedBox(width: FarmTheme.spaceSm),
          const Expanded(
            child: Text(
              'Tap or long-press the new location for this point',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: _cancelRepositioning,
            child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
              Text('Area: ${GeoMath.areaLabel(_areaHectares)}'),
              Text('Perimeter: ${GeoMath.perimeterLabel(_perimeterMeters)}'),
            ],
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          const Text(
            'Long-press the map to add a point. Tap a point to remove or '
            'reposition it.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: FarmTheme.spaceSm),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _boundaryPoints.isEmpty ? null : _clearBoundary,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('CLEAR ALL'),
                ),
              ),
              const SizedBox(width: FarmTheme.spaceSm),
              Expanded(
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
          ),
        ],
      ),
    );
  }
}
