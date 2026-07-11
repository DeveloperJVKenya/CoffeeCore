import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/climate_satellite_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_mapping_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';

/// Latest climate/satellite data for the selected farm, with refresh
/// orchestration and loading/error state. Never fabricates data on
/// failure — surfaces [ServiceUnavailableException.userMessage] instead.
class ClimateSatelliteProvider with ChangeNotifier {
  final FarmPolygon farm;
  final ClimateSatelliteService _climateService;
  final FarmMappingService _mappingService;

  ClimateSatelliteProvider({
    required this.farm,
    ClimateSatelliteService? climateService,
    FarmMappingService? mappingService,
  })  : _climateService = climateService ?? ClimateSatelliteService(),
        _mappingService = mappingService ?? FarmMappingService();

  ClimateData? _climate;
  SatelliteData? _satellite;
  List<Map<String, dynamic>> _forecast = [];
  bool _isLoadingClimate = false;
  bool _isLoadingSatellite = false;
  bool _isLoadingForecast = false;
  String? _climateError;
  String? _satelliteError;
  String? _forecastError;

  ClimateData? get climate => _climate ?? farm.climateData;
  SatelliteData? get satellite => _satellite ?? farm.satelliteData;
  List<Map<String, dynamic>> get forecast => _forecast;
  bool get isLoadingClimate => _isLoadingClimate;
  bool get isLoadingSatellite => _isLoadingSatellite;
  bool get isLoadingForecast => _isLoadingForecast;
  String? get climateError => _climateError;
  String? get satelliteError => _satelliteError;
  String? get forecastError => _forecastError;

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
      String? polyId = farm.agroMonitoringPolyId;
      polyId ??= await _climateService.registerAgroPolygon(
        farmName: farm.farmName,
        coordinates:
            farm.coordinates.map((c) => [c.longitude, c.latitude]).toList(),
      );
      if (polyId != farm.agroMonitoringPolyId) {
        await _mappingService.setAgroMonitoringPolyId(farm.farmId!, polyId);
      }
      final data = await _climateService.fetchLatestNdvi(agroPolyId: polyId);
      _satellite = data;
      await _mappingService.updateSatelliteData(farm.farmId!, data);
    } on ServiceUnavailableException catch (e) {
      _satelliteError = e.userMessage;
    } catch (e) {
      _satelliteError = 'Something went wrong fetching satellite data.';
    } finally {
      _isLoadingSatellite = false;
      notifyListeners();
    }
  }
}
