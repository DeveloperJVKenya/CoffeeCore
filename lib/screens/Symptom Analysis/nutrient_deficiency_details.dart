// ─────────────────────────────────────────────────────────────────────────────
// COFFEE NUTRIENT DEFICIENCY REFERENCE
//
// Mirrors the structure of kPestDetails/kDiseaseDetails (coffee_pest_
// management_page.dart / coffee_disease_management_page.dart) so the
// Symptom Checker's existing local-scoring and Gemini-ranking machinery
// (SymptomCheckerAiService._rank) works unchanged against this map too.
//
// Keyed by the EXACT field names already used on CoffeeSoilData
// (lib/models/coffee_soil_data.dart: nitrogen, phosphorus, potassium,
// magnesium, calcium, zinc, boron) so a matched result can link straight
// back to the Soil module — a farmer confirms a suspected deficiency with
// an actual soil test, not from visual symptoms alone. This is deliberate:
// visual symptom overlap between several of these deficiencies is genuinely
// high in real agronomy, so nothing here claims a definitive diagnosis.
// ─────────────────────────────────────────────────────────────────────────────

final Map<String, Map<String, dynamic>> kNutrientDeficiencyDetails = {
  for (final entry in _kNutrientDeficiencyDetailsBase.entries)
    entry.key: {
      ...entry.value,
      // 'symptoms' as a joined string — the shape SymptomCheckerAiService._rank
      // and the classification prompt builder expect (kPestDetails/
      // kDiseaseDetails carry the same field), derived here so the source
      // list above stays the single source of truth.
      'symptoms': (entry.value['visualSymptoms'] as List<String>).join('; '),
    },
};

final Map<String, Map<String, dynamic>> _kNutrientDeficiencyDetailsBase = {
  'nitrogen': {
    'displayName': 'Nitrogen (N)',
    'description':
        'Nitrogen is mobile in the plant, so deficiency symptoms show up '
            'first on older, lower leaves as the plant remobilizes it to '
            'newer growth — overall pale, yellowish-green foliage and '
            'stunted shoots are the classic picture.',
    'visualSymptoms': [
      'Uniform yellowing of older (lower) leaves',
      'Overall pale green foliage color',
      'Stunted shoot growth',
      'Reduced leaf size',
      'Premature leaf drop of older leaves',
    ],
    'correctiveMeasures': [
      'Apply nitrogen fertilizer (e.g. urea, CAN) split across the growing season',
      'Incorporate well-decomposed organic manure or compost',
      'Avoid over-liming, which can reduce nitrogen availability',
    ],
  },
  'phosphorus': {
    'displayName': 'Phosphorus (P)',
    'description':
        'Phosphorus deficiency is common in acidic, P-fixing tropical '
            'soils and shows as dark green leaves with a purplish or '
            'reddish tinge, alongside stunted overall growth.',
    'visualSymptoms': [
      'Dark green leaves with a purple or reddish underside tinge',
      'Stunted overall plant growth',
      'Delayed flowering',
      'Small, narrow leaves',
      'Poor root development',
    ],
    'correctiveMeasures': [
      'Apply phosphorus fertilizer (e.g. triple superphosphate, DAP) near the root zone',
      'Correct soil pH toward 5.5–6.5 to improve phosphorus availability',
      'Use mycorrhizal inoculants where available',
    ],
  },
  'potassium': {
    'displayName': 'Potassium (K)',
    'description': 'Potassium is mobile and remobilized from older tissue, so '
        'deficiency appears as yellowing and scorching along the '
        'margins and tips of older leaves.',
    'visualSymptoms': [
      'Yellowing at leaf margins or tips of older leaves',
      'Brown, scorched (necrotic) leaf edges',
      'Leaves appear cupped or curled',
      'Weak branches, poor bean filling',
      'Increased susceptibility to drought stress',
    ],
    'correctiveMeasures': [
      'Apply potassium fertilizer (e.g. muriate of potash, sulfate of potash)',
      'Mulch to conserve soil moisture and potassium availability',
      'Avoid excessive nitrogen application without balancing potassium',
    ],
  },
  'magnesium': {
    'displayName': 'Magnesium (Mg)',
    'description': 'Magnesium deficiency causes interveinal chlorosis on older '
        'leaves — the veins stay green while the tissue between them '
        'yellows, often forming a distinctive "Christmas tree" pattern '
        'in coffee.',
    'visualSymptoms': [
      'Interveinal yellowing on older leaves (veins stay green)',
      '"Christmas tree" pattern of chlorosis on the leaf blade',
      'Premature leaf fall',
      'Reduced photosynthesis, generally weak growth',
    ],
    'correctiveMeasures': [
      'Apply magnesium sulfate (Epsom salt) or dolomitic lime',
      'Foliar spray of magnesium sulfate for faster correction',
      'Avoid excess potassium fertilization, which competes with magnesium uptake',
    ],
  },
  'calcium': {
    'displayName': 'Calcium (Ca)',
    'description':
        'Calcium is immobile in the plant, so deficiency affects new '
            'growth first — distorted young leaves and dieback of growing '
            'tips are the key signs.',
    'visualSymptoms': [
      'Distorted or hooked young leaves',
      'Dieback of shoot tips / growing points',
      'Weak, poorly developed root tips',
      'Premature fruit or berry drop',
    ],
    'correctiveMeasures': [
      'Apply agricultural lime to raise soil calcium and pH',
      'Apply gypsum where a pH increase is not desired',
      'Ensure consistent soil moisture — calcium uptake depends on water flow',
    ],
  },
  'zinc': {
    'displayName': 'Zinc (Zn)',
    'description':
        'Zinc deficiency in coffee produces small, narrow leaves clustered '
            'in rosettes at branch tips — sometimes called "little leaf" — '
            'with interveinal chlorosis on young growth.',
    'visualSymptoms': [
      'Small, narrow leaves ("little leaf")',
      'Rosette clustering of leaves at shoot tips',
      'Interveinal chlorosis on young leaves',
      'Shortened internodes',
    ],
    'correctiveMeasures': [
      'Apply zinc sulfate as a foliar spray for fast correction',
      'Soil-apply zinc sulfate in confirmed-deficient plots',
      'Avoid excessive phosphorus application, which can worsen zinc deficiency',
    ],
  },
  'boron': {
    'displayName': 'Boron (B)',
    'description':
        'Boron deficiency causes dieback of terminal buds and brittle, '
            'malformed young leaves, along with poor flowering and fruit '
            'set.',
    'visualSymptoms': [
      'Dieback of terminal / growing buds',
      'Brittle, malformed young leaves',
      'Poor flowering and fruit set',
      'Corky, cracked patches on stems or fruit',
    ],
    'correctiveMeasures': [
      'Apply borax or a boron-specific fertilizer in small, precise doses (over-application risks boron toxicity)',
      'Foliar spray of boron during the flowering stage',
      'Ensure balanced soil moisture — boron uptake is water-dependent',
    ],
  },
};
