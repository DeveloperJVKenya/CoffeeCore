// ─────────────────────────────────────────────────────────────────────────────
// COFFEE DISEASE MODELS
//
// Mirrors the structure of CoffeePestData in coffee_pest_models.dart.
// Extended with culturalControls — a separate list from preventiveMeasures,
// since disease management typically distinguishes curative cultural practices
// (removing infected tissue, soil drainage) from preventive ones.
// ─────────────────────────────────────────────────────────────────────────────

class CoffeeDiseaseData {
  final String       name;
  final String       description;
  final String       symptoms;
  final List<String> chemicalControls;
  final List<String> biologicalControls;
  final List<String> culturalControls;
  final List<String> possibleCauses;
  final List<String> preventiveMeasures;
  final List<String> lifecycleImages;

  const CoffeeDiseaseData({
    required this.name,
    required this.description,
    required this.symptoms,
    required this.chemicalControls,
    required this.biologicalControls,
    required this.culturalControls,
    required this.possibleCauses,
    required this.preventiveMeasures,
    required this.lifecycleImages, required List<dynamic> mechanicalControls,
  });

  /// Converts the local data into the same map format returned by Gemini AI
  /// so that DiseaseResultsPage can render it identically regardless of source.
  Map<String, dynamic> toAiFormatMap() => {
    'description'        : description,
    'symptoms'           : symptoms,
    'chemical_controls'  : chemicalControls,
    'biological_controls': biologicalControls,
    'cultural_controls'  : culturalControls,
    'possible_causes'    : possibleCauses,
    'preventive_measures': preventiveMeasures,
  };

  /// Creates a copy with optional field overrides — useful for merging
  /// local data with AI-enriched details returned from Gemini.
  CoffeeDiseaseData copyWith({
    String?       name,
    String?       description,
    String?       symptoms,
    List<String>? chemicalControls,
    List<String>? biologicalControls,
    List<String>? culturalControls,
    List<String>? possibleCauses,
    List<String>? preventiveMeasures,
    List<String>? lifecycleImages,
  }) {
    return CoffeeDiseaseData(
      name:               name               ?? this.name,
      description:        description        ?? this.description,
      symptoms:           symptoms           ?? this.symptoms,
      chemicalControls:   chemicalControls   ?? this.chemicalControls,
      biologicalControls: biologicalControls ?? this.biologicalControls,
      culturalControls:   culturalControls   ?? this.culturalControls,
      possibleCauses:     possibleCauses     ?? this.possibleCauses,
      preventiveMeasures: preventiveMeasures ?? this.preventiveMeasures,
      lifecycleImages:    lifecycleImages    ?? this.lifecycleImages, mechanicalControls: [],
    );
  }

  @override
  String toString() => 'CoffeeDiseaseData(name: $name)';
}