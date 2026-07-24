// lib/screens/Weather Station/weather_station_screen.dart
//
// Full-detail view of live NuaSense weather station data, styled to match
// Coffeecore's existing Field Data pages (brown/cream palette).
//
// Unlike the farmer app, Coffeecore plots are plain string IDs with no GPS
// attached, so there's no "farm location" to derive a station from. Instead
// the user picks a NuaSense station directly via the switcher in the AppBar
// — the choice is saved (SharedPreferences + Firestore) and reused by
// WeatherStationInlinePanel wherever it's embedded elsewhere in the app.
//
// Sections:
//   1. Status bar (live / stale / offline)
//   2. Current conditions grid (temp, humidity, wind, rainfall, pressure, sunlight)
//   3. Agronomic advice cards (leaf wetness, spray window, VPD, ET₀)
//      — spray window uses NuaSense's own spray_quality_index/_label when
//      available (wind + delta-T + inversion risk combined).
//   4. 24-hour sparkline strip (temp + humidity)
//   5. Upcoming spray windows (48h outlook from GET /derived/forecast)
//   6. Pest pressure — coffee berry borer (featured), aphid, whitefly
//   7. Station switcher (AppBar) for accounts covering more than one station
//   8. About this data bottom sheet
//
// Import it directly:
//   import 'package:coffeecore/screens/Weather%20Station/weather_station_screen.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nuasense_service.dart';

class _C {
  static const darkBrown = Color(0xFF3C2F2F);
  static const brown = Color(0xFF4A2C2A);
  static const brownDeep = Color(0xFF2A1F1F);
  static const green = Color(0xFF3A5F0B);
  static const lightGreen = Color(0xFFEFF5E4);
  static const amber = Color(0xFFB8860B);
  static const lightAmber = Color(0xFFFFF3E0);
  static const red = Color(0xFFB71C1C);
  static const blue = Color(0xFF1565C0);
  static const pageBg = Color(0xFFF5E8C7);
  static const border = Color(0xFFDBC9AE);
}

class WeatherStationScreen extends StatefulWidget {
  const WeatherStationScreen({super.key});

  @override
  State<WeatherStationScreen> createState() => _WeatherStationScreenState();
}

class _WeatherStationScreenState extends State<WeatherStationScreen> {
  bool _loading = true;
  String? _error;
  NuaSenseReading? _reading;
  List<NuaSenseHourPoint> _history = [];
  List<NuaSenseForecastPoint> _forecast = [];

