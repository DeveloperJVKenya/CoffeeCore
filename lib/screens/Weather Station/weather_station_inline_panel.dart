// lib/screens/Weather Station/weather_station_inline_panel.dart
//
// Compact NuaSense weather widget meant to be dropped inline into other
// Coffeecore screens (e.g. CoffeeSoilInputPage / CoffeeSoilForm) so a
// farmer/agronomist sees live conditions right where they're already
// working, instead of having to navigate to a separate weather screen.
//
// Import it directly:
//   import 'package:coffeecore/screens/Weather%20Station/weather_station_inline_panel.dart';
//
//   const WeatherStationInlinePanel(
//     showDegreeDays: true,
//     showFertiliser: true,
//   ),
//
// Sections shown:
//   • Status bar (live / stale)
//   • 3-metric mini-grid (air temp, humidity, wind)
//   • Spray/application window card — driven by NuaSense's own
//     spray_quality_index/_label/_limiting_factor when available, with a
//     wind/rain heuristic fallback. Doubles as guidance for foliar feed
//     and fungicide timing, both relevant to the soil/nutrient flows this
//     sits inside.
//   • Leaf wetness card (coffee leaf rust risk) — shows consecutive wet
//     hours, since long unbroken wet runs matter far more than a single
//     wet hour.
//   • Pest pressure strip — coffee berry borer (featured), plus aphid and
//     whitefly as general secondary pressure.
//   • "Full station data →" link to WeatherStationScreen
//
// Parameters:
//   [showDegreeDays] – set false to hide the pest-pressure strip (e.g. in
//                      a context that's purely about soil chemistry)
//   [showFertiliser] – set false to hide the foliar-feed timing note
//   [stationId]      – pass a specific NuaSense station id to override the
//                      user's saved default (rarely needed — the panel
//                      loads the saved selection itself otherwise)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nuasense_service.dart';
import 'weather_station_screen.dart';

class _C {
  static const brown = Color(0xFF4A2C2A);
  static const green = Color(0xFF3A5F0B);
  static const amber = Color(0xFFB8860B);
  static const red = Color(0xFFB71C1C);
  static const blue = Color(0xFF1565C0);
  static const lightBlue = Color(0xFFF0F4FF);
  static const cardBg = Color(0xFFF0E4D7);
  static const border = Color(0xFFDBC9AE);
}

class WeatherStationInlinePanel extends StatefulWidget {
  final bool showDegreeDays;
  final bool showFertiliser;
  final String? stationId;

  const WeatherStationInlinePanel({
    super.key,
    this.showDegreeDays = true,
    this.showFertiliser = true,
    this.stationId,
  });

  @override
  State<WeatherStationInlinePanel> createState() =>
      _WeatherStationInlinePanelState();
}

