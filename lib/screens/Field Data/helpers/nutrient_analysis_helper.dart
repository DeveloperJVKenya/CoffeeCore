import 'dart:developer' as developer;

class NutrientAnalysisHelper {
  static const Map<String, Map<String, Map<String, double>>> optimalValues = {
    'Establishment/Seedling': {
      'pH': {'low': 5.0, 'optimal': 6.0, 'high': 7.0},
      'nitrogen': {'low': 100.0, 'optimal': 150.0, 'high': 200.0},
      'phosphorus': {'low': 20.0, 'optimal': 40.0, 'high': 60.0},
      'potassium': {'low': 150.0, 'optimal': 200.0, 'high': 250.0},
      'magnesium': {'low': 50.0, 'optimal': 100.0, 'high': 150.0},
      'calcium': {'low': 1000.0, 'optimal': 1500.0, 'high': 2000.0},
      'zinc': {'low': 2.0, 'optimal': 5.0, 'high': 10.0},
      'boron': {'low': 0.5, 'optimal': 1.0, 'high': 2.0},
    },
    'Vegetative Growth': {
      'pH': {'low': 5.0, 'optimal': 6.0, 'high': 7.0},
      'nitrogen': {'low': 120.0, 'optimal': 180.0, 'high': 240.0},
      'phosphorus': {'low': 25.0, 'optimal': 50.0, 'high': 75.0},
      'potassium': {'low': 180.0, 'optimal': 240.0, 'high': 300.0},
      'magnesium': {'low': 60.0, 'optimal': 120.0, 'high': 180.0},
      'calcium': {'low': 1200.0, 'optimal': 1800.0, 'high': 2400.0},
      'zinc': {'low': 2.5, 'optimal': 6.0, 'high': 12.0},
      'boron': {'low': 0.6, 'optimal': 1.2, 'high': 2.4},
    },
    'Flowering and Fruiting': {
      'pH': {'low': 5.0, 'optimal': 6.0, 'high': 7.0},
      'nitrogen': {'low': 80.0, 'optimal': 120.0, 'high': 160.0},
      'phosphorus': {'low': 30.0, 'optimal': 60.0, 'high': 90.0},
      'potassium': {'low': 200.0, 'optimal': 300.0, 'high': 400.0},
      'magnesium': {'low': 70.0, 'optimal': 140.0, 'high': 210.0},
      'calcium': {'low': 1400.0, 'optimal': 2000.0, 'high': 2600.0},
      'zinc': {'low': 3.0, 'optimal': 7.0, 'high': 14.0},
      'boron': {'low': 0.7, 'optimal': 1.5, 'high': 3.0},
    },
    'Maturation and Harvesting': {
      'pH': {'low': 5.0, 'optimal': 6.0, 'high': 7.0},
      'nitrogen': {'low': 60.0, 'optimal': 100.0, 'high': 140.0},
      'phosphorus': {'low': 20.0, 'optimal': 40.0, 'high': 60.0},
      'potassium': {'low': 150.0, 'optimal': 200.0, 'high': 250.0},
      'magnesium': {'low': 50.0, 'optimal': 100.0, 'high': 150.0},
      'calcium': {'low': 1000.0, 'optimal': 1500.0, 'high': 2000.0},
      'zinc': {'low': 2.0, 'optimal': 5.0, 'high': 10.0},
      'boron': {'low': 0.5, 'optimal': 1.0, 'high': 2.0},
    },
  };

  static String getNutrientStatus(String nutrient, double value, String stage) {
    try {
      final ranges = optimalValues[stage]?[nutrient];
      if (ranges == null) {
        developer.log('No ranges found for $nutrient in stage $stage',
            name: 'NutrientAnalysisHelper');
        return 'Unknown';
      }

      if (value < ranges['low']!) {
        return 'Low';
      } else if (value > ranges['high']!) {
        return 'High';
      } else {
        return 'Optimal';
      }
    } catch (e) {
      developer.log('Error determining status for $nutrient: $e',
          name: 'NutrientAnalysisHelper', error: e);
      return 'Unknown';
    }
  }

  static String getNutrientUnit(String nutrient, bool isPerPlant) {
    if (nutrient == 'pH') return '';
    return isPerPlant ? 'mg/plant' : 'kg/acre';
  }

  static double convertToPerPlant(
      String nutrient, double value, int plantDensity) {
    if (nutrient == 'pH') return value;
    return value / plantDensity * 1000; // kg/acre to mg/plant
  }

  static double convertToPerAcre(
      String nutrient, double value, int plantDensity) {
    if (nutrient == 'pH') return value;
    return value * plantDensity / 1000; // mg/plant to kg/acre
  }

  /// Returns a lightweight loading placeholder map.
  ///
  /// The real per-nutrient recommendations are now fetched live from Gemini's
  /// Google-Search-grounded model via [GeminiSoilAiService.fetchLiveRecommendations].
  /// This stub is kept so existing call sites compile unchanged; it is replaced
  /// by the Gemini result as soon as the async fetch completes.
  static Map<String, String> getRecommendations(String nutrient, String status,
      String stage, String? soilType, bool isPerPlant, int plantDensity) {
    // Return an empty map — the form will show a loading indicator and
    // replace this with the live Gemini result once it arrives.
    return {};
  }
}
