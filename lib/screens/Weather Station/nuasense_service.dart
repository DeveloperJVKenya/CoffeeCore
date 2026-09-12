// lib/screens/Weather Station/nuasense_service.dart
//
// Everything the Weather Station feature needs to talk to NuaSense lives in
// this one folder (screens/Weather Station/) — service, screen, and inline
// panel — so there's a single place to look, and a single import path to
// remember from the rest of Coffeecore:
//
//   import 'package:coffeecore/screens/Weather%20Station/nuasense_service.dart';
//   import 'package:coffeecore/screens/Weather%20Station/weather_station_screen.dart';
//   import 'package:coffeecore/screens/Weather%20Station/weather_station_inline_panel.dart';
//
// This service calls the `getNuaSenseData` Firebase Cloud Function, which
// proxies to the NuaSense Partner API (key stored server-side in Secret
// Manager — see functions/index.js). It ships with the full July 2026
// NuaSense API surface:
//   • Crop-specific degree-day accumulators — Coffeecore gets dd_cbb_hour
//     (coffee berry borer) plus the general pest set.
//   • lwd_consecutive_hours — running count of unbroken wet hours.
//   • Full spray-quality block: spray_quality_index / _label /
//     _limiting_factor, plus delta_t and inversion_risk.
//   • Multi-station support: GET /stations + ?gateway_id= on every call —
//     useful here since a Coffeecore account may cover more than one
//     partner farm/station.
//   • GET /derived/forecast — up to 7 days ahead, incl. spray-quality outlook.
//
// Call pattern:
//   final reading  = await NuaSenseService.getLatestReading();
//   final history  = await NuaSenseService.get24hHistory();
//   final stations = await NuaSenseService.getStations();
//   final forecast = await NuaSenseService.getSprayForecast();
//
// Cache: readings are cached per-station for 10 minutes to respect the
// 2,000/day call allowance. clearCache() is called from the weather station
// screen's refresh button.
//
// Station selection persistence: unlike the farmer app, Coffeecore plots
// are plain string IDs with no GPS attached, so there's no "farm location"
// to key weather off. Instead the user just picks a NuaSense station
// directly (see [saveSelectedStation] / [loadSelectedStation]) — saved to
// SharedPreferences for instant reads and mirrored to Firestore so the
// choice follows the user across devices.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Data model ─────────────────────────────────────────────────────────────

class NuaSenseReading {
  /// Air temperature (°C) — from weather metric air_temperature
  final double airTemp;

  /// Relative humidity (%) — from weather metric humidity
  final double humidity;

  /// Cumulative rainfall (mm) — from weather metric rainfall
  final double rainfall;

  /// Wind speed (m/s)
  final double windSpeed;

  /// Wind gusts (m/s)
  final double windGusts;

  /// Wind direction (degrees, 0 = North)
  final double windDirection;

  /// Sunlight (lux)
  final double sunlight;

  /// Air pressure (hPa)
  final double airPressure;

  // ── Derived agronomic fields ───────────────────────────────────────────

  /// Dew point temperature (°C)
  final double dewPoint;

  /// Dew point depression (°C) — ≤ 2 °C signals condensation / leaf wetness
  final double dewPointDepression;

  /// Vapour pressure deficit (kPa) — crop water-stress indicator
  final double vpd;

  /// FAO-56 reference evapotranspiration for this hour (mm/h)
  final double et0Hour;

  /// Leaf wetness flag (1 = wet, 0 = dry)
  final int lwdHour;

  /// Which rule triggered leaf wetness: 'rainfall' | 'dpd' | 'night_condensation' | ''
  final String lwdReason;

  /// Running count of unbroken wet hours. Long unbroken runs matter far
  /// more for coffee leaf rust (CLR) and berry disease risk than any
  /// single wet hour.
  final int lwdConsecutiveHours;

  /// 6-hour barometric trend (hPa, + rising / - falling)
  final double pressureTrend6h;

  // ── Spray-quality block ─────────────────────────────────────────────────

  /// Spray quality index, 0–100 — NuaSense's combined wind, delta-T and
  /// inversion-risk score. Prefer this over hand-rolled wind/rain checks.
  final double sprayQualityIndex;

  /// Human-readable label for [sprayQualityIndex], e.g. "Good", "Marginal",
  /// "Poor" — straight from the API.
  final String sprayQualityLabel;

