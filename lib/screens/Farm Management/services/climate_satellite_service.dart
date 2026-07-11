import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:coffeecore/config.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';

class ClimateSatelliteService {
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _weatherApiKey = Config.weatherApiKey;
  static const String _agroApiKey = Config.agroApiKey;

  static const String _googleWeatherBase = 'https://weather.googleapis.com/v1';

  // AgroMonitoring doesn't send CORS headers, so browser (web) builds route
  // through a Cloud Functions proxy that fetches server-side instead.
  // Native builds (Android/iOS/desktop) aren't subject to browser CORS and
  // call AgroMonitoring directly.
  static const String _agroBase = kIsWeb
      ? 'https://us-central1-coffeecore-7111a.cloudfunctions.net/agroProxy'
      : 'https://api.agromonitoring.com/agro/1.0';

  static const Duration _timeout = Duration(seconds: 20);

  // ── CLIMATE DATA ────────────────────────────────────────────
  //
  // All fetch methods below throw ServiceUnavailableException on any
  // failure instead of returning null/fabricated data. Callers must not
  // substitute guessed values on error — show the exception's userMessage
  // instead, so the UI never presents invented numbers as if real.

  Future<ClimateData> fetchCurrentClimate(
      {required double lat, required double lng}) async {
    if (_isPlaceholderKey(_weatherApiKey)) {
      _log.w(
        'ClimateSatelliteService.fetchCurrentClimate: '
        'Weather API key not configured – skipping',
      );
      throw const ServiceUnavailableException(
        'Weather service is not configured for this app yet.',
      );
    }
    try {
      _log.i(
        'ClimateSatelliteService.fetchCurrentClimate: '
        'Requesting weather for lat=$lat, lng=$lng',
      );
      final uri = Uri.parse(
        '$_googleWeatherBase/currentConditions:lookup'
        '?key=$_weatherApiKey'
        '&location.latitude=$lat&location.longitude=$lng'
        '&unitsSystem=METRIC',
      );
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode != 200) {
        _log.w(
          'ClimateSatelliteService.fetchCurrentClimate: '
          'HTTP ${res.statusCode} – ${res.body}',
        );
        throw ServiceUnavailableException(
          extractApiMessage(res.body) ??
              'Weather provider returned an error (HTTP ${res.statusCode}).',
        );
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final weatherCondition =
          data['weatherCondition'] as Map<String, dynamic>? ?? {};
      final description =
          weatherCondition['description'] as Map<String, dynamic>?;
      final temperature = data['temperature'] as Map<String, dynamic>?;
      final wind = data['wind'] as Map<String, dynamic>?;
      final windSpeed = wind?['speed'] as Map<String, dynamic>?;
      final precipitation = data['precipitation'] as Map<String, dynamic>?;
      final qpf = precipitation?['qpf'] as Map<String, dynamic>?;

      final climate = ClimateData(
        temperatureCelsius: (temperature?['degrees'] as num? ?? 0).toDouble(),
        humidity: (data['relativeHumidity'] as num? ?? 0).toDouble(),
        rainfallMm: (qpf?['quantity'] as num? ?? 0).toDouble(),
        // Google returns wind speed in km/h under METRIC units; convert to m/s.
        windSpeedMs: (windSpeed?['value'] as num? ?? 0).toDouble() / 3.6,
        weatherDescription:
            (description?['text'] as String? ?? 'Unknown').capitalize(),
        weatherIcon: weatherCondition['iconBaseUri'] as String? ?? '',
        fetchedAt: DateTime.now(),
      );
      _log.i(
        'ClimateSatelliteService.fetchCurrentClimate: '
        '${climate.temperatureCelsius}°C, ${climate.humidity}% RH, '
        '${climate.weatherDescription}',
      );
      return climate;
    } on ServiceUnavailableException {
      rethrow;
    } catch (e, st) {
      _log.e(
        'ClimateSatelliteService.fetchCurrentClimate: Error – $e',
        stackTrace: st,
      );
      throw ServiceUnavailableException(
        isNetworkError(e)
            ? 'Could not reach the weather service — check your internet connection.'
            : 'Something went wrong fetching weather data.',
        isNetworkError: isNetworkError(e),
      );
    }
  }

