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
}