  /// What's currently capping the spray quality score:
  /// 'wind' | 'delta_t' | 'inversion' | 'rain' | ''
  final String sprayLimitingFactor;

  /// Delta T (°C) — wet-bulb depression used for spray drift/evaporation risk.
  final double deltaT;

  /// Temperature-inversion risk label (low / moderate / high) — relevant
  /// for early-morning and evening spraying, when drift can hang low.
  final String inversionRisk;

  // ── General pest degree-days ────────────────────────────────────────────

  /// Coffee aphid degree-days (base 4.3 °C)
  final double ddAphidHour;

  /// Whitefly degree-days (base 10 °C, cap 32 °C) — coffee whitefly included
  final double ddWhiteflyHour;

  // ── Coffee-specific pest degree-days ────────────────────────────────────

  /// Coffee berry borer (CBB) degree-days — Coffeecore catalog, added to
  /// the NuaSense API specifically to support this app.
  final double ddCbbHour;

  /// Timestamp of the most recent data point
  final DateTime timestamp;

  /// Whether this is cached / stale data (> 10 min old)
  final bool isStale;

  const NuaSenseReading({
    required this.airTemp,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
    required this.windGusts,
    required this.windDirection,
    required this.sunlight,
    required this.airPressure,
    required this.dewPoint,
    required this.dewPointDepression,
    required this.vpd,
    required this.et0Hour,
    required this.lwdHour,
    required this.lwdReason,
    required this.lwdConsecutiveHours,
    required this.pressureTrend6h,
    required this.sprayQualityIndex,
    required this.sprayQualityLabel,
    required this.sprayLimitingFactor,
    required this.deltaT,
    required this.inversionRisk,
    required this.ddAphidHour,
    required this.ddWhiteflyHour,
    required this.ddCbbHour,
    required this.timestamp,
    this.isStale = false,
  });

  /// Returns a safe zero-value reading — used when station is offline.
  factory NuaSenseReading.empty() => NuaSenseReading(
        airTemp: 0,
        humidity: 0,
        rainfall: 0,
        windSpeed: 0,
        windGusts: 0,
        windDirection: 0,
        sunlight: 0,
        airPressure: 0,
        dewPoint: 0,
        dewPointDepression: 99,
        vpd: 0,
        et0Hour: 0,
        lwdHour: 0,
        lwdReason: '',
        lwdConsecutiveHours: 0,
        pressureTrend6h: 0,
        sprayQualityIndex: 0,
        sprayQualityLabel: '',
        sprayLimitingFactor: '',
        deltaT: 0,
        inversionRisk: '',
        ddAphidHour: 0,
        ddWhiteflyHour: 0,
        ddCbbHour: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        isStale: true,
      );

  bool get leafIsWet => lwdHour == 1;
  bool get goodSprayWind => windSpeed < 3.0;
  bool get rainingNow => rainfall > 0.1;

  /// True once NuaSense's own combined score calls it a good spray window.
  /// Prefer this over [goodSprayWind] wherever the spray-quality block is
  /// available — it accounts for delta-T and inversion risk too.
  bool get sprayQualityGood => sprayQualityIndex >= 70;
  bool get sprayQualityMarginal =>
      sprayQualityIndex >= 40 && sprayQualityIndex < 70;

  String get windDirLabel {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((windDirection + 22.5) / 45).floor() % 8];
  }
}

// ── 24-hour history point ──────────────────────────────────────────────────

class NuaSenseHourPoint {
  final DateTime time;
  final double airTemp;
  final double humidity;
  final double rainfall;
  final double windSpeed;
  final double et0Hour;
  final int lwdHour;

  const NuaSenseHourPoint({
    required this.time,
    required this.airTemp,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
    required this.et0Hour,
    required this.lwdHour,
  });
}

// ── Station (multi-station support) ─────────────────────────────────────────

class NuaStation {
  final String id; // gateway_id
  final String name;
  final double? lat;
  final double? lon;
  final DateTime? lastSeen;
  final bool online;

  const NuaStation({
    required this.id,
    required this.name,
    this.lat,
    this.lon,
    this.lastSeen,
    required this.online,
  });

