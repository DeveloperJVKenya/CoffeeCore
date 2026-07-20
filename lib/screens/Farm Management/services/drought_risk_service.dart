import 'package:coffeecore/screens/Farm%20Management/models/drought_risk_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/ndvi_history_entry_model.dart';

/// Computes a transparent, rule-based Drought Risk Index (0-100) for a farm
/// from its NDVI/NDWI/climate data. This is pure calculation — no network
/// I/O — so it never throws [ServiceUnavailableException]; when a required
/// input is missing it simply excludes that factor and redistributes its
/// weight across the remaining ones, rather than assuming a value.
///
/// All thresholds are named constants below so the model can be recalibrated
/// without restructuring the formula, and every factor's contribution is
/// surfaced in [DroughtRiskResult.explanation] so the score is never a
/// black box.
class DroughtRiskService {
  // NDVI: matches the "Excellent" threshold already used to label
  // vegetation health elsewhere in this module.
  static const double _ndviExcellentThreshold = 0.60;
  static const double _ndviTrendDropForMaxRisk = 0.15;
  static const Duration _ndviTrendLookback = Duration(days: 21);

  // NDWI (McFeeters): ample canopy/soil moisture vs. dry stress.
  static const double _ndwiAmpleThreshold = 0.20;
  static const double _ndwiDryThreshold = -0.30;

  // Rainfall: adequate 5-day outlook baseline for coffee.
  static const double _adequateRainfallMm = 20.0;

  // Temperature/humidity stress range.
  static const double _heatStressBaseC = 24.0;
  static const double _heatStressMaxC = 34.0;
  static const double _humidityAdequatePercent = 60.0;

  // Composite weights (renormalized over whichever factors are available).
  static const double _ndviWeight = 0.30;
  static const double _ndwiWeight = 0.30;
  static const double _rainfallWeight = 0.25;
  static const double _climateStressWeight = 0.15;

