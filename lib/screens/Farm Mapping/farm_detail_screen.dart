import 'dart:async';
import 'package:coffeecore/screens/Farm%20Mapping/climate_satellite_service.dart';
import 'package:coffeecore/screens/Farm%20Mapping/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Mapping/farm_polygon_model.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Farm%20Mapping/map_tile_providers.dart';
import 'package:coffeecore/screens/Farm%20Mapping/eudr_compliance_service.dart';
import 'package:coffeecore/screens/Farm%20Mapping/service_exceptions.dart';

// ── Fullscreen Map Dialog (with historical forest toggle) ───
class _FullScreenMapDialog extends StatefulWidget {
  final FarmPolygon farm;
  final MapType initialMapType;
  final ValueChanged<MapType> onMapTypeChanged;

  const _FullScreenMapDialog({
    required this.farm,
    required this.initialMapType,
    required this.onMapTypeChanged,
  });

  @override
  State<_FullScreenMapDialog> createState() => _FullScreenMapDialogState();
}

class _FullScreenMapDialogState extends State<_FullScreenMapDialog> {
  late MapType mapType;
  bool showHistoricalForest = false;
  bool showForestLoss = false;
  Set<TileOverlay> tileOverlays = {};

  @override
  void initState() {
    super.initState();
    mapType = widget.initialMapType;
  }

  void updateTiles() {
    final tiles = <TileOverlay>{};
    if (showHistoricalForest) {
      tiles.add(
        TileOverlay(
          tileOverlayId: const TileOverlayId('fs_gfw_treecover_2000'),
          tileProvider: UrlTileProvider(gfwTreeCover2000Url),
          transparency: 0.35,
          zIndex: 20,
        ),
      );
    }
    if (showForestLoss) {
      tiles.add(
        TileOverlay(
          tileOverlayId: const TileOverlayId('fs_gfw_treecover_loss'),
          tileProvider: UrlTileProvider(gfwTreeCoverLossUrl),
          transparency: 0.25,
          zIndex: 21,
        ),
      );
    }
    setState(() => tileOverlays = tiles);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.brown[700],
          foregroundColor: Colors.white,
          title: Text(widget.farm.farmName),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.forest,
                color: showHistoricalForest ? Colors.green[400] : Colors.white70,
              ),
              tooltip: 'Toggle Year 2000 Forest Cover',
              onPressed: () {
                setState(() {
                  showHistoricalForest = !showHistoricalForest;
                  if (showHistoricalForest) showForestLoss = false;
                });
                updateTiles();
              },
            ),
            IconButton(
              icon: Icon(
                Icons.local_fire_department,
                color: showForestLoss ? Colors.red[400] : Colors.white70,
              ),
              tooltip: 'Toggle Forest Loss Layer',
              onPressed: () {
                setState(() {
                  showForestLoss = !showForestLoss;
                  if (showForestLoss) showHistoricalForest = false;
                });
                updateTiles();
              },
            ),
            IconButton(
              icon: Icon(
                mapType == MapType.hybrid
                    ? Icons.map_outlined
                    : Icons.satellite_alt,
                color: Colors.white,
              ),
              tooltip: 'Toggle Map Type',
              onPressed: () {
                setState(() {
                  mapType = mapType == MapType.hybrid
                      ? MapType.normal
                      : MapType.hybrid;
                });
                widget.onMapTypeChanged(mapType);
              },
            ),
          ],
        ),
        body: GoogleMap(
          mapType: mapType,
          initialCameraPosition: CameraPosition(
            target: widget.farm.center,
            zoom: 16.0,
          ),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          mapToolbarEnabled: true,
          polygons: widget.farm.coordinates.length >= 3
              ? {
                  Polygon(
                    polygonId: const PolygonId('farm_boundary_fullscreen'),
                    points: List<LatLng>.from(widget.farm.coordinates),
                    fillColor: const Color(0xFF6D4C41).withValues(alpha: 0.20),
                    strokeColor: const Color(0xFF6D4C41),
                    strokeWidth: 3,
                    geodesic: true,
                  ),
                }
              : {},
          markers: {
            Marker(
              markerId: const MarkerId('farm_center_fullscreen'),
              position: widget.farm.center,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(
                title: widget.farm.farmName,
                snippet: widget.farm.areaLabel,
              ),
            ),
          },
          tileOverlays: tileOverlays,
        ),
      ),
    );
  }
}

class FarmDetailScreen extends StatefulWidget {
  final FarmPolygon farm;

  const FarmDetailScreen({super.key, required this.farm});