  // ── 5-DAY FORECAST ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchFiveDayForecast(
      {required double lat, required double lng}) async {
    if (_isPlaceholderKey(_weatherApiKey)) {
      _log.w(
        'ClimateSatelliteService.fetchFiveDayForecast: '
        'API key not configured – skipping',
      );
      throw const ServiceUnavailableException(
        'Weather service is not configured for this app yet.',
      );
    }
    try {
      _log.i(
        'ClimateSatelliteService.fetchFiveDayForecast: '
        'Requesting 5-day forecast for lat=$lat, lng=$lng',
      );
      final uri = Uri.parse(
        '$_googleWeatherBase/forecast/days:lookup'
        '?key=$_weatherApiKey'
        '&location.latitude=$lat&location.longitude=$lng'
        '&days=5&unitsSystem=METRIC',
      );
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode != 200) {
        _log.w(
          'ClimateSatelliteService.fetchFiveDayForecast: '
          'HTTP ${res.statusCode} – ${res.body}',
        );
        throw ServiceUnavailableException(
          extractApiMessage(res.body) ??
              'Forecast provider returned an error (HTTP ${res.statusCode}).',
        );
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rawDays = data['forecastDays'] as List<dynamic>? ?? [];

      final days = <Map<String, dynamic>>[];
      for (final item in rawDays) {
        final entry = item as Map<String, dynamic>;
        final displayDate = entry['displayDate'] as Map<String, dynamic>?;
        if (displayDate == null) continue;
        final dt = DateTime(
          displayDate['year'] as int,
          displayDate['month'] as int,
          displayDate['day'] as int,
        );
        final daytime = entry['daytimeForecast'] as Map<String, dynamic>? ?? {};
        final weatherCondition =
            daytime['weatherCondition'] as Map<String, dynamic>? ?? {};
        final description =
            weatherCondition['description'] as Map<String, dynamic>?;
        final maxTemp = entry['maxTemperature'] as Map<String, dynamic>?;

        days.add({
          'date': dt,
          'temp': (maxTemp?['degrees'] as num? ?? 0).toDouble(),
          'humidity': (daytime['relativeHumidity'] as num? ?? 0).toDouble(),
          'description':
              (description?['text'] as String? ?? 'Unknown').capitalize(),
          'icon': weatherCondition['iconBaseUri'] as String? ?? '',
        });
      }

      _log.i(
        'ClimateSatelliteService.fetchFiveDayForecast: '
        '${days.length} daily forecasts parsed',
      );
      return days.take(5).toList();
    } on ServiceUnavailableException {
      rethrow;
    } catch (e, st) {
      _log.e(
        'ClimateSatelliteService.fetchFiveDayForecast: Error – $e',
        stackTrace: st,
      );
      throw ServiceUnavailableException(
        isNetworkError(e)
            ? 'Could not reach the forecast service — check your internet connection.'
            : 'Something went wrong fetching the forecast.',
        isNetworkError: isNetworkError(e),
      );
    }
  }

  // ── AGRONOMIC SATELLITE – REGISTER POLYGON ──────────────────

  Future<String> registerAgroPolygon({
    required String farmName,
    required List<List<double>> coordinates,
  }) async {
    if (_isPlaceholderKey(_agroApiKey)) {
      _log.w(
        'ClimateSatelliteService.registerAgroPolygon: '
        'AgroMonitoring API key not configured – skipping',
      );
      throw const ServiceUnavailableException(
        'Satellite monitoring is not configured for this app yet.',
      );
    }
    try {
      _log.i(
        'ClimateSatelliteService.registerAgroPolygon: '
        'Registering polygon "$farmName" with ${coordinates.length} vertices',
      );

      final ring = List<List<double>>.from(coordinates);
      if (ring.isNotEmpty &&
          (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
        ring.add(ring.first);
      }

      final body = jsonEncode({
        'name': farmName,
        'geo_json': {
          'type': 'Feature',
          'properties': {},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [ring],
          },
        },
      });

      final res = await http
          .post(
            Uri.parse('$_agroBase/polygons?appid=$_agroApiKey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final responseData = jsonDecode(res.body) as Map<String, dynamic>;
        final polyId = responseData['id'] as String;
        _log.i(
          'ClimateSatelliteService.registerAgroPolygon: '
          'Registered as polyId=$polyId',
        );
        return polyId;
      } else {
        _log.w(
          'ClimateSatelliteService.registerAgroPolygon: '
          'HTTP ${res.statusCode} – ${res.body}',
        );
        throw ServiceUnavailableException(
          extractApiMessage(res.body) ??
              'Satellite provider rejected this farm boundary (HTTP ${res.statusCode}).',
        );
      }
    } on ServiceUnavailableException {
      rethrow;
    } catch (e, st) {
      _log.e(
        'ClimateSatelliteService.registerAgroPolygon: Error – $e',
        stackTrace: st,
      );
      throw ServiceUnavailableException(
        isNetworkError(e)
            ? 'Could not reach the satellite monitoring service — check your internet connection.'
            : 'Something went wrong registering this farm for satellite monitoring.',
        isNetworkError: isNetworkError(e),
      );
    }
  }

  // ── NDVI / SATELLITE DATA ───────────────────────────────────

  Future<SatelliteData> fetchLatestNdvi({required String agroPolyId}) async {
    if (_isPlaceholderKey(_agroApiKey)) {
      _log.w(
        'ClimateSatelliteService.fetchLatestNdvi: '
        'AgroMonitoring API key not configured – skipping',
      );
      throw const ServiceUnavailableException(
        'Satellite monitoring is not configured for this app yet.',
      );
    }
    try {
      final now = DateTime.now();
      final startUnix =
          now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
      final endUnix = now.millisecondsSinceEpoch ~/ 1000;

      _log.i(
        'ClimateSatelliteService.fetchLatestNdvi: '
        'Querying NDVI for polyId=$agroPolyId '
        '(${now.subtract(const Duration(days: 30)).toIso8601String()} → ${now.toIso8601String()})',
      );

      final uri = Uri.parse(
        '$_agroBase/ndvi/history?polyid=$agroPolyId'
        '&appid=$_agroApiKey'
        '&start=$startUnix'
        '&end=$endUnix',
      );
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode != 200) {
        _log.w(
          'ClimateSatelliteService.fetchLatestNdvi: '
          'HTTP ${res.statusCode} – ${res.body}',
        );
        throw ServiceUnavailableException(
          extractApiMessage(res.body) ??
              'Satellite provider returned an error (HTTP ${res.statusCode}).',
        );
      }

      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) {
        _log.w(
          'ClimateSatelliteService.fetchLatestNdvi: '
          'No NDVI history available for polyId=$agroPolyId',
        );
        throw const ServiceUnavailableException(
          'No satellite imagery is available yet for this farm boundary. Try again in a few days.',
        );
      }

      final latest = list.last as Map<String, dynamic>;
      final ndviData = (latest['data'] as Map<String, dynamic>?) ?? {};
      final ndvi = (ndviData['mean'] as num? ?? 0).toDouble();

      final satellite = SatelliteData(
        ndviScore: ndvi,
        vegetationHealth: _ndviToHealth(ndvi),
        soilMoistureIndex: _estimateSoilMoisture(ndvi),
        fetchedAt: DateTime.now(),
        dataSource: 'Sentinel-2 / AgroMonitoring',
      );
      _log.i(
        'ClimateSatelliteService.fetchLatestNdvi: '
        'NDVI=${ndvi.toStringAsFixed(3)}, '
        'Health=${satellite.vegetationHealth}, '
        'SoilMoisture=${satellite.soilMoistureIndex.toStringAsFixed(1)}%',
      );
      return satellite;
    } on ServiceUnavailableException {
      rethrow;
    } catch (e, st) {
      _log.e(
        'ClimateSatelliteService.fetchLatestNdvi: Error – $e',
        stackTrace: st,
      );
      throw ServiceUnavailableException(
        isNetworkError(e)
            ? 'Could not reach the satellite monitoring service — check your internet connection.'
            : 'Something went wrong fetching satellite data.',
        isNetworkError: isNetworkError(e),
      );
    }
  }

  // ── Private helpers ─────────────────────────────────────────

  bool _isPlaceholderKey(String key) => key.startsWith('YOUR_') || key.isEmpty;

  String _ndviToHealth(double ndvi) {
    if (ndvi >= 0.60) return 'Excellent';
    if (ndvi >= 0.40) return 'Good';
    if (ndvi >= 0.20) return 'Fair';
    return 'Poor';
  }

  double _estimateSoilMoisture(double ndvi) =>
      ((ndvi * 85.0).clamp(0.0, 100.0));
}

extension _StringCapitalize on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