  String _userId = '';
  List<NuaStation> _stations = [];
  String? _selectedStationId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _init();
  }

  Future<void> _init() async {
    // Load the user's saved station choice first (if any) before the first
    // fetch, so we don't flash the default station and then swap.
    final saved = await NuaSenseService.loadSelectedStation(_userId);
    if (mounted) {
      setState(() {
        _selectedStationId = saved;
      });
    }
    await _load();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final stations = await NuaSenseService.getStations();
      if (!mounted) return;
      setState(() {
        _stations = stations;
      });
    } catch (_) {
      // Single-station accounts just get an empty list — switcher stays hidden.
    }
  }

  Future<void> _switchStation(String? stationId) async {
    setState(() {
      _selectedStationId = stationId;
      _loading = true;
    });
    await NuaSenseService.saveSelectedStation(_userId, stationId);
    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reading =
          await NuaSenseService.getLatestReading(stationId: _selectedStationId);
      final history =
          await NuaSenseService.get24hHistory(stationId: _selectedStationId);
      if (!mounted) return;
      setState(() {
        _reading = reading;
        _history = history;
        _loading = false;
      });
      _loadForecast();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadForecast() async {
    try {
      final forecast = await NuaSenseService.getSprayForecast(
          stationId: _selectedStationId, hours: 48);
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _forecast = [];
      });
    }
  }

  Future<void> _refresh() async {
    NuaSenseService.clearCache(stationId: _selectedStationId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.pageBg,
      appBar: AppBar(
        backgroundColor: _C.darkBrown,
        title: const Text('Weather Station',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_stations.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _StationSwitcherButton(
                stations: _stations,
                selectedStationId: _selectedStationId,
                onSelect: _switchStation,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showAboutSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _C.green,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.green))
            : _error != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(children: [
      const SizedBox(height: 120),
      const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.black26),
      const SizedBox(height: 12),
      const Center(
          child: Text('Could not load weather station data.',
              style: TextStyle(fontSize: 14, color: Colors.black54))),
      const SizedBox(height: 12),
      Center(
          child: ElevatedButton(
        onPressed: _load,
        style: ElevatedButton.styleFrom(
            backgroundColor: _C.green, foregroundColor: Colors.white),
        child: const Text('Retry'),
      )),
    ]);
  }

  Widget _buildContent() {
    final r = _reading!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusBar(r),
        const SizedBox(height: 14),
        _sectionLabel('Current conditions'),
        _buildConditionsGrid(r),
        const SizedBox(height: 16),
        _sectionLabel('Agronomic advice'),
        ..._buildAdviceCards(r),
        const SizedBox(height: 16),
        _sectionLabel('Last 24 hours'),
        _buildHistoryStrip(),
        const SizedBox(height: 16),
        _sectionLabel('Upcoming spray windows'),
        _buildForecastStrip(),
        const SizedBox(height: 16),
        _sectionLabel('Pest degree-day pressure'),
        _buildDegreeDaySection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _C.brown,
                letterSpacing: 0.3)),
      );

  // ── Status bar ─────────────────────────────────────────────────────────

  Widget _buildStatusBar(NuaSenseReading r) {
    final stale = r.isStale;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: stale ? _C.lightAmber : _C.lightGreen,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: stale
                ? _C.amber.withValues(alpha: 0.3)
                : _C.green.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(stale ? Icons.history_toggle_off_rounded : Icons.sensors_rounded,
            size: 16, color: stale ? _C.amber : _C.green),
        const SizedBox(width: 8),
        Text(stale ? 'Showing cached data' : 'Live station data',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: stale ? _C.amber : _C.green)),
        const Spacer(),
        Text('Updated ${_timeAgo(r.timestamp)}',
            style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
      ]),
    );
  }

  // ── Current conditions grid ───────────────────────────────────────────

  Widget _buildConditionsGrid(NuaSenseReading r) {
    final tiles = [
      _ConditionTile(Icons.thermostat_rounded, 'Air Temp',
          '${r.airTemp.toStringAsFixed(1)}°C'),
      _ConditionTile(Icons.water_drop_outlined, 'Humidity',
          '${r.humidity.toStringAsFixed(0)}%'),
      _ConditionTile(Icons.air_rounded, 'Wind',
          '${r.windSpeed.toStringAsFixed(1)} m/s ${r.windDirLabel}'),
      _ConditionTile(Icons.water_rounded, 'Rainfall',
          '${r.rainfall.toStringAsFixed(1)} mm'),
      _ConditionTile(Icons.speed_rounded, 'Pressure',
          '${r.airPressure.toStringAsFixed(0)} hPa'),
      _ConditionTile(Icons.wb_sunny_outlined, 'Sunlight',
          '${r.sunlight.toStringAsFixed(0)} lux'),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: tiles
          .map((t) => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon, size: 20, color: _C.brown),
                      const SizedBox(height: 6),
                      Text(t.value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _C.brown)),
                      const SizedBox(height: 2),
                      Text(t.label,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.black45)),
                    ]),
              ))
          .toList(),
    );
  }

  // ── Advice cards ───────────────────────────────────────────────────────

  List<Widget> _buildAdviceCards(NuaSenseReading r) {
    final cards = <Widget>[];

    // Leaf wetness (coffee leaf rust risk)
    cards.add(_AdviceCard(
      icon: r.leafIsWet
          ? Icons.grain_rounded
          : Icons.check_circle_outline_rounded,
      title: r.leafIsWet ? 'Leaf Wetness — Fungal Risk' : 'Leaf Wetness — Dry',
      color: r.leafIsWet ? _C.blue : _C.green,
      bullets: [
        r.leafIsWet
            ? 'Leaves are wet (${r.lwdReason.isNotEmpty ? r.lwdReason.replaceAll('_', ' ') : 'conditions indicate wetness'}). '
                'Coffee leaf rust and other fungal spores germinate more readily.'
            : 'Leaf surfaces are dry. Reduced fungal infection risk.',
        if (r.leafIsWet && r.lwdConsecutiveHours > 0)
          'Wet for ${r.lwdConsecutiveHours} consecutive hour'
              '${r.lwdConsecutiveHours == 1 ? '' : 's'}'
              '${r.lwdConsecutiveHours >= 6 ? ' — long unbroken wetness drives most infections.' : '.'}',
        'Dew point: ${r.dewPoint.toStringAsFixed(1)}°C  ·  '
            'Dew gap: ${r.dewPointDepression.toStringAsFixed(1)}°C'
            '${r.dewPointDepression <= 2 ? '  ⚠ Near-condensation' : ''}',
      ],
    ));

    // Spray window — prefer NuaSense's own combined score when present.
    if (r.sprayQualityLabel.isNotEmpty) {
      final good = r.sprayQualityGood;
      final marginal = r.sprayQualityMarginal;
      final color = good
          ? _C.green
          : marginal
              ? _C.amber
              : _C.red;
      final factorLabel = switch (r.sprayLimitingFactor) {
        'wind' => 'wind speed',
        'delta_t' => 'delta-T (droplets drying before landing)',
        'inversion' => 'a temperature inversion (drift hangs near the ground)',
        'rain' => 'rain',
        _ => r.sprayLimitingFactor,
      };
      cards.add(_AdviceCard(
        icon: good
            ? Icons.opacity_outlined
            : marginal
                ? Icons.warning_amber_rounded
                : Icons.not_interested_rounded,
        title:
            'Spray Window — ${r.sprayQualityLabel} (${r.sprayQualityIndex.toStringAsFixed(0)}/100)',
        color: color,
        bullets: [
          'Wind: ${r.windSpeed.toStringAsFixed(1)} m/s  ·  '
              'Delta-T: ${r.deltaT.toStringAsFixed(1)}°C'
              '${r.inversionRisk.isNotEmpty ? '  ·  Inversion risk: ${r.inversionRisk}' : ''}',
          if (!good && r.sprayLimitingFactor.isNotEmpty)
            'Main limiting factor: $factorLabel.',
          if (good)
            'Good conditions now for fungicide or foliar feed. Best held in early '
                'morning (6–9am) or late afternoon (4–5pm).'
          else if (marginal)
            'Usable but not ideal — expect some drift or faster evaporation.'
          else
            'Hold off. See "Upcoming spray windows" below for the next good stretch.',
        ],
      ));
    } else {
      final goodWind = r.goodSprayWind;
      final noRain = !r.rainingNow;
      final hour = DateTime.now().hour;
      final inWindow = hour >= 6 && hour <= 17;
      final goodSpray = goodWind && noRain && inWindow;
      cards.add(_AdviceCard(
        icon: goodSpray ? Icons.opacity_outlined : Icons.not_interested_rounded,
        title: goodSpray ? 'Spray Window — Safe Now' : 'Spray Window — Hold',
        color: goodSpray ? _C.green : _C.amber,
        bullets: [
          'Wind: ${r.windSpeed.toStringAsFixed(1)} m/s  ${goodWind ? "✓ Below 3 m/s" : "⚠ Too high — drift risk"}',
          'Rain: ${r.rainingNow ? "⚠ Currently raining — product washes off" : "✓ Dry conditions"}',
          if (!inWindow) '⚠ Outside typical spray hours (6am–5pm)',
          if (goodSpray)
            'Best spray time: early morning (6–9am) or late afternoon (4–5pm).',
        ],
      ));
    }

    // VPD / fertigation guidance
    final vpdOk = r.vpd >= 0.4 && r.vpd <= 1.6;
    cards.add(_AdviceCard(
      icon: Icons.eco_outlined,
      title: 'Vapour Pressure Deficit (VPD)',
      color: vpdOk ? _C.green : _C.amber,
      bullets: [
        'VPD: ${r.vpd.toStringAsFixed(2)} kPa',
        vpdOk
            ? 'Good uptake conditions for root or foliar feeding.'
            : r.vpd < 0.4
                ? 'Low VPD — plant water uptake slows; avoid over-watering.'
                : 'High VPD — plants may be under water stress; check soil moisture before feeding.',
        'ET₀ this hour: ${r.et0Hour.toStringAsFixed(2)} mm — use to guide irrigation scheduling.',
      ],
    ));

    return cards;
  }

  // ── 24h history strip ───────────────────────────────────────────────────

  Widget _buildHistoryStrip() {
    if (_history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: const Text('No history available yet.',
            style: TextStyle(fontSize: 12, color: Colors.black38)),
      );
    }

    final maxTemp =
        _history.map((p) => p.airTemp).reduce((a, b) => a > b ? a : b);
    final minTemp =
        _history.map((p) => p.airTemp).reduce((a, b) => a < b ? a : b);
    final range = (maxTemp - minTemp).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            'Air temperature range: ${minTemp.toStringAsFixed(1)}–${maxTemp.toStringAsFixed(1)}°C',
            style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _history.map((p) {
              final frac = ((p.airTemp - minTemp) / range).clamp(0.05, 1.0);
              final wet = p.lwdHour == 1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: (frac * 10).round().clamp(1, 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: (wet ? _C.blue : _C.amber)
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        const Text('amber = temperature bar, blue = leaf-wet hour',
            style: TextStyle(fontSize: 9.5, color: Colors.black38)),
      ]),
    );
  }

  // ── Upcoming spray windows (48h forecast) ───────────────────────────────

  Widget _buildForecastStrip() {
    if (_forecast.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: const Text('Forecast unavailable right now.',
            style: TextStyle(fontSize: 12, color: Colors.black38)),
      );
    }

    final nextWindow = NuaSenseService.nextGoodSprayWindow(_forecast);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (nextWindow != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _C.lightGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.event_available_rounded,
                  size: 15, color: _C.green),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Next good window: ${_hourLabel(nextWindow.start)}–'
                '${_hourLabel(nextWindow.end)}'
                '${nextWindow.start.day != DateTime.now().day ? ' (${nextWindow.start.day}/${nextWindow.start.month})' : ''}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _C.green),
              )),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
                'No clearly good spray window in the next '
                '${_forecast.length}h — conditions stay marginal or poor.',
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ),
        SizedBox(
          height: 46,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _forecast.take(24).map((p) {
              final frac = (p.sprayQualityIndex / 100).clamp(0.05, 1.0);
              final color = p.sprayQualityIndex >= 70
                  ? _C.green
                  : p.sprayQualityIndex >= 40
                      ? _C.amber
                      : _C.red;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: (frac * 10).round().clamp(1, 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
            'Next ${_forecast.take(24).length}h  ·  green = good, amber = marginal, red = poor',
            style: const TextStyle(fontSize: 9.5, color: Colors.black38)),
      ]),
    );
  }

  String _hourLabel(DateTime dt) {
    final h = dt.hour;
    final ampm = h >= 12 ? 'pm' : 'am';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12$ampm';
  }

  // ── Pest degree-day pressure ────────────────────────────────────────────

  Widget _buildDegreeDaySection() {
    final r = _reading!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Temperature-based. Higher values = pests developing faster. '
          'Scout immediately at medium or high pressure.',
          style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 12),
        const Text('Coffee berry borer (featured)',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
                letterSpacing: 0.4)),
        const SizedBox(height: 8),
        _ddTile(
            'Coffee berry borer pressure',
            r.ddCbbHour,
            0.2,
            0.5,
            'Coffee only — small holes bored into ripening berries; scout weekly during fruiting',
            Icons.bug_report_outlined),
        const SizedBox(height: 8),
        const Text('General pests',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
                letterSpacing: 0.4)),
        const SizedBox(height: 8),
        _ddTile(
            'Aphid pressure',
            r.ddAphidHour,
            0.5,
            1.2,
            'Base 4.3°C — develops faster in warm humid conditions, check new growth',
            Icons.pest_control_outlined),
        _ddTile(
            'Whitefly pressure',
            r.ddWhiteflyHour,
            0.3,
            0.8,
            'Base 10°C — thrives in hot dry weather above 25°C, watch for sooty mould',
            Icons.pest_control_outlined),
      ]),
    );
  }

  Widget _ddTile(String label, double value, double medThresh,
      double highThresh, String description, IconData icon) {
    final level = value >= highThresh
        ? 2
        : value >= medThresh
            ? 1
            : 0;
    final color = level == 2
        ? _C.red
        : level == 1
            ? _C.amber
            : _C.green;
    final levelLabel = level == 2
        ? 'High'
        : level == 1
            ? 'Medium'
            : 'Low';
    final frac = (value / (highThresh * 1.4)).clamp(0.04, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _C.brown))),
          Text(levelLabel,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 3),
        Text(description,
            style: const TextStyle(fontSize: 10.5, color: Colors.black45)),
      ]),
    );
  }

  // ── About sheet ─────────────────────────────────────────────────────────

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('About this data',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _C.brownDeep)),
            const SizedBox(height: 14),
            _aboutRow(
                Icons.sensors_rounded,
                'Data source',
                'Live readings from a NuaSense weather station, fetched through a '
                    'Firebase Cloud Function that keeps the partner API key private.'),
            _aboutRow(
                Icons.refresh_rounded,
                'Update frequency',
                'Readings are cached for 10 minutes on-device to stay within the '
                    'API\'s daily call allowance. Pull down to force a refresh.'),
            _aboutRow(
                Icons.speed_rounded,
                'Spray quality score',
                'A single 0–100 score combining wind speed, delta-T (droplet '
                    'drying risk) and temperature-inversion risk, provided directly '
                    'by the station.'),
            _aboutRow(
                Icons.water_drop_outlined,
                'Leaf wetness (LWD)',
                'Computed hourly. A leaf-wet hour occurs when humidity is high, '
                    'dew-point depression is ≤2°C, or rainfall is recorded. '
                    'Consecutive wet hours drive most fungal infections, including '
                    'coffee leaf rust.'),
            _aboutRow(
                Icons.event_available_rounded,
                'Forecast',
                'Projects the signals above up to 7 days ahead, so you can plan '
                    'spraying rather than only reacting to current conditions.'),
            _aboutRow(
                Icons.bug_report_outlined,
                'Degree-days',
                'Temperature above a pest\'s threshold, accumulated per hour. '
                    'Coffee berry borer is Coffeecore\'s dedicated pest signal; '
                    'aphid and whitefly are shown as general secondary pressure.'),
            if (_stations.length > 1)
              _aboutRow(
                  Icons.compare_arrows_rounded,
                  'Multiple stations',
                  'Your account covers more than one NuaSense station. Use the '
                      'switcher at the top of this screen to change which one this '
                      'data comes from.'),
          ]),
        ),
      ),
    );
  }

  Widget _aboutRow(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: _C.green),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _C.brown)),
          const SizedBox(height: 2),
          Text(body,
              style: const TextStyle(
                  fontSize: 12, color: Colors.black54, height: 1.4)),
        ])),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Small value classes ───────────────────────────────────────────────────

