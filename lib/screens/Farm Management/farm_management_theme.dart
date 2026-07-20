import 'package:flutter/material.dart';

/// Consolidated color, spacing and typography constants for the Farm
/// Management section. Every screen/widget in this folder must import this
/// file instead of redefining local color constants. Values mirror the
/// previously-scattered constants from the old `Farm Management/constants.dart`
/// (customBrown) and `Farm Mapping/farm_detail_screen.dart` (_primary, _accent,
/// _accentStop, _cardBg) so the visual identity does not change — only layout
/// and component structure are modernized.
class FarmTheme {
  const FarmTheme._();

  // ── Core palette ─────────────────────────────────────────────
  static const Color primaryBrown = Color(0xFF4A2F1A); // == old customBrown
  static const Color primaryBrownAlt =
      Color(0xFF6D4C41); // == old Farm Mapping _primary
  static const Color secondaryGreen =
      Color(0xFF2E7D32); // aligned with Colors.green[800] app seed
  static const Color accentGood = Color(0xFF4CAF50); // == old _accent
  static const Color accentBad = Color(0xFFE53935); // == old _accentStop
  static const Color cardBackground = Color(0xFFF1ECEA); // == old _cardBg

  // ── Vegetation / satellite health palette ───────────────────
  static const Color healthExcellent = Color(0xFF2E7D32);
  static const Color healthGood = Color(0xFF66BB6A);
  static const Color healthFair = Color(0xFFFFB300);
  static const Color healthPoor = Color(0xFFE53935);
  static const Color healthUnknown = Color(0xFF78909C);

  // ── NDVI ramp ─────────────────────────────────────────────────
  // Standard EOS/USGS/Sentinel-Hub-custom-scripts NDVI convention: gray
  // (water/cloud/snow, <0) → brown (bare soil, ~0) → tan/yellow (sparse,
  // 0.1-0.2) → light green (moderate, 0.35) → dark green (dense, 1.0).
  // Exposed as public stop/color lists so the legend widget and the color
  // function below always stay in sync.
  static const List<double> ndviStops = [
    -1.0,
    0.0,
    0.1,
    0.2,
    0.35,
    0.5,
    0.7,
    1.0,
  ];
  static const List<Color> ndviColors = [
    Color(0xFF9E9E9E), // <0: water/cloud/snow — gray
    Color(0xFF8D6E63), // 0.0: bare soil — brown
    Color(0xFFBCAA33), // 0.1: sparse — tan/olive
    Color(0xFFD4CB27), // 0.2: sparse-transition — yellow
    Color(0xFFA8D14C), // 0.35: light green
    Color(0xFF6CBF43), // 0.5: moderate green
    Color(0xFF3E8E28), // 0.7: green
    Color(0xFF1B5E20), // 1.0: dense — dark green
  ];

  // ── NDWI ramp ─────────────────────────────────────────────────
  // Sentinel Hub NDWI custom-script convention (McFeeters, 1996): brown/tan
  // (dry, negative) → blue gradient (moist/water, positive).
  static const List<double> ndwiStops = [
    -1.0,
    -0.3,
    -0.1,
    0.0,
    0.1,
    0.3,
    0.6,
    1.0,
  ];
  static const List<Color> ndwiColors = [
    Color(0xFF6D4C29), // very dry — dark brown
    Color(0xFFA9825A), // dry — tan/brown
    Color(0xFFD8C79A), // low moisture — pale tan
    Color(0xFFE0E0C0), // transition
    Color(0xFFAED9E0), // moist — light blue
    Color(0xFF4FA3D1), // wet — blue
    Color(0xFF1565C0), // very wet
    Color(0xFF0D47A1), // water — deep blue
  ];

  // ── Spacing scale ────────────────────────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // ── Radii ────────────────────────────────────────────────────
  static const double radiusCard = 16;

  // ── Text styles ──────────────────────────────────────────────
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: primaryBrown,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: primaryBrown,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.black54,
  );

  // ── Shared decorations ───────────────────────────────────────
  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(radiusCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static Color colorForProfitLoss(double value) =>
      value >= 0 ? accentGood : accentBad;

  static Color colorForVegetationHealth(String health) {
    switch (health.toLowerCase()) {
      case 'excellent':
        return healthExcellent;
      case 'good':
        return healthGood;
      case 'fair':
        return healthFair;
      case 'poor':
        return healthPoor;
      default:
        return healthUnknown;
    }
  }

  static Color colorForNdvi(double ndvi) =>
      _lerpRamp(ndvi, ndviStops, ndviColors);

  static Color colorForNdwi(double ndwi) =>
      _lerpRamp(ndwi, ndwiStops, ndwiColors);

  static Color colorForDroughtRisk(double score) {
    if (score < 25) return healthExcellent;
    if (score < 50) return const Color(0xFFFFB300); // Moderate — amber
    if (score < 75) return const Color(0xFFFB8C00); // High — orange
    return const Color(0xFFB71C1C); // Severe — deep red
  }

  static String droughtRiskBand(double score) {
    if (score < 25) return 'Low';
    if (score < 50) return 'Moderate';
    if (score < 75) return 'High';
    return 'Severe';
  }

  static Color _lerpRamp(double value, List<double> stops, List<Color> colors) {
    final v = value.clamp(stops.first, stops.last);
    for (int i = 0; i < stops.length - 1; i++) {
      if (v >= stops[i] && v <= stops[i + 1]) {
        final t = (v - stops[i]) / (stops[i + 1] - stops[i]);
        return Color.lerp(colors[i], colors[i + 1], t)!;
      }
    }
    return colors.last;
  }
}