class _WeatherStationInlinePanelState extends State<WeatherStationInlinePanel> {
  bool _loading = true;
  String? _error;
  NuaSenseReading? _reading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var stationId = widget.stationId;
      if (stationId == null) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        stationId = await NuaSenseService.loadSelectedStation(uid);
      }
      final reading =
          await NuaSenseService.getLatestReading(stationId: stationId);
      if (!mounted) return;
      setState(() {
        _reading = reading;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _shell(const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
            child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: _C.green),
        )),
      ));
    }
    if (_error != null || _reading == null) {
      return _shell(Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: Colors.black38),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Weather station data unavailable right now.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54))),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      ));
    }

    final r = _reading!;
    return _shell(Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _statusBar(r),
        const SizedBox(height: 10),
        _miniGrid(r),
        const SizedBox(height: 10),
        _sprayWindowCard(r),
        const SizedBox(height: 8),
        _leafWetnessCard(r),
        if (widget.showFertiliser) ...[
          const SizedBox(height: 8),
          _fertiliserNote(r),
        ],
        if (widget.showDegreeDays) ...[
          const SizedBox(height: 10),
          _pestPressureStrip(r),
        ],
        const SizedBox(height: 8),
        _fullDataLink(),
      ]),
    ));
  }

  Widget _shell(Widget child) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: child,
      );

  Widget _statusBar(NuaSenseReading r) {
    final stale = r.isStale;
    return Row(children: [
      Icon(stale ? Icons.history_toggle_off_rounded : Icons.sensors_rounded,
          size: 14, color: stale ? Colors.black38 : _C.green),
      const SizedBox(width: 6),
      Text(stale ? 'Cached reading' : 'Live station data',
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: stale ? Colors.black45 : _C.green)),
      const Spacer(),
      Text(_timeAgo(r.timestamp),
          style: const TextStyle(fontSize: 11, color: Colors.black38)),
    ]);
  }

  Widget _miniGrid(NuaSenseReading r) {
    Widget tile(IconData icon, String label, String value) => Expanded(
          child: Column(children: [
            Icon(icon, size: 16, color: _C.brown),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _C.brown)),
            Text(label,
                style: const TextStyle(fontSize: 9.5, color: Colors.black45)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(children: [
        tile(Icons.thermostat_rounded, 'Air temp',
            '${r.airTemp.toStringAsFixed(1)}°C'),
        tile(Icons.water_drop_outlined, 'Humidity',
            '${r.humidity.toStringAsFixed(0)}%'),
        tile(
            Icons.air_rounded, 'Wind', '${r.windSpeed.toStringAsFixed(1)} m/s'),
      ]),
    );
  }

  Widget _adviceCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color))),
        ]),
        const SizedBox(height: 6),
        for (final b in bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text('•  $b',
                style: const TextStyle(
                    fontSize: 11.5, color: Colors.black87, height: 1.35)),
          ),
      ]),
    );
  }

  // ── Spray / foliar-application window ───────────────────────────────────
  // Prefers NuaSense's combined spray-quality score; falls back to the old
  // wind/rain-only heuristic if the Cloud Function hasn't returned it yet.

  Widget _sprayWindowCard(NuaSenseReading r) {
    final hasQualityBlock = r.sprayQualityLabel.isNotEmpty;

    if (hasQualityBlock) {
      final good = r.sprayQualityGood;
      final marginal = r.sprayQualityMarginal;
      final color = good
          ? _C.green
          : marginal
              ? _C.amber
              : _C.red;

      final bullets = <String>[
        'Spray quality: ${r.sprayQualityIndex.toStringAsFixed(0)}/100 — ${r.sprayQualityLabel}',
      ];
      if (!good && r.sprayLimitingFactor.isNotEmpty) {
        final factorLabel = switch (r.sprayLimitingFactor) {
          'wind' => 'wind speed',
          'delta_t' => 'delta-T (droplets/foliar feed drying before absorbing)',
          'inversion' =>
            'a temperature inversion (drift can hang near the ground)',
          'rain' => 'rain',
          _ => r.sprayLimitingFactor,
        };
        bullets.add('Main limiting factor right now: $factorLabel.');
      }
      bullets.add('Wind ${r.windSpeed.toStringAsFixed(1)} m/s  ·  '
          'Delta-T ${r.deltaT.toStringAsFixed(1)}°C'
          '${r.inversionRisk.isNotEmpty ? '  ·  Inversion risk: ${r.inversionRisk}' : ''}');
      if (good) {
        bullets.add('Good window for fungicide or foliar feed. Best in early '
            'morning or late afternoon.');
      } else if (marginal) {
        bullets
            .add('Usable but not ideal — expect some drift or faster drying. '
                'Consider waiting if the job isn\'t urgent.');
      } else {
        bullets.add('Hold off on spraying or foliar feeding for now.');
      }

      return _adviceCard(
        icon: good
            ? Icons.opacity_outlined
            : marginal
                ? Icons.warning_amber_rounded
                : Icons.not_interested_rounded,
        title: 'Spray Window — ${r.sprayQualityLabel}',
        color: color,
        bullets: bullets,
      );
    }

    // ── Fallback: wind/rain/daylight heuristic ─────────────────────────────
    final goodWind = r.goodSprayWind;
    final noRain = !r.rainingNow;
    final hour = DateTime.now().hour;
    final inWindow = hour >= 6 && hour <= 17;
    final canSpray = goodWind && noRain && inWindow;

    final bullets = <String>[];
    if (canSpray) {
      bullets.add(
          'Wind ${r.windSpeed.toStringAsFixed(1)} m/s ✓  ·  No rain ✓  ·  Daylight ✓');
      bullets.add(
          'Best time to spray or foliar-feed: early morning 6–9am or late afternoon 4–5pm.');
    } else {
      if (!goodWind) {
        bullets.add('Wind ${r.windSpeed.toStringAsFixed(1)} m/s — too high. '
            'Wait for it to drop below 3 m/s.');
      }
      if (!noRain) {
        bullets.add(
            'Currently raining — product will wash off before it can work.');
      }
      if (!inWindow) {
        bullets.add('Outside typical spray hours (6am–5pm).');
      }
    }

    return _adviceCard(
      icon: canSpray ? Icons.opacity_outlined : Icons.not_interested_rounded,
      title:
          canSpray ? 'Spray Window — Safe to Spray Now' : 'Spray Window — Hold',
      color: canSpray ? _C.green : _C.amber,
      bullets: bullets,
    );
  }

  // ── Leaf wetness (coffee leaf rust risk) ────────────────────────────────

  Widget _leafWetnessCard(NuaSenseReading r) {
    final wet = r.leafIsWet;
    final reason = r.lwdReason.isEmpty ? '' : r.lwdReason.replaceAll('_', ' ');
    final bullets = <String>[];

    if (wet) {
      bullets.add(
          'Leaves wet${reason.isNotEmpty ? ' ($reason)' : ''} — coffee leaf '
          'rust and other fungal spores germinate more readily.');
      if (r.lwdConsecutiveHours > 0) {
        final long = r.lwdConsecutiveHours >= 6;
        bullets.add('Wet for ${r.lwdConsecutiveHours} hour'
            '${r.lwdConsecutiveHours == 1 ? '' : 's'} in a row'
            '${long ? ' — long unbroken wetness is when most infection actually takes hold.' : '.'}');
      }
      bullets.add(
          'Avoid spraying foliar fertiliser or fungicide until leaves dry — '
          'product will run off rather than absorb.');
    } else {
      bullets.add('Leaf surfaces dry — lower fungal infection risk right now.');
      bullets.add('Dew gap: ${r.dewPointDepression.toStringAsFixed(1)}°C'
          '${r.dewPointDepression <= 2 ? ' — approaching condensation, watch overnight.' : '.'}');
    }

    return _adviceCard(
      icon: wet ? Icons.grain_rounded : Icons.check_circle_outline_rounded,
      title: wet ? 'Leaf Wetness — Fungal Risk' : 'Leaf Wetness — Dry',
      color: wet ? _C.blue : _C.green,
      bullets: bullets,
    );
  }

  Widget _fertiliserNote(NuaSenseReading r) {
    final vpdOk = r.vpd >= 0.4 && r.vpd <= 1.6;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.lightBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.eco_outlined, size: 15, color: _C.blue),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
          'VPD ${r.vpd.toStringAsFixed(2)} kPa — ${vpdOk ? "good uptake conditions for root or foliar feeding." : r.vpd < 0.4 ? "low; uptake may be slower, avoid over-watering." : "high; plants may be under water stress — check soil moisture before feeding."}',
          style: const TextStyle(
              fontSize: 11.5, color: Colors.black87, height: 1.35),
        )),
      ]),
    );
  }

  // ── Pest pressure (coffee berry borer featured) ─────────────────────────

  Widget _pestPressureStrip(NuaSenseReading r) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bug_report_outlined, size: 13, color: _C.green),
          const SizedBox(width: 6),
          const Text('PEST PRESSURE (this hour)',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _C.green,
                  letterSpacing: 0.4)),
        ]),
        const SizedBox(height: 8),
        _ddBar(
            'Coffee berry borer',
            Icons.bug_report_outlined,
            r.ddCbbHour,
            0.2,
            0.5,
            'Bores into ripening cherries — check for small entry holes'),
        _ddBar('Aphid', Icons.pest_control_outlined, r.ddAphidHour, 0.5, 1.2,
            'Warm + humid conditions — check new growth and undersides of leaves'),
        _ddBar('Whitefly', Icons.pest_control_outlined, r.ddWhiteflyHour, 0.3,
            0.8, 'Hot + dry conditions — look for sooty mould on leaves'),
      ]),
    );
  }

  Widget _ddBar(String label, IconData icon, double value, double medThresh,
      double highThresh, String sub) {
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _C.brown))),
          Text(levelLabel,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 5,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 9.5, color: Colors.black45)),
      ]),
    );
  }

  Widget _fullDataLink() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WeatherStationScreen()),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Full station data',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _C.green)),
          SizedBox(width: 3),
          Icon(Icons.arrow_forward_rounded, size: 14, color: _C.green),
        ]),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
