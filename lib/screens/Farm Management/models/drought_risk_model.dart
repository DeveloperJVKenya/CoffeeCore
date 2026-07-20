/// Result of [DroughtRiskService.compute] — a transparent, explainable
/// 0-100 drought risk score for a farm, broken down by contributing factor.
/// This is a pure computed value derived from live NDVI/NDWI/climate data;
/// it is not the source of truth and is recomputed on demand rather than
/// persisted, so it can never drift from the inputs it was built from.
class DroughtRiskResult {
  final double score;
  final String band;

  /// 0-100 risk contribution of each factor, or null if that factor's
  /// input data wasn't available (its weight was redistributed instead).
  final double? ndviFactor;
  final double? ndwiFactor;
  final double? rainfallFactor;
  final double? climateStressFactor;

  final String explanation;
  final DateTime computedAt;

  const DroughtRiskResult({
    required this.score,
    required this.band,
    required this.ndviFactor,
    required this.ndwiFactor,
    required this.rainfallFactor,
    required this.climateStressFactor,
    required this.explanation,
    required this.computedAt,
  });
}
