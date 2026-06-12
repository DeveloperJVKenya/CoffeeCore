import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Farm%20Mapping/farm_polygon_model.dart';

class ClimateSatelliteService {
  final Logger _log = Logger(printer: PrettyPrinter());

  // ── API configuration ───────────────────────────────────────
  // Replace these placeholders with your own keys.
  // Keys are identical for both endpoints (same OpenWeatherMap account).
  static const String _weatherApiKey = 'YOUR_OPENWEATHERMAP_API_KEY';
  static const String _agroApiKey = 'YOUR_AGROMONITORING_API_KEY';

  static const String _owmBase =
      'https://api.openweathermap.org/data/2.5';
  static const String _agroBase =
      'https://agromonitoring.com/agromonitoring/v1';

  static const Duration _timeout = Duration(seconds: 20);

  // ── CLIMATE DATA ────────────────────────────────────────────

  /// Fetches current weather for the farm centroid.
  /// Returns null on API error or if keys are unconfigured.
  Future<ClimateData?> fetchCurrentClimate(
      {required double lat, required double lng}) async {
    if (_isPlaceholderKey(_weatherApiKey)) {
      _log.w(
        'ClimateSatelliteService.fetchCurrentClimate: '
        'OpenWeatherMap API key not configured – skipping',
      );
      return null;
    }
    try {
      _log.i(
        'ClimateSatelliteService.fetchCurrentClimate: '
        'Requesting weather for lat=$lat, lng=$lng',
      );
      final uri = Uri.parse(
        '$_owmBase/weather?lat=$lat&lon=$lng'
        '&appid=$_weatherApiKey&units=metric',
      );
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode != 200) {
        _log.w(
          'ClimateSatelliteService.fetchCurrentClimate: '
          'HTTP ${res.statusCode} – ${res.body}',
        );
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final main = data['main'] as Map<String, dynamic>;
      final wind = data['wind'] as Map<String, dynamic>;
      final weatherList = data['weather'] as List<dynamic>;
      final weather = weatherList.first as Map<String, dynamic>;
      final rainData = data['rain'] as Map<String, dynamic>?;
      final rainfallMm =
          (rainData?['1h'] as num? ?? 0).toDouble();

      final climate = ClimateData(
        temperatureCelsius: (main['temp'] as num).toDouble(),
        humidity: (main['humidity'] as num).toDouble(),
        rainfallMm: rainfallMm,
        windSpeedMs: (wind['speed'] as num).toDouble(),
        weatherDescription:
            (weather['description'] as String).capitalize(),
        weatherIcon: weather['icon'] as String,
        fetchedAt: DateTime.now(),
      );
      _log.i(
        'ClimateSatelliteService.fetchCurrentClimate: '
        '${climate.temperatureCelsius}°C, ${climate.humidity}% RH, '
        '${climate.weatherDescription}',
      );
      return climate;
    } catch (e, st) {
      _log.e(
        'ClimateSatelliteService.fetchCurrentClimate: Error – $e',
        stackTrace: st,
      );
      return null;
    }
  }

  // ── 5-DAY FORECAST ──────────────────────────────────────────