  @override
  State<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends State<FarmDetailScreen> {
  // ── Services ────────────────────────────────────────────────
  final FarmMappingService _mappingService = FarmMappingService();
  final ClimateSatelliteService _climateService =
      ClimateSatelliteService();
  final Logger _log = Logger(printer: PrettyPrinter());

  // ── Map ─────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  bool _isMapReady = false;
  MapType _mapType = MapType.hybrid;

  // ── Live data state ──────────────────────────────────────────
  late FarmPolygon _farm;
  ClimateData? _climateData;
  SatelliteData? _satelliteData;
  List<Map<String, dynamic>> _forecastDays = [];

  bool _isRefreshingClimate = false;
  bool _isRefreshingSatellite = false;
  bool _isRefreshingForecast = false;
  bool _isDeleting = false;

  // Reasons a fetch didn't produce real data — shown inline in each card
  // instead of ever substituting guessed/simulated numbers for real ones.
  String? _climateError;
  bool _climateErrorIsNetwork = false;
  String? _satelliteError;
  bool _satelliteErrorIsNetwork = false;

  // ── EUDR Compliance state ───────────────────────────────────
  final EudrComplianceService _eudrService = EudrComplianceService();
  EudrComplianceResult? _eudrResult;
  bool _isCheckingEudr = false;
  bool _showEudrCard = false;
  String? _eudrError;
  bool _eudrErrorIsNetwork = false;

  // ── Theme ────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF6D4C41);
  static const Color _cardBg = Color(0xFFF1ECEA);

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _farm = widget.farm;
    _climateData = _farm.climateData;
    _satelliteData = _farm.satelliteData;
    _log.i(
      'FarmDetailScreen: Opened for "${_farm.farmName}" '
      '(id: ${_farm.farmId}, ${_farm.areaLabel})',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // DATA REFRESH
  // ─────────────────────────────────────────────────────────────

  Future<void> _refreshAllData() async {
    _log.i(
      'FarmDetailScreen: Refreshing all data for "${_farm.farmName}"',
    );
    await Future.wait([
      _refreshClimate(),
      _refreshForecast(),
      _refreshSatellite(),
    ]);
  }

  Future<void> _refreshClimate() async {
    if (_farm.coordinates.isEmpty) return;
    setState(() => _isRefreshingClimate = true);
    try {
      final center = _farm.center;
      _log.i(
        'FarmDetailScreen: Fetching climate data for "${_farm.farmName}" '
        '(${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)})',
      );
      final climate = await _climateService.fetchCurrentClimate(
        lat: center.latitude,
        lng: center.longitude,
      );
      setState(() {
        _climateData = climate;
        _climateError = null;
      });
      if (_farm.farmId != null) {
        await _mappingService.updateClimateData(_farm.farmId!, climate);
        _log.i(
          'FarmDetailScreen: Climate data saved to Firestore '
          'for farm ${_farm.farmId}',
        );
      }
    } on ServiceUnavailableException catch (e) {
      _log.w('FarmDetailScreen: Climate unavailable – ${e.userMessage}');
      if (mounted) {
        setState(() {
          _climateError = e.userMessage;
          _climateErrorIsNetwork = e.isNetworkError;
        });
      }
    } catch (e, st) {
      _log.e('FarmDetailScreen: Climate refresh error – $e', stackTrace: st);
      _showUserError(
        title: 'Weather Data Unavailable',
        message: 'We couldn\'t fetch the latest weather data. Please check your internet connection.',
        technicalDetails: 'Climate refresh error: $e\n$st',
      );
    } finally {
      if (mounted) setState(() => _isRefreshingClimate = false);
    }
  }

  Future<void> _refreshForecast() async {
    if (_farm.coordinates.isEmpty) return;
    setState(() => _isRefreshingForecast = true);
    try {
      final center = _farm.center;
      _log.i(
        'FarmDetailScreen: Fetching 5-day forecast for "${_farm.farmName}"',
      );
      final forecast = await _climateService.fetchFiveDayForecast(
        lat: center.latitude,
        lng: center.longitude,
      );
      if (mounted) setState(() => _forecastDays = forecast);
      _log.i(
        'FarmDetailScreen: Received ${forecast.length} forecast day(s)',
      );
    } on ServiceUnavailableException catch (e) {
      _log.w('FarmDetailScreen: Forecast unavailable – ${e.userMessage}');
      _showUserError(
        title: 'Forecast Unavailable',
        message: e.userMessage,
        technicalDetails: 'Forecast refresh error: ${e.userMessage}',
      );
    } catch (e, st) {
      _log.e('FarmDetailScreen: Forecast refresh error – $e', stackTrace: st);
      _showUserError(
        title: 'Forecast Unavailable',
        message: 'We couldn\'t load the weather forecast. Please try again later.',
        technicalDetails: 'Forecast refresh error: $e\n$st',
      );
    } finally {
      if (mounted) setState(() => _isRefreshingForecast = false);
    }
  }

  Future<void> _refreshSatellite() async {
    setState(() => _isRefreshingSatellite = true);
    try {
      var agroPolyId = _farm.agroMonitoringPolyId;

      // Legacy farms saved before an AgroMonitoring key was configured never
      // got registered. Retry registration now that a real key may exist,
      // instead of showing simulated data forever.
      if (agroPolyId == null && _farm.farmId != null) {
        if (_farm.coordinates.length < 3) {
          throw const ServiceUnavailableException(
            'This farm needs at least 3 boundary points before satellite monitoring can be enabled.',
          );
        }
        _log.i(
          'FarmDetailScreen: No AgroMonitoring polyId for '
          '"${_farm.farmName}" – attempting retroactive registration',
        );
        final coords =
            _farm.coordinates.map((c) => [c.longitude, c.latitude]).toList();
        agroPolyId = await _climateService.registerAgroPolygon(
          farmName: _farm.farmName,
          coordinates: coords,
        );
        await _mappingService.setAgroMonitoringPolyId(
            _farm.farmId!, agroPolyId);
        if (mounted) {
          setState(() {
            _farm = _farm.copyWith(agroMonitoringPolyId: agroPolyId);
          });
        }
        _log.i(
          'FarmDetailScreen: Registered "${_farm.farmName}" with '
          'AgroMonitoring → polyId=$agroPolyId',
        );
      }

      if (agroPolyId == null) {
        throw const ServiceUnavailableException(
          'Satellite monitoring could not be enabled for this farm.',
        );
      }

      _log.i('FarmDetailScreen: Fetching NDVI for agroPolyId=$agroPolyId');
      final satellite =
          await _climateService.fetchLatestNdvi(agroPolyId: agroPolyId);
      setState(() {
        _satelliteData = satellite;
        _satelliteError = null;
      });
      if (_farm.farmId != null) {
        await _mappingService.updateSatelliteData(_farm.farmId!, satellite);
        _log.i(
          'FarmDetailScreen: Satellite data saved to Firestore '
          '(NDVI=${satellite.ndviScore.toStringAsFixed(3)}, '
          'Health=${satellite.vegetationHealth})',
        );
      }
    } on ServiceUnavailableException catch (e) {
      _log.w('FarmDetailScreen: Satellite unavailable – ${e.userMessage}');
      if (mounted) {
        setState(() {
          _satelliteError = e.userMessage;
          _satelliteErrorIsNetwork = e.isNetworkError;
        });
      }
    } catch (e, st) {
      _log.e(
        'FarmDetailScreen: Satellite refresh error – $e',
        stackTrace: st,
      );
      _showUserError(
        title: 'Satellite Data Unavailable',
        message: 'We couldn\'t fetch the latest satellite imagery. The farm health data may be outdated.',
        technicalDetails: 'Satellite refresh error: $e\n$st',
      );
    } finally {
      if (mounted) setState(() => _isRefreshingSatellite = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FARM ACTIONS
  // ─────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────
  // EUDR COMPLIANCE CHECK
  // ─────────────────────────────────────────────────────────────

  Future<void> _checkEudrCompliance() async {
    if (_farm.coordinates.length < 3) {
      _showUserError(
        title: 'EUDR Check Unavailable',
        message: 'Need a complete farm boundary to run the deforestation check.',
        technicalDetails: 'Farm has fewer than 3 GPS points.',
      );
      return;
    }

    setState(() => _isCheckingEudr = true);
    _log.i(
      'FarmDetailScreen: Starting EUDR compliance check for "${_farm.farmName}"',
    );

    try {
      // Uses Global Forest Watch (GFW) Hansen-UMD API.
      final result = await _eudrService.checkFarmCompliance(
        coordinates: _farm.coordinates,
        areaHectares: _farm.areaHectares,
      );

      // Persist to Firestore
      if (_farm.farmId != null) {
        await _mappingService.updateEudrCompliance(
            _farm.farmId!, EudrComplianceData.fromResult(result));
        _log.i(
          'FarmDetailScreen: EUDR result persisted to Firestore '
          'for farm ${_farm.farmId}',
        );
      }

      if (mounted) {
        setState(() {
          _eudrResult = result;
          _eudrError = null;
          _showEudrCard = true;
          _isCheckingEudr = false;
        });
      }
    } on ServiceUnavailableException catch (e) {
      _log.w('FarmDetailScreen: EUDR unavailable – ${e.userMessage}');
      if (mounted) {
        setState(() {
          _isCheckingEudr = false;
          _eudrError = e.userMessage;
          _eudrErrorIsNetwork = e.isNetworkError;
          _showEudrCard = true;
        });
      }
    } catch (e, st) {
      _log.e('FarmDetailScreen: EUDR check error – $e', stackTrace: st);
      if (mounted) {
        setState(() => _isCheckingEudr = false);
        _showUserError(
          title: 'EUDR Check Failed',
          message:
              'Could not retrieve historical forest data. '
              'Please check your internet connection and try again.',
          technicalDetails: 'EUDR compliance check error: $e$st',
        );
      }
    }
  }

  Future<void> _showRenameDialog() async {
    final ctrl = TextEditingController(text: _farm.farmName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.brown[700], size: 20),
            const SizedBox(width: 8),
            const Text('Rename Farm'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Farm Name',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Colors.brown[700]!, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == _farm.farmName) {
      return;
    }
    if (_farm.farmId == null) return;

    try {
      _log.i(
        'FarmDetailScreen: Renaming "${_farm.farmName}" → "$newName"',
      );
      await _mappingService.renameFarm(_farm.farmId!, newName);
      setState(() {
        _farm = _farm.copyWith(farmName: newName);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Farm renamed to "$newName"'),
            backgroundColor: Colors.brown[700],
          ),
        );
      }
    } catch (e, st) {
      _log.e('FarmDetailScreen: Rename error – $e', stackTrace: st);
      _showUserError(
        title: 'Rename Failed',
        message: 'Could not rename the farm. Please try again.',
        technicalDetails: 'Rename error: $e\n$st',
      );
    }
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Farm?'),
        content: Text(
          'Permanently delete "${_farm.farmName}"?\n\n'
          'All boundary data, climate readings, and satellite '
          'records will be removed. This cannot be undone.',
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || _farm.farmId == null) return;

    setState(() => _isDeleting = true);
    try {
      _log.i(
        'FarmDetailScreen: Deleting farm "${_farm.farmName}" (${_farm.farmId})',
      );
      await _mappingService.deleteFarm(_farm.farmId!);
      _log.i('FarmDetailScreen: Farm deleted successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${_farm.farmName}" deleted'),
            backgroundColor: Colors.red[700],
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, st) {
      _log.e('FarmDetailScreen: Delete error – $e', stackTrace: st);
      setState(() => _isDeleting = false);
      _showUserError(
        title: 'Delete Failed',
        message: 'Could not delete the farm. Please try again.',
        technicalDetails: 'Delete error: $e\n$st',
      );
    }
  }

  // ── User-friendly error handling ────────────────────────────
  void _showUserError({
    required String title,
    required String message,
    required String technicalDetails,
  }) {
    _log.e('USER_ERROR [$title]: $technicalDetails');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DETAILS',
          textColor: Colors.white,
          onPressed: () {
            _showTechnicalErrorDialog(title, message, technicalDetails);
          },
        ),
      ),
    );
  }

  void _showTechnicalErrorDialog(String title, String message, String technical) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              const Text(
                'Technical Details (for developers):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(  // FIXED: Use SelectableText for easy copying
                  technical,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.green[400],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FULLSCREEN MAP
  // ─────────────────────────────────────────────────────────────

  void _showFullScreenMap() {
    showDialog(
      context: context,
      builder: (ctx) => _FullScreenMapDialog(
        farm: _farm,
        initialMapType: _mapType,
        onMapTypeChanged: (type) {
          if (mounted) setState(() => _mapType = type);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EE),
      appBar: _buildAppBar(),
      body: _isDeleting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6D4C41)),
                  SizedBox(height: 12),
                  Text('Deleting farm…'),
                ],
              ),
            )
          : RefreshIndicator(
              color: Colors.brown[700],
              onRefresh: _refreshAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMapCard(),
                    const SizedBox(height: 12),
                    _buildEudrComplianceCard(),
                    const SizedBox(height: 12),
                    _buildFarmStatsCard(),
                    const SizedBox(height: 12),
                    _buildClimateCard(),
                    const SizedBox(height: 12),
                    _buildSatelliteCard(),
                    const SizedBox(height: 12),
                    if (_forecastDays.isNotEmpty ||
                        _isRefreshingForecast)
                      _buildForecastCard(),
                    const SizedBox(height: 12),
                    _buildBoundaryCoordinatesCard(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.brown[700],
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _farm.farmName,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _farm.areaLabel,
            style:
                const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
      actions: [
        (_isRefreshingClimate || _isRefreshingSatellite || _isRefreshingForecast)
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh data',
                onPressed: _refreshAllData,
              ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (val) {
            if (val == 'rename') _showRenameDialog();
            if (val == 'delete') _showDeleteDialog();
            if (val == 'maptype') {
              setState(() {
                _mapType = _mapType == MapType.hybrid
                    ? MapType.normal
                    : MapType.hybrid;
              });
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'rename',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Rename Farm'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'maptype',
              child: ListTile(
                leading: Icon(Icons.satellite_alt),
                title: Text('Toggle Map Type'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Farm',
                    style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SECTION CARDS
  // ─────────────────────────────────────────────────────────────

  // ── EUDR Compliance Card ────────────────────────────────────

  // Farms checked before simulated fallbacks were removed may still have a
  // fabricated result persisted in Firestore. Never treat that as real data.
  bool _isSimulatedEudrData(EudrComplianceData? data) =>
      data != null && data.dataSource.toUpperCase().contains('SIMULATED');

  Widget _buildEudrComplianceCard() {
    final persistedEudr = _isSimulatedEudrData(_farm.eudrCompliance)
        ? null
        : _farm.eudrCompliance;

    if (!_showEudrCard && persistedEudr == null) {
      return _sectionCard(
        icon: Icons.forest,
        title: 'EUDR Deforestation Check',
        trailing: _isCheckingEudr
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Switch(
                value: _showEudrCard,
                onChanged: (val) {
                  if (val) _checkEudrCompliance();
                  setState(() => _showEudrCard = val);
                },
                activeThumbColor: Colors.brown[700],
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toggle on to check if this farm was forested before 2020. '
              'This is required for EUDR (EU Deforestation Regulation) compliance '
              'certification before selling to international markets.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.brown[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Uses Hansen-UMD satellite data (2000 baseline) via Global Forest Watch.',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final result = _eudrResult ??
        (persistedEudr != null
            ? EudrComplianceResult(
                isCompliant: persistedEudr.isCompliant,
                wasForestedBefore2020: persistedEudr.wasForestedBefore2020,
                treeCoverPercent2000: persistedEudr.treeCoverPercent2000,
                treeCoverLossAreaHa: persistedEudr.treeCoverLossAreaHa,
                remainingTreeCoverPercent: persistedEudr.remainingTreeCoverPercent,
                explanation: persistedEudr.explanation,
                recommendation: persistedEudr.recommendation,
                dataSource: persistedEudr.dataSource,
                checkedAt: persistedEudr.checkedAt,
              )
            : null);

    if (result == null) {
      return _sectionCard(
        icon: Icons.forest,
        title: 'EUDR Deforestation Check',
        trailing: _isCheckingEudr
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                icon: Icon(Icons.refresh, size: 18, color: Colors.brown[600]),
                tooltip: 'Retry EUDR check',
                onPressed: _checkEudrCompliance,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
        child: _eudrError != null
            ? _unavailableState(_eudrError!, isNetwork: _eudrErrorIsNetwork)
            : _emptyDataState('No EUDR data available.', false),
      );
    }

    final Color statusColor = result.isCompliant ? Colors.green[700]! : Colors.red[700]!;
    final IconData statusIcon = result.isCompliant ? Icons.verified : Icons.warning_rounded;
    final String statusLabel = result.isCompliant ? 'EUDR COMPLIANT' : 'NON-COMPLIANT';

    return _sectionCard(
      icon: Icons.forest,
      title: 'EUDR Deforestation Check',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isCheckingEudr)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(
            icon: Icon(Icons.refresh, size: 18, color: Colors.brown[600]),
            tooltip: 'Re-check compliance',
            onPressed: _isCheckingEudr ? null : _checkEudrCompliance,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        result.isCompliant
                            ? 'Eligible for EU market export'
                            : 'Deforestation risk – export blocked',
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Metrics
          Row(
            children: [
              _statBox(
                label: 'Tree Cover 2000',
                value: '${result.treeCoverPercent2000.toStringAsFixed(1)}%',
                icon: Icons.park,
                color: result.wasForestedBefore2020
                    ? Colors.green[700]!
                    : Colors.orange[700]!,
              ),
              const SizedBox(width: 10),
              _statBox(
                label: 'Loss < 2020',
                value: '${result.treeCoverLossAreaHa.toStringAsFixed(2)} ha',
                icon: Icons.remove_circle_outline,
                color: result.treeCoverLossAreaHa > 0.01
                    ? Colors.red[700]!
                    : Colors.grey[600]!,
              ),
              const SizedBox(width: 10),
              _statBox(
                label: 'Remaining',
                value: '${result.remainingTreeCoverPercent.toStringAsFixed(1)}%',
                icon: Icons.nature,
                color: Colors.teal[700]!,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Explanation
          Text(
            'Analysis Result',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.brown[800],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.explanation,
            style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
          ),
          const SizedBox(height: 12),

          // Recommendation box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: result.isCompliant
                  ? Colors.green[50]
                  : Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: result.isCompliant
                    ? Colors.green.shade200
                    : Colors.red.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      result.isCompliant ? Icons.check_circle : Icons.warning_amber,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Recommendation',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.recommendation,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Source: ${result.dataSource} • Checked ${_timeAgo(result.checkedAt)}',
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Map preview ──────────────────────────────────────────
  Widget _buildMapCard() {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          GoogleMap(
            mapType: _mapType,
            initialCameraPosition: CameraPosition(
              target: _farm.center,
              zoom: 16.0,
            ),
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              setState(() => _isMapReady = true);
              _log.i(
                'FarmDetailScreen: Map ready, zooming to farm boundary',
              );
              if (_farm.coordinates.length >= 2) {
                final bounds = _latLngBounds(_farm.coordinates);
                Future.delayed(
                  const Duration(milliseconds: 400),
                  () {
                    if (_isMapReady && mounted) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngBounds(bounds, 50),
                      );
                    }
                  },
                );
              }
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            mapToolbarEnabled: false,
            polygons: _farm.coordinates.length >= 3
                ? {
                    Polygon(
                      polygonId: const PolygonId('farm_boundary'),
                      points: List<LatLng>.from(_farm.coordinates),
                      fillColor: _primary.withValues(alpha: 0.20),
                      strokeColor: _primary,
                      strokeWidth: 3,
                    ),
                  }
                : {},
            markers: {
              Marker(
                markerId: const MarkerId('farm_center'),
                position: _farm.center,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
                infoWindow: InfoWindow(
                  title: _farm.farmName,
                  snippet: _farm.areaLabel,
                ),
                zIndexInt: 5,
              ),
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: FloatingActionButton.small(
              heroTag: 'expand_map_detail',
              onPressed: _showFullScreenMap,
              backgroundColor: Colors.white,
              foregroundColor: Colors.brown[700],
              tooltip: 'Expand Map',
              child: const Icon(Icons.fullscreen),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Farm statistics ──────────────────────────────────────
  Widget _buildFarmStatsCard() {
    return _sectionCard(
      icon: Icons.terrain,
      title: 'Farm Overview',
      child: Column(
        children: [
          Row(
            children: [
              _statBox(
                label: 'Total Area',
                value: _farm.areaLabel,
                icon: Icons.crop_square,
                color: Colors.brown[700]!,
              ),
              const SizedBox(width: 10),
              _statBox(
                label: 'Perimeter',
                value: _farm.perimeterLabel,
                icon: Icons.linear_scale,
                color: Colors.brown[600]!,
              ),
              const SizedBox(width: 10),
              _statBox(
                label: 'GPS Points',
                value: '${_farm.coordinates.length}',
                icon: Icons.push_pin,
                color: Colors.teal[700]!,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _infoRow(
            Icons.calendar_today,
            'Date Mapped',
            DateFormat('dd MMM yyyy, HH:mm').format(_farm.createdAt),
          ),
          if (_farm.updatedAt != _farm.createdAt)
            _infoRow(
              Icons.update,
              'Last Updated',
              DateFormat('dd MMM yyyy, HH:mm').format(_farm.updatedAt),
            ),
          _infoRow(
            Icons.location_on,
            'Center Coordinates',
            '${_farm.center.latitude.toStringAsFixed(5)}, '
                '${_farm.center.longitude.toStringAsFixed(5)}',
          ),
        ],
      ),
    );
  }

  // ── 3. Climate card ─────────────────────────────────────────
  Widget _buildClimateCard() {
    return _sectionCard(
      icon: Icons.cloud,
      title: 'Current Climate',
      trailing: _isRefreshingClimate
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: Icon(Icons.refresh, size: 18, color: Colors.brown[600]),
              tooltip: 'Refresh climate',
              onPressed: _refreshClimate,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
      child: _climateData == null
          ? (_climateError != null && !_isRefreshingClimate
              ? _unavailableState(_climateError!,
                  isNetwork: _climateErrorIsNetwork)
              : _emptyDataState(
                  _isRefreshingClimate
                      ? 'Fetching weather data…'
                      : 'No climate data available.',
                  _isRefreshingClimate,
                ))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(
                          _climateData!.iconUrl,
                          width: 56,
                          height: 56,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.cloud,
                            size: 50,
                            color: Colors.brown[400],
                          ),
                        ),
                        Text(
                          _climateData!.weatherDescription,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_climateData!.temperatureCelsius.toStringAsFixed(1)}°C',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown[800],
                          ),
                        ),
                        Text(
                          'Farm temperature',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _climateMetric(
                      icon: Icons.water_drop,
                      label: 'Humidity',
                      value: '${_climateData!.humidity.toStringAsFixed(0)}%',
                      color: Colors.blue[700]!,
                    ),
                    _climateMetric(
                      icon: Icons.grain,
                      label: 'Rainfall',
                      value:
                          '${_climateData!.rainfallMm.toStringAsFixed(1)} mm',
                      color: Colors.indigo[600]!,
                    ),
                    _climateMetric(
                      icon: Icons.air,
                      label: 'Wind',
                      value:
                          '${_climateData!.windSpeedMs.toStringAsFixed(1)} m/s',
                      color: Colors.teal[600]!,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Updated ${_timeAgo(_climateData!.fetchedAt)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
    );
  }

  // ── 4. Satellite / NDVI card ────────────────────────────────
  Widget _buildSatelliteCard() {
    return _sectionCard(
      icon: Icons.satellite_alt,
      title: 'Satellite Analysis',
      trailing: _isRefreshingSatellite
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: Icon(Icons.refresh, size: 18, color: Colors.brown[600]),
              tooltip: 'Refresh satellite data',
              onPressed: _refreshSatellite,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
      child: _satelliteData == null
          ? (_satelliteError != null && !_isRefreshingSatellite
              ? _unavailableState(_satelliteError!,
                  isNetwork: _satelliteErrorIsNetwork)
              : _emptyDataState(
                  _isRefreshingSatellite
                      ? 'Fetching satellite data…'
                      : 'No satellite data yet.',
                  _isRefreshingSatellite,
                ))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ndviGauge(_satelliteData!.ndviScore),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _satelliteData!.healthColor
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _satelliteData!.healthColor
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.eco,
                                  size: 16,
                                  color: _satelliteData!.healthColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _satelliteData!.vegetationHealth,
                                  style: TextStyle(
                                    color: _satelliteData!.healthColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vegetation Health',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _ndviHealthDescription(
                                _satelliteData!.vegetationHealth),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Text('NDVI',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700])),
                    const SizedBox(width: 8),
                    Expanded(child: _ndviBar(_satelliteData!.ndviScore)),
                    const SizedBox(width: 8),
                    Text(
                      _satelliteData!.ndviScore.toStringAsFixed(2),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _satelliteData!.healthColor),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                _infoRow(
                  Icons.water,
                  'Soil Moisture Index',
                  '${_satelliteData!.soilMoistureIndex.toStringAsFixed(1)}%',
                ),
                _infoRow(
                  Icons.satellite_alt,
                  'Data Source',
                  _satelliteData!.dataSource,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Updated ${_timeAgo(_satelliteData!.fetchedAt)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ),

                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.brown[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.brown.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_cafe,
                              size: 14, color: Colors.brown[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Coffee Farm Interpretation',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _coffeeFarmNdviAdvice(_satelliteData!.ndviScore),
                        style: TextStyle(
                            fontSize: 12, color: Colors.brown[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── 5. 5-Day forecast ───────────────────────────────────────
  Widget _buildForecastCard() {
    return _sectionCard(
      icon: Icons.wb_sunny_outlined,
      title: '5-Day Forecast',
      child: _isRefreshingForecast && _forecastDays.isEmpty
          ? _emptyDataState('Loading forecast…', true)
          : _forecastDays.isEmpty
              ? _emptyDataState('No forecast data available.', false)
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _forecastDays.map((day) {
                      final date = day['date'] as DateTime;
                      final temp =
                          (day['temp'] as double).toStringAsFixed(0);
                      final humidity =
                          (day['humidity'] as double).toStringAsFixed(0);
                      final icon = day['icon'] as String;
                      final desc = day['description'] as String;
                      final isToday = date.day == DateTime.now().day;

                      return Container(
                        width: 88,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.brown[700]
                              : Colors.brown[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isToday
                                ? Colors.brown[700]!
                                : Colors.brown.shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              isToday
                                  ? 'Today'
                                  : DateFormat('EEE').format(date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isToday
                                    ? Colors.white
                                    : Colors.brown[700],
                              ),
                            ),
                            Text(
                              DateFormat('d MMM').format(date),
                              style: TextStyle(
                                fontSize: 10,
                                color: isToday
                                    ? Colors.white70
                                    : Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Image.network(
                              icon.isEmpty ? '' : '$icon.png',
                              width: 40,
                              height: 40,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.wb_cloudy_outlined,
                                size: 36,
                                color: isToday
                                    ? Colors.white70
                                    : Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$temp°C',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isToday
                                    ? Colors.white
                                    : Colors.brown[800],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: isToday
                                    ? Colors.white70
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.water_drop,
                                  size: 10,
                                  color: isToday
                                      ? Colors.white70
                                      : Colors.blue[400],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '$humidity%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isToday
                                        ? Colors.white70
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  // ── 6. GPS boundary coordinates ─────────────────────────────
  Widget _buildBoundaryCoordinatesCard() {
    return _sectionCard(
      icon: Icons.gps_fixed,
      title: 'GPS Boundary Points (${_farm.coordinates.length})',
      child: _farm.coordinates.isEmpty
          ? _emptyDataState('No boundary coordinates recorded.', false)
          : Column(
              children: List.generate(
                _farm.coordinates.length > 10
                    ? 10
                    : _farm.coordinates.length,
                (i) {
                  final pt = _farm.coordinates[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? Colors.green[700]
                                : Colors.brown[100],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: i == 0
                                    ? Colors.white
                                    : Colors.brown[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${pt.latitude.toStringAsFixed(6)}°N,  '
                                '${pt.longitude.toStringAsFixed(6)}°E',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )..addAll(
                  _farm.coordinates.length > 10
                      ? [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '… and ${_farm.coordinates.length - 10} more points',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          )
                        ]
                      : [],
                ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // REUSABLE WIDGET BUILDERS
  // ─────────────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade500.withAlpha(80),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.brown[700]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[800],
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style:
                  TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.brown[500]),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _climateMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color),
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

  Widget _emptyDataState(String message, bool loading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            loading
                ? CircularProgressIndicator(color: Colors.brown[400])
                : Icon(Icons.signal_wifi_off_outlined,
                    size: 36, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // Distinct from _emptyDataState: this is shown when a real fetch attempt
  // failed for a specific, known reason (business-rule rejection, network
  // failure, missing config) — never used to dress up fabricated data as
  // if it were real.
  Widget _unavailableState(String reason, {bool isNetwork = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Center(
        child: Column(
          children: [
            Icon(
              isNetwork ? Icons.wifi_off_rounded : Icons.info_outline,
              size: 32,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ndviGauge(double ndvi) {
    final fraction = ((ndvi + 1) / 2).clamp(0.0, 1.0);
    final color = _satelliteData!.healthColor;
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 8,
              backgroundColor: Colors.grey[200],
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ndvi.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'NDVI',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ndviBar(double ndvi) {
    final fraction = ((ndvi + 1) / 2).clamp(0.0, 1.0);
    return Stack(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE53935),
                Color(0xFFFFB300),
                Color(0xFF66BB6A),
                Color(0xFF2E7D32),
              ],
            ),
          ),
        ),
        Positioned(
          left: (fraction * (MediaQuery.of(context).size.width - 120))
              .clamp(0, MediaQuery.of(context).size.width - 120),
          top: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                  color: _satelliteData!.healthColor, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3)
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS & UTILITIES
  // ─────────────────────────────────────────────────────────────

  LatLngBounds _latLngBounds(List<LatLng> pts) {
    final lats = pts.map((p) => p.latitude);
    final lngs = pts.map((p) => p.longitude);
    double minLat = lats.reduce((a, b) => a < b ? a : b);
    double maxLat = lats.reduce((a, b) => a > b ? a : b);
    double minLng = lngs.reduce((a, b) => a < b ? a : b);
    double maxLng = lngs.reduce((a, b) => a > b ? a : b);
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _ndviHealthDescription(String health) {
    switch (health.toLowerCase()) {
      case 'excellent':
        return 'Dense, highly active vegetation cover.';
      case 'good':
        return 'Healthy vegetation with adequate cover.';
      case 'fair':
        return 'Moderate vegetation; monitor closely.';
      case 'poor':
        return 'Sparse or stressed vegetation detected.';
      default:
        return 'Vegetation status unknown.';
    }
  }

  String _coffeeFarmNdviAdvice(double ndvi) {
    if (ndvi >= 0.60) {
      return 'Excellent canopy coverage. Coffee trees are thriving. '
          'Continue current management practices.';
    } else if (ndvi >= 0.40) {
      return 'Good vegetation health. Consider shade management '
          'and routine fertilisation to maintain vigour.';
    } else if (ndvi >= 0.20) {
      return 'Fair health detected. Review irrigation, soil nutrients, '
          'and inspect for pest/disease pressure.';
    } else {
      return 'Low NDVI indicates stressed or sparse vegetation. '
          'Urgent soil analysis, pest inspection, and possible replanting '
          'of gaps is recommended.';
    }
  }
}