  factory NuaStation.fromJson(Map<String, dynamic> j) => NuaStation(
        id: j['gateway_id']?.toString() ?? j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? j['location']?.toString() ?? 'Station',
        lat: (j['lat'] as num?)?.toDouble() ??
            (j['latitude'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble() ??
            (j['longitude'] as num?)?.toDouble(),
        lastSeen: DateTime.tryParse(j['last_seen']?.toString() ?? ''),
        online: j['online'] == true || j['status']?.toString() == 'online',
      );
}

// ── Forecast point ────────────────────────────────────────────────────────
// GET /derived/forecast projects spray quality (and other signals) up to
// 7 days ahead. We surface the spray-quality outlook — enough to answer
// "when's my next good spray/fertigation window?"

class NuaSenseForecastPoint {
  final DateTime time;
  final double sprayQualityIndex;
  final String sprayQualityLabel;

  const NuaSenseForecastPoint({
    required this.time,
    required this.sprayQualityIndex,
    required this.sprayQualityLabel,
  });

  bool get isGoodSprayWindow => sprayQualityIndex >= 70;
}

// ── Service ────────────────────────────────────────────────────────────────

class NuaSenseService {
  NuaSenseService._();

  // Cache — keyed by stationId ('' = default/demo gateway) so switching
  // between stations doesn't show stale data from another one. Current
  // conditions and 24h history are cached (and fetched) independently: the
  // inline panel dropped into other screens (soil forms, dashboard menus)
  // only ever needs [getLatestReading] and has no chart, so it shouldn't
  // pay for the two 24h-history queries every time — those only matter to
  // the full Weather Station screen.
  static final Map<String, NuaSenseReading> _cachedReadings = {};
  static final Map<String, List<NuaSenseHourPoint>> _cachedHistories = {};
  static final Map<String, DateTime> _cachedAtCurrent = {};
  static final Map<String, DateTime> _cachedAtHistory = {};
  static const _cacheDuration = Duration(minutes: 10);

  static String _key(String? stationId) => stationId ?? '';

  static bool _cacheValid(Map<String, DateTime> cachedAt, String key) =>
      cachedAt[key] != null &&
      DateTime.now().difference(cachedAt[key]!) < _cacheDuration;

  /// Clears cache. Pass [stationId] to clear just one station's cache,
  /// or omit to clear everything.
  static void clearCache({String? stationId}) {
    if (stationId == null) {
      _cachedReadings.clear();
      _cachedHistories.clear();
      _cachedAtCurrent.clear();
      _cachedAtHistory.clear();
    } else {
      final key = _key(stationId);
      _cachedReadings.remove(key);
      _cachedHistories.remove(key);
      _cachedAtCurrent.remove(key);
      _cachedAtHistory.remove(key);
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetches the latest reading (current hour, weather + derived fields).
  /// Returns cached value if < 10 minutes old. Only fetches the 2 "current"
  /// queries — not the 24h-history ones [get24hHistory] needs — so callers
  /// that just want current conditions (e.g. [WeatherStationInlinePanel])
  /// aren't paying for a chart they don't render.
  static Future<NuaSenseReading> getLatestReading({String? stationId}) async {
    final key = _key(stationId);
    if (_cacheValid(_cachedAtCurrent, key) && _cachedReadings[key] != null) {
      return _cachedReadings[key]!.copyWith(isStale: true);
    }
    await _fetchCurrent(stationId: stationId);
    return _cachedReadings[key] ?? NuaSenseReading.empty();
  }

  /// Fetches hourly history for the last 24 hours.
  static Future<List<NuaSenseHourPoint>> get24hHistory(
      {String? stationId}) async {
    final key = _key(stationId);
    if (_cacheValid(_cachedAtHistory, key) && _cachedHistories[key] != null) {
      return _cachedHistories[key]!;
    }
    await _fetchHistory(stationId: stationId);
    return _cachedHistories[key] ?? [];
  }

  /// Lists every station this account's API key owns — location, last-seen,
  /// online status. Powers the station switcher.
  static Future<List<NuaStation>> getStations() async {
    final res = await _call('stations', {});
    final list = (res['stations'] as List?) ?? (res['data'] as List?) ?? [];
    return list
        .whereType<Map>()
        .map((s) => NuaStation.fromJson(Map<String, dynamic>.from(s)))
        .toList();
  }

  /// Spray-quality outlook for the coming hours (up to 7 days / 168h).
  static Future<List<NuaSenseForecastPoint>> getSprayForecast({
    String? stationId,
    int hours = 48,
  }) async {
    final res = await _call('derived/forecast', {
      'fields': 'spray_quality_index,spray_quality_label',
      'hours': '$hours',
      if (stationId != null) 'gateway_id': stationId,
    });
    final pts = (res['points'] as List?) ?? [];
    return pts.whereType<Map>().map((p) {
      final map = Map<String, dynamic>.from(p);
      final dt = DateTime.tryParse(
              map['time']?.toString() ?? map['x']?.toString() ?? '') ??
          DateTime.now();
      return NuaSenseForecastPoint(
        time: dt,
        sprayQualityIndex:
            (map['spray_quality_index'] as num?)?.toDouble() ?? 0.0,
        sprayQualityLabel: map['spray_quality_label']?.toString() ?? '',
      );
    }).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Convenience: the next upcoming stretch of good (>=70) spray-quality
  /// hours from a forecast list, or null if none in range.
  static ({DateTime start, DateTime end})? nextGoodSprayWindow(
      List<NuaSenseForecastPoint> forecast) {
    DateTime? start;
    for (var i = 0; i < forecast.length; i++) {
      final p = forecast[i];
      if (p.isGoodSprayWindow) {
        start ??= p.time;
        final isLast = i == forecast.length - 1;
        final nextBreaks = !isLast && !forecast[i + 1].isGoodSprayWindow;
        if (isLast || nextBreaks) {
          return (start: start, end: p.time);
        }
      } else {
        start = null;
      }
    }
    return null;
  }

  // ── Station selection persistence ─────────────────────────────────────────
  // Coffeecore plots are plain string IDs with no GPS, so there's no farm
  // location to derive a station from — the user just picks one. Saved
  // locally for instant reads on next launch, and mirrored to Firestore so
  // the choice follows the account across devices (same dual-persistence
  // pattern used elsewhere in the app).

  static const _prefsKey = 'coffeecore_selected_weather_station_id';

  static Future<void> saveSelectedStation(String uid, String? stationId) async {
    final prefs = await SharedPreferences.getInstance();
    if (stationId == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, stationId);
    }
    if (uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('weatherStation')
          .set({
        'selectedStationId': stationId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Local save already succeeded — Firestore mirror is best-effort.
    }
  }

  static Future<String?> loadSelectedStation(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_prefsKey);
    if (local != null) return local;
    if (uid.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('weatherStation')
          .get();
      final remote = doc.data()?['selectedStationId'] as String?;
      if (remote != null) {
        await prefs.setString(_prefsKey, remote);
      }
      return remote;
    } catch (_) {
      return null;
    }
  }

  // ── Internal fetch ────────────────────────────────────────────────────────
  // Split into "current" (2 queries) and "history" (2 queries), each its own
  // batched callable invocation, so a caller that only wants current
  // conditions — [WeatherStationInlinePanel], dropped into menus and forms —
  // never fetches the 24h-history queries it has nowhere to show. The full
  // Weather Station screen wants both, and fetches them concurrently (see
  // weather_station_screen.dart's _load) so it pays for one round trip's
  // worth of latency, not two sequential ones.

  static double _lastVal(Map<String, dynamic> resp, String metricId) {
    final series = (resp['series'] as List?)
        ?.firstWhere((s) => s['id'] == metricId, orElse: () => null);
    if (series == null) return 0.0;
    final pts = series['data'] as List?;
    if (pts == null || pts.isEmpty) return 0.0;
    return (pts.last['y'] as num?)?.toDouble() ?? 0.0;
  }

  static DateTime _lastTime(Map<String, dynamic> resp) {
    final series = (resp['series'] as List?)?.firstOrNull;
    final pts = series?['data'] as List?;
    if (pts == null || pts.isEmpty) return DateTime.now();
    final ts = pts.last['x'] as String? ?? '';
    return DateTime.tryParse(ts) ?? DateTime.now();
  }

  static double _derivedVal(Map<String, dynamic> resp, String field) {
    final pts = resp['points'] as List?;
    if (pts == null || pts.isEmpty) return 0.0;
    return (pts.last[field] as num?)?.toDouble() ?? 0.0;
  }

  static int _derivedInt(Map<String, dynamic> resp, String field) =>
      _derivedVal(resp, field).round();

  static String _derivedStr(Map<String, dynamic> resp, String field) {
    final pts = resp['points'] as List?;
    if (pts == null || pts.isEmpty) return '';
    return pts.last[field]?.toString() ?? '';
  }

  static Future<void> _fetchCurrent({String? stationId}) async {
    final gatewayParam =
        stationId != null ? {'gateway_id': stationId} : <String, String>{};

    final results = await _callBatch([
      (
        endpoint: 'weather',
        params: {
          'metrics': 'air_temperature,humidity,rainfall,wind_speed,wind_gusts,'
              'wind_direction,sunlight,air_pressure',
          'start': '-2h',
          'resolution': 'hourly',
          'aggregate': 'last',
          ...gatewayParam,
        },
      ),
      (
        endpoint: 'derived',
        params: {
          'fields': 'dew_point,dew_point_depression,vpd,et0_hour,'
              'lwd_hour,lwd_reason,lwd_consecutive_hours,pressure_trend_6h,'
              'spray_quality_index,spray_quality_label,spray_limiting_factor,'
              'delta_t,inversion_risk,'
              'dd_aphid_hour,dd_whitefly_hour,dd_cbb_hour',
          'start': '-2h',
          ...gatewayParam,
        },
      ),
    ]);

    final weatherNow = results[0];
    final derivedNow = results[1];
    final key = _key(stationId);

    _cachedReadings[key] = NuaSenseReading(
      airTemp: _lastVal(weatherNow, 'air_temperature'),
      humidity: _lastVal(weatherNow, 'humidity'),
      rainfall: _lastVal(weatherNow, 'rainfall'),
      windSpeed: _lastVal(weatherNow, 'wind_speed'),
      windGusts: _lastVal(weatherNow, 'wind_gusts'),
      windDirection: _lastVal(weatherNow, 'wind_direction'),
      sunlight: _lastVal(weatherNow, 'sunlight'),
      airPressure: _lastVal(weatherNow, 'air_pressure'),
      dewPoint: _derivedVal(derivedNow, 'dew_point'),
      dewPointDepression: _derivedVal(derivedNow, 'dew_point_depression'),
      vpd: _derivedVal(derivedNow, 'vpd'),
      et0Hour: _derivedVal(derivedNow, 'et0_hour'),
      lwdHour: _derivedInt(derivedNow, 'lwd_hour'),
      lwdReason: _derivedStr(derivedNow, 'lwd_reason'),
      lwdConsecutiveHours: _derivedInt(derivedNow, 'lwd_consecutive_hours'),
      pressureTrend6h: _derivedVal(derivedNow, 'pressure_trend_6h'),
      sprayQualityIndex: _derivedVal(derivedNow, 'spray_quality_index'),
      sprayQualityLabel: _derivedStr(derivedNow, 'spray_quality_label'),
      sprayLimitingFactor: _derivedStr(derivedNow, 'spray_limiting_factor'),
      deltaT: _derivedVal(derivedNow, 'delta_t'),
      inversionRisk: _derivedStr(derivedNow, 'inversion_risk'),
      ddAphidHour: _derivedVal(derivedNow, 'dd_aphid_hour'),
      ddWhiteflyHour: _derivedVal(derivedNow, 'dd_whitefly_hour'),
      ddCbbHour: _derivedVal(derivedNow, 'dd_cbb_hour'),
      timestamp: _lastTime(weatherNow),
      isStale: false,
    );
    _cachedAtCurrent[key] = DateTime.now();
  }

  static Future<void> _fetchHistory({String? stationId}) async {
    final gatewayParam =
        stationId != null ? {'gateway_id': stationId} : <String, String>{};

    final results = await _callBatch([
      (
        endpoint: 'weather',
        params: {
          'metrics': 'air_temperature,humidity,rainfall,wind_speed',
          'start': '-24h',
          'resolution': 'hourly',
          'aggregate': 'mean',
          ...gatewayParam,
        },
      ),
      (
        endpoint: 'derived',
        params: {
          'fields': 'et0_hour,lwd_hour',
          'start': '-24h',
          ...gatewayParam,
        },
      ),
    ]);

    final weatherHist = results[0];
    final derivedHist = results[1];
    final key = _key(stationId);

    final Map<String, Map<String, double>> byTime = {};

    void addSeries(Map<String, dynamic> resp, String metricId) {
      final series = (resp['series'] as List?)
          ?.firstWhere((s) => s['id'] == metricId, orElse: () => null);
      if (series == null) return;
      for (final pt in (series['data'] as List? ?? [])) {
        final t = pt['x'] as String? ?? '';
        byTime.putIfAbsent(t, () => {})[metricId] =
            (pt['y'] as num?)?.toDouble() ?? 0.0;
      }
    }

    void addDerived(Map<String, dynamic> resp, List<String> fields) {
      for (final pt in (resp['points'] as List? ?? [])) {
        final t = pt['time'] as String? ?? '';
        for (final f in fields) {
          byTime.putIfAbsent(t, () => {})[f] =
              (pt[f] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    addSeries(weatherHist, 'air_temperature');
    addSeries(weatherHist, 'humidity');
    addSeries(weatherHist, 'rainfall');
    addSeries(weatherHist, 'wind_speed');
    addDerived(derivedHist, ['et0_hour', 'lwd_hour']);

    _cachedHistories[key] = byTime.entries
        .map((e) {
          final dt = DateTime.tryParse(e.key);
          if (dt == null) return null;
          final v = e.value;
          return NuaSenseHourPoint(
            time: dt,
            airTemp: v['air_temperature'] ?? 0,
            humidity: v['humidity'] ?? 0,
            rainfall: v['rainfall'] ?? 0,
            windSpeed: v['wind_speed'] ?? 0,
            et0Hour: v['et0_hour'] ?? 0,
            lwdHour: (v['lwd_hour'] ?? 0).round(),
          );
        })
        .whereType<NuaSenseHourPoint>()
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    _cachedAtHistory[key] = DateTime.now();
  }

  // ── Firebase call ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _call(
    String endpoint,
    Map<String, String> params,
  ) async {
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('getNuaSenseData');
      final res = await fn.call({'endpoint': endpoint, 'params': params});
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      // Return empty structure so callers degrade gracefully
      return {};
    }
  }

  /// Runs several NuaSense queries in a single callable invocation — the
  /// Cloud Function fans them out server-side in parallel — instead of one
  /// invocation per query. Falls back to individual [_call]s (still run
  /// concurrently client-side) if the deployed function doesn't support
  /// batch mode yet, so a mid-rollout mismatch degrades gracefully rather
  /// than breaking the screen.
  static Future<List<Map<String, dynamic>>> _callBatch(
    List<({String endpoint, Map<String, String> params})> requests,
  ) async {
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('getNuaSenseData');
      final res = await fn.call({
        'endpoint': 'batch',
        'requests': [
          for (final r in requests)
            {'endpoint': r.endpoint, 'params': r.params},
        ],
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final results = data['results'] as List?;
      if (results == null) return List.filled(requests.length, {});
      return results
          .map((r) => Map<String, dynamic>.from(r as Map? ?? {}))
          .toList();
    } catch (e) {
      return Future.wait(
        requests.map((r) => _call(r.endpoint, r.params)),
      );
    }
  }
}

// ── Extension for copyWith ─────────────────────────────────────────────────
extension _NuaSenseCopy on NuaSenseReading {
  NuaSenseReading copyWith({bool? isStale}) => NuaSenseReading(
        airTemp: airTemp,
        humidity: humidity,
        rainfall: rainfall,
        windSpeed: windSpeed,
        windGusts: windGusts,
        windDirection: windDirection,
        sunlight: sunlight,
        airPressure: airPressure,
        dewPoint: dewPoint,
        dewPointDepression: dewPointDepression,
        vpd: vpd,
        et0Hour: et0Hour,
        lwdHour: lwdHour,
        lwdReason: lwdReason,
        lwdConsecutiveHours: lwdConsecutiveHours,
        pressureTrend6h: pressureTrend6h,
        sprayQualityIndex: sprayQualityIndex,
        sprayQualityLabel: sprayQualityLabel,
        sprayLimitingFactor: sprayLimitingFactor,
        deltaT: deltaT,
        inversionRisk: inversionRisk,
        ddAphidHour: ddAphidHour,
        ddWhiteflyHour: ddWhiteflyHour,
        ddCbbHour: ddCbbHour,
        timestamp: timestamp,
        isStale: isStale ?? this.isStale,
      );
}