  /// Returns up to 5 daily forecast entries (noon snapshot per day).
  /// Each map contains: date, temp, humidity, description, icon.
  Future<List<Map<String, dynamic>>> fetchFiveDayForecast(
      {required double lat, required double lng}) async {
    if (_isPlaceholderKey(_weatherApiKey)) {
      _log.w(
        'ClimateSatelliteService.fetchFiveDayForecast: '
        'API key not configured – skipping',
      );
      return [];
    }
    try {
      _log.i(
        'ClimateSatelliteService.fetchFiveDayForecast: '
        'Requesting 5-day forecast for lat=$lat, lng=$lng',
      );
      // cnt=40 = 5 days × 8 three-hourly slots
      final uri = Uri.parse(
        '$_owmBase/forecast?lat=$lat&lon=$lng'
        '&appid=$_weatherApiKey&units=metric&cnt=40',
      );
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode != 200) {
        _log.w(
          'ClimateSatelliteService.fetchFiveDayForecast: '
          'HTTP ${res.statusCode}',
        );
        return [];
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rawList = data['list'] as List<dynamic>;

      // Pick one entry per calendar day (prefer the 12:00 slot)
      final Map<String, Map<String, dynamic>> dayMap = {};
      for (final item in rawList) {
        final entry = item as Map<String, dynamic>;
        final dt =
            DateTime.fromMillisecondsSinceEpoch((entry['dt'] as int) * 1000);
        final dayKey =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        if (!dayMap.containsKey(dayKey) || dt.hour == 12) {
          final mainData = entry['main'] as Map<String, dynamic>;
          final weatherList = entry['weather'] as List<dynamic>;
          final weatherEntry = weatherList.first as Map<String, dynamic>;
          dayMap[dayKey] = {
            'date': dt,
            'temp': (mainData['temp'] as num).toDouble(),
            'humidity': (mainData['humidity'] as num).toDouble(),
            'description':
                (weatherEntry['description'] as String).capitalize(),
            'icon': weatherEntry['icon'] as String,
          };
        }
      }

      final sorted = dayMap.values.toList()
        ..sort((a, b) =>
            (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      _log.i(
        'ClimateSatelliteService.fetchFiveDayForecast: '
        '${sorted.length} daily forecasts parsed',
      );
      return sorted.take(5).toList();
    } catch (e, st) {
      _log.e(
        'ClimateSatelliteService.fetchFiveDayForecast: Error – $e',
        stackTrace: st,
      );
      return [];
    }
  }

  // ── AGRONOMIC SATELLITE – REGISTER POLYGON ──────────────────

  /// Registers the farm's GeoJSON polygon with AgroMonitoring.
  /// Must be called once per farm; stores the returned ID in Firestore
  /// via FarmMappingService so NDVI queries can reference it.
  ///
  /// [coordinates]: list of [longitude, latitude] pairs (GeoJSON order).
  /// Returns the AgroMonitoring polygon ID, or null on failure.
  Future<String?> registerAgroPolygon({
    required String farmName,
    required List<List<double>> coordinates, // [[lng, lat], …]
  }) async {
    if (_isPlaceholderKey(_agroApiKey)) {
      _log.w(
        'ClimateSatelliteService.registerAgroPolygon: '
        'AgroMonitoring API key not configured – skipping',
      );
      return null;
    }
    try {
      _log.i(
        'ClimateSatelliteService.registerAgroPolygon: '
        'Registering polygon "$farmName" with ${coordinates.length} vertices',
      );

      // Close the polygon ring if not already closed (GeoJSON requirement)
      final ring = List<List<double>>.from(coordinates);
      if (ring.isNotEmpty &&
          (ring.first[0] != ring.last[0] ||
              ring.first[1] != ring.last[1])) {
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
        final responseData =
            jsonDecode(res.body) as Map<String, dynamic>;
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
        return null;
      }
    } catch (e, st) {
      _log.e(
        'ClimateSatelliteService.registerAgroPolygon: Error – $e',
        stackTrace: st,
      );
      return null;
    }
  }

  // ── NDVI / SATELLITE DATA ───────────────────────────────────

  /// Fetches the latest Sentinel-2 NDVI reading for a registered polygon.
  ///
  /// [agroPolyId]: The polygon ID from [registerAgroPolygon].
  /// Defaults to the past 30 days of data.
  /// Returns null if no data is available or on error.
  Future<SatelliteData?> fetchLatestNdvi(
      {required String agroPolyId}) async {
    if (_isPlaceholderKey(_agroApiKey)) {
      _log.w(
        'ClimateSatelliteService.fetchLatestNdvi: '
        'AgroMonitoring API key not configured – returning simulated data',
      );
      // Return a simulated SatelliteData for development/demo
      return _simulatedNdviData();
    }
    try {
      final now = DateTime.now();
      final startUnix =
          now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/
              1000;
      final endUnix = now.millisecondsSinceEpoch ~/ 1000;

      _log.i(
        'ClimateSatelliteService.fetchLatestNdvi: '
        'Querying NDVI for polyId=$agroPolyId '
        '(${now.subtract(const Duration(days: 30)).toIso8601String()} → ${now.toIso8601String()})',
      );

      final uri = Uri.parse(
        '$_agroBase/ndvi/history?polyid=$agroPolyId'
        '&appid=$_agroApiKey'
        '&period_start=$startUnix'
        '&period_end=$endUnix',
      );
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode != 200) {
        _log.w(
          'ClimateSatelliteService.fetchLatestNdvi: '
          'HTTP ${res.statusCode} – ${res.body}',
        );
        return null;
      }

      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) {
        _log.w(
          'ClimateSatelliteService.fetchLatestNdvi: '
          'No NDVI history available for polyId=$agroPolyId',
        );
        return null;
      }

      // Most-recent entry
      final latest = list.last as Map<String, dynamic>;
      final ndviData =
          (latest['data'] as Map<String, dynamic>?) ?? {};
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
    } catch (e, st) {
      _log.e(
        'ClimateSatelliteService.fetchLatestNdvi: Error – $e',
        stackTrace: st,
      );
      return null;
    }
  }

  // ── Private helpers ─────────────────────────────────────────

  bool _isPlaceholderKey(String key) =>
      key.startsWith('YOUR_') || key.isEmpty;

  /// NDVI → vegetation health label (Agronica GIAS thresholds)
  String _ndviToHealth(double ndvi) {
    if (ndvi >= 0.60) return 'Excellent';
    if (ndvi >= 0.40) return 'Good';
    if (ndvi >= 0.20) return 'Fair';
    return 'Poor';
  }

  /// Simple linear model: NDVI ↑ → soil moisture ↑
  /// Calibrated for tropical coffee-growing regions.
  double _estimateSoilMoisture(double ndvi) =>
      ((ndvi * 85.0).clamp(0.0, 100.0));

  /// Simulated SatelliteData when AgroMonitoring key is absent.
  /// Useful during development / demo.
  SatelliteData _simulatedNdviData() {
    const ndvi = 0.52; // Typical healthy young coffee
    return SatelliteData(
      ndviScore: ndvi,
      vegetationHealth: _ndviToHealth(ndvi),
      soilMoistureIndex: _estimateSoilMoisture(ndvi),
      fetchedAt: DateTime.now(),
      dataSource: 'Simulated (configure AgroMonitoring key for live data)',
    );
  }
}

// ── String extension ────────────────────────────────────────────
extension _StringCapitalize on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}