  DroughtRiskResult compute({
    required double currentNdvi,
    List<NdviHistoryEntry> ndviHistory = const [],
    double? currentNdwi,
    List<Map<String, dynamic>> forecast = const [],
    ClimateData? climate,
  }) {
    final explanationParts = <String>[];

    // ── NDVI factor ──────────────────────────────────────────
    final ndviLevelScore = _clamp(
      (_ndviExcellentThreshold - currentNdvi) / _ndviExcellentThreshold * 100,
    );
    double ndviTrendScore = 0;
    final trendBaseline = _findClosestEntry(ndviHistory, _ndviTrendLookback);
    if (trendBaseline != null) {
      final slope = currentNdvi - trendBaseline.ndvi;
      ndviTrendScore = _clamp(-slope / _ndviTrendDropForMaxRisk * 100);
      if (slope < -0.02) {
        explanationParts.add(
          'NDVI has dropped ${(-slope).toStringAsFixed(2)} over the last '
          '~3 weeks (+${ndviTrendScore.toStringAsFixed(0)} pts trend risk)',
        );
      } else {
        explanationParts.add(
          'NDVI trend over the last ~3 weeks is stable or improving '
          '(+${ndviTrendScore.toStringAsFixed(0)} pts trend risk)',
        );
      }
    } else {
      explanationParts.add(
        'Vegetation trend data is still accumulating (need a few more weeks '
        'of history) — trend risk treated as neutral',
      );
    }
    final ndviFactor = 0.6 * ndviLevelScore + 0.4 * ndviTrendScore;
    explanationParts.add(
      'Current NDVI is ${currentNdvi.toStringAsFixed(2)} '
      '(+${ndviLevelScore.toStringAsFixed(0)} pts level risk)',
    );

    // ── NDWI factor ──────────────────────────────────────────
    double? ndwiFactor;
    if (currentNdwi != null) {
      ndwiFactor = _clamp(
        (_ndwiAmpleThreshold - currentNdwi) /
            (_ndwiAmpleThreshold - _ndwiDryThreshold) *
            100,
      );
      explanationParts.add(
        'Canopy/soil moisture (NDWI) is ${currentNdwi.toStringAsFixed(2)} '
        '(+${ndwiFactor.toStringAsFixed(0)} pts)',
      );
    } else {
      explanationParts.add(
        'Moisture (NDWI) has not been fetched yet for this farm — its '
        'weight has been redistributed to the other factors',
      );
    }

    // ── Rainfall outlook factor ──────────────────────────────
    double? rainfallFactor;
    if (forecast.isNotEmpty) {
      final totalMm = forecast.fold<double>(
        0,
        (sum, day) => sum + ((day['rainfallMm'] as num?)?.toDouble() ?? 0),
      );
      rainfallFactor =
          _clamp((_adequateRainfallMm - totalMm) / _adequateRainfallMm * 100);
      explanationParts.add(
        'Only ${totalMm.toStringAsFixed(0)}mm of rain is forecast over the '
        'next ${forecast.length} day(s) '
        '(+${rainfallFactor.toStringAsFixed(0)} pts)',
      );
    } else {
      explanationParts.add(
        'No rainfall forecast is available yet — its weight has been '
        'redistributed to the other factors',
      );
    }

    // ── Temperature/humidity stress factor ────────────────────
    double? climateStressFactor;
    if (climate != null) {
      final tempScore = _clamp(
        (climate.temperatureCelsius - _heatStressBaseC) /
            (_heatStressMaxC - _heatStressBaseC) *
            100,
      );
      final humidityScore = _clamp(
        (_humidityAdequatePercent - climate.humidity) /
            _humidityAdequatePercent *
            100,
      );
      climateStressFactor = 0.5 * tempScore + 0.5 * humidityScore;
      if (climateStressFactor > 15) {
        explanationParts.add(
          'Temperature (${climate.temperatureCelsius.toStringAsFixed(0)}°C) '
          'and humidity (${climate.humidity.toStringAsFixed(0)}%) are adding '
          'heat/dryness stress (+${climateStressFactor.toStringAsFixed(0)} pts)',
        );
      } else {
        explanationParts.add(
          'Temperature and humidity are within normal range '
          '(+${climateStressFactor.toStringAsFixed(0)} pts)',
        );
      }
    } else {
      explanationParts.add(
        'Current weather conditions have not been fetched yet — its weight '
        'has been redistributed to the other factors',
      );
    }

    // ── Composite (renormalized over available factors) ──────
    double weightedSum = _ndviWeight * ndviFactor;
    double totalWeight = _ndviWeight;
    if (ndwiFactor != null) {
      weightedSum += _ndwiWeight * ndwiFactor;
      totalWeight += _ndwiWeight;
    }
    if (rainfallFactor != null) {
      weightedSum += _rainfallWeight * rainfallFactor;
      totalWeight += _rainfallWeight;
    }
    if (climateStressFactor != null) {
      weightedSum += _climateStressWeight * climateStressFactor;
      totalWeight += _climateStressWeight;
    }
    final score = totalWeight > 0 ? weightedSum / totalWeight : 0.0;

    return DroughtRiskResult(
      score: score,
      band: _bandFor(score),
      ndviFactor: ndviFactor,
      ndwiFactor: ndwiFactor,
      rainfallFactor: rainfallFactor,
      climateStressFactor: climateStressFactor,
      explanation: explanationParts.join('. '),
      computedAt: DateTime.now(),
    );
  }

  NdviHistoryEntry? _findClosestEntry(
      List<NdviHistoryEntry> history, Duration lookback) {
    if (history.isEmpty) return null;
    final target = DateTime.now().subtract(lookback);
    // History is stored oldest-first; only use entries at least as old as
    // the lookback window so we're measuring an actual trend, not noise
    // from back-to-back same-day refreshes.
    final eligible =
        history.where((e) => e.fetchedAt.isBefore(target)).toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) => (target.difference(a.fetchedAt))
        .abs()
        .compareTo((target.difference(b.fetchedAt)).abs()));
    return eligible.first;
  }

  String _bandFor(double score) {
    if (score < 25) return 'Low';
    if (score < 50) return 'Moderate';
    if (score < 75) return 'High';
    return 'Severe';
  }

  double _clamp(double v) => v.clamp(0.0, 100.0);
}