class _ConditionTile {
  final IconData icon;
  final String label;
  final String value;
  const _ConditionTile(this.icon, this.label, this.value);
}

class _AdviceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> bullets;

  const _AdviceCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: color))),
        ]),
        const SizedBox(height: 7),
        for (final b in bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('•  $b',
                style: const TextStyle(
                    fontSize: 12.5, color: Colors.black87, height: 1.4)),
          ),
      ]),
    );
  }
}

// ── Station-switcher button ─────────────────────────────────────────────────
// Compact pill in the AppBar that opens a bottom sheet listing every station
// the account owns (from GET /stations), with online/offline status.

class _StationSwitcherButton extends StatelessWidget {
  final List<NuaStation> stations;
  final String? selectedStationId;
  final void Function(String? stationId) onSelect;

  const _StationSwitcherButton({
    required this.stations,
    required this.selectedStationId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final current =
        stations.where((s) => s.id == selectedStationId).firstOrNull ??
            stations.firstOrNull;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sensors_rounded,
              size: 14,
              color: current?.online == true ? Colors.white : Colors.white54),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              current?.name ?? 'Station',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.expand_more, size: 14, color: Colors.white70),
        ]),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('Switch weather station',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _C.brownDeep)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                  'Choose which of your NuaSense stations to read from.',
                  style: TextStyle(
                      fontSize: 12.5, color: Colors.black54, height: 1.4)),
            ),
            const Divider(height: 1),
            ...stations.map((s) {
              final isSelected = s.id == selectedStationId ||
                  (selectedStationId == null && s == stations.first);
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? _C.lightGreen : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sensors_rounded,
                    size: 18,
                    color: !s.online
                        ? Colors.grey
                        : isSelected
                            ? _C.green
                            : Colors.black54,
                  ),
                ),
                title: Text(s.name,
                    style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected ? _C.brownDeep : Colors.black87)),
                subtitle: Text(
                  s.online ? 'Online' : 'Offline',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: s.online ? Colors.black54 : _C.red),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: _C.green, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelect(s.id);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
