import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/drought_risk_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/ndvi_history_entry_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/climate_satellite_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/drought_risk_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/sentinel_hub_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';

/// Latest climate/satellite data for the selected farm, with refresh
/// orchestration and loading/error state. Never fabricates data on
/// failure — surfaces [ServiceUnavailableException.userMessage] instead.
class ClimateSatelliteProvider with ChangeNotifier {
  final FarmPolygon farm;
  final ClimateSatelliteService _climateService;
  final FarmMappingService _mappingService;
  final SentinelHubService _sentinelHubService;
  final DroughtRiskService _droughtRiskService;

  ClimateSatelliteProvider({
    required this.farm,
    ClimateSatelliteService? climateService,
    FarmMappingService? mappingService,
    SentinelHubService? sentinelHubService,
    DroughtRiskService? droughtRiskService,
  })  : _climateService = climateService ?? ClimateSatelliteService(),
        _mappingService = mappingService ?? FarmMappingService(),
        _sentinelHubService = sentinelHubService ?? SentinelHubService(),
        _droughtRiskService = droughtRiskService ?? DroughtRiskService();

  ClimateData? _climate;
  SatelliteData? _satellite;
  List<Map<String, dynamic>> _forecast = [];
  List<NdviHistoryEntry> _history = [];
  // Cached locally (in addition to farm.agroMonitoringPolyId) because
  // `farm` is immutable for the lifetime of this provider — without this,
  // every refresh after the first would see farm.agroMonitoringPolyId as
  // still null (even though it was persisted to Firestore) and try to
  // register a duplicate AgroMonitoring polygon, which the API rejects.
  String? _agroMonitoringPolyId;
  bool _isLoadingClimate = false;
  bool _isLoadingSatellite = false;
  bool _isLoadingForecast = false;
  bool _isLoadingNdwi = false;
  String? _climateError;
  String? _satelliteError;
  String? _forecastError;
  String? _ndwiError;

  ClimateData? get climate => _climate ?? farm.climateData;
  SatelliteData? get satellite => _satellite ?? farm.satelliteData;
  List<Map<String, dynamic>> get forecast => _forecast;
  List<NdviHistoryEntry> get history => _history;
  bool get isLoadingClimate => _isLoadingClimate;
  bool get isLoadingSatellite => _isLoadingSatellite;
  bool get isLoadingForecast => _isLoadingForecast;
  bool get isLoadingNdwi => _isLoadingNdwi;
  String? get climateError => _climateError;
  String? get satelliteError => _satelliteError;
  String? get forecastError => _forecastError;
  String? get ndwiError => _ndwiError;

  /// Transparent, explainable Drought Risk Index derived from whatever
  /// NDVI/NDWI/climate/forecast data is currently loaded. Purely computed —
  /// no loading/error state needed since it's synchronous — and returns
  /// null only when there's no satellite data at all yet to base it on.
  DroughtRiskResult? get droughtRisk {
    final s = satellite;
    if (s == null) return null;
    return _droughtRiskService.compute(
      currentNdvi: s.ndviScore,
      ndviHistory: _history,
      currentNdwi: s.ndwiScore,
      forecast: _forecast,
      climate: climate,
    );
  }

  Future<void> refreshClimate() async {
    if (farm.farmId == null) return;
    _isLoadingClimate = true;
    _climateError = null;
    notifyListeners();
    try {
      final center = farm.center;
      final data = await _climateService.fetchCurrentClimate(
          lat: center.latitude, lng: center.longitude);
      _climate = data;
      await _mappingService.updateClimateData(farm.farmId!, data);
    } on ServiceUnavailableException catch (e) {
      _climateError = e.userMessage;
    } catch (e) {
      _climateError = 'Something went wrong fetching climate data.';
    } finally {
      _isLoadingClimate = false;
      notifyListeners();
    }
  }

  Future<void> refreshForecast() async {
    _isLoadingForecast = true;
    _forecastError = null;
    notifyListeners();
    try {
      final center = farm.center;
      final days = await _climateService.fetchFiveDayForecast(
          lat: center.latitude, lng: center.longitude);
      _forecast = days;
    } on ServiceUnavailableException catch (e) {
      _forecastError = e.userMessage;
    } catch (e) {
      _forecastError = 'Something went wrong fetching the forecast.';
    } finally {
      _isLoadingForecast = false;
      notifyListeners();
    }
  }

  Future<void> refreshSatellite() async {
    if (farm.farmId == null) return;
    _isLoadingSatellite = true;
    _satelliteError = null;
    notifyListeners();
    try {
      String? polyId = _agroMonitoringPolyId ?? farm.agroMonitoringPolyId;
      polyId ??= await _climateService.registerAgroPolygon(
        farmName: farm.farmName,
        coordinates:
            farm.coordinates.map((c) => [c.longitude, c.latitude]).toList(),
      );
      if (polyId != farm.agroMonitoringPolyId) {
        await _mappingService.setAgroMonitoringPolyId(farm.farmId!, polyId);
      }
      _agroMonitoringPolyId = polyId;
      final data = await _climateService.fetchLatestNdvi(agroPolyId: polyId);
      // Preserve any already-fetched NDWI reading across this NDVI refresh.
      _satellite = data.copyWith(
        ndwiScore: _satellite?.ndwiScore,
        moistureLevel: _satellite?.moistureLevel,
      );
      await _mappingService.updateSatelliteData(farm.farmId!, _satellite!);
      await _mappingService.appendNdviHistoryEntry(
        farm.farmId!,
        NdviHistoryEntry(
          ndvi: data.ndviScore,
          ndwi: _satellite?.ndwiScore,
          fetchedAt: DateTime.now(),
        ),
      );
    } on ServiceUnavailableException catch (e) {
      _satelliteError = e.userMessage;
    } catch (e) {
      _satelliteError = 'Something went wrong fetching satellite data.';
    } finally {
      _isLoadingSatellite = false;
      notifyListeners();
    }
  }

  Future<void> refreshNdwi() async {
    if (farm.farmId == null) return;
    _isLoadingNdwi = true;
    _ndwiError = null;
    notifyListeners();
    try {
      final ndwi =
          await _sentinelHubService.fetchNdwi(coordinates: farm.coordinates);
      final base = satellite;
      if (base == null) {
        throw const ServiceUnavailableException(
          'Fetch NDVI/satellite data for this farm first, then retry moisture (NDWI).',
        );
      }
      final updated = base.copyWith(
        ndwiScore: ndwi.mean,
        moistureLevel: _ndwiToMoistureLevel(ndwi.mean),
      );
      _satellite = updated;
      await _mappingService.updateSatelliteData(farm.farmId!, updated);
      await _mappingService.appendNdviHistoryEntry(
        farm.farmId!,
        NdviHistoryEntry(
          ndvi: updated.ndviScore,
          ndwi: ndwi.mean,
          fetchedAt: DateTime.now(),
        ),
      );
    } on ServiceUnavailableException catch (e) {
      _ndwiError = e.userMessage;
    } catch (e) {
      _ndwiError = 'Something went wrong fetching moisture (NDWI) data.';
    } finally {
      _isLoadingNdwi = false;
      notifyListeners();
    }
  }

  Future<void> loadNdviHistory() async {
    if (farm.farmId == null) return;
    _history = await _mappingService.fetchRecentNdviHistory(farm.farmId!);
    notifyListeners();
  }

  String _ndwiToMoistureLevel(double ndwi) {
    if (ndwi >= 0.30) return 'Saturated';
    if (ndwi >= 0.05) return 'Moist';
    if (ndwi >= -0.20) return 'Adequate';
    return 'Dry';
  }
}
