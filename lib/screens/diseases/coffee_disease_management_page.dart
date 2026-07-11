import 'package:coffeecore/screens/Disease%20Management/coffee_user_disease_history_page.dart';
import 'package:coffeecore/screens/diseases/disease_results_page.dart';
import 'package:coffeecore/screens/diseases/disease_scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coffeecore/screens/diseases/coffee_disease_models.dart';
//import 'package:coffeecore/screens/diseases/coffee_user_disease_history.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHARED DISEASE DATA — accessed by DiseaseResultsPage as a local fallback
// ─────────────────────────────────────────────────────────────────────────────

const List<String> kDiseaseStages = [
  'Seedling & Nursery',
  'Vegetative Growth',
  'Flowering & Fruit Development',
  'Post-harvest / Storage',
];

const Map<String, List<String>> kStageDiseases = {
  'Seedling & Nursery': [
    'Coffee Damping Off',
    'Coffee Nursery Blight',
    'Coffee Brown Eye Spot',
    'Coffee Root Rot',
  ],
  'Vegetative Growth': [
    'Coffee Leaf Rust',
    'Coffee Brown Eye Spot',
    'Coffee Bacterial Blight',
    'Coffee Sooty Mold',
    'Coffee Wilt Disease',
    'Coffee Root Rot',
    'Coffee Anthracnose',
  ],
  'Flowering & Fruit Development': [
    'Coffee Berry Disease',
    'Coffee Leaf Rust',
    'Coffee Anthracnose',
    'Coffee Brown Eye Spot',
    'Coffee Bacterial Blight',
    'Coffee Sooty Mold',
  ],
  'Post-harvest / Storage': [
    'Coffee Green Mold',
    'Coffee Ochratoxin A Contamination',
    'Coffee Anthracnose',
  ],
};

final Map<String, Map<String, dynamic>> kDiseaseDetails = {
  'Coffee Leaf Rust': {
    'description':
        'The most devastating coffee disease worldwide, caused by the fungus Hemileia vastatrix. '
            'It produces orange-yellow powdery spore masses on the undersides of leaves, reducing photosynthesis and fruit production.',
    'symptoms':
        'Yellow-orange powdery pustules on the undersides of leaves, corresponding pale yellow spots on the upper surface, '
            'premature leaf drop, and defoliation of branches. Severe infection causes complete leaf loss and branch die-back.',
    'chemicalControls': [
      'Copper oxychloride',
      'Mancozeb',
      'Propiconazole',
      'Trifloxystrobin'
    ],
    'biologicalControls': [
      'Trichoderma harzianum',
      'Bacillus subtilis',
      'Copper-based organic fungicides'
    ],
    'culturalControls': [
      'Shade management',
      'Pruning for airflow',
      'Remove infected leaves'
    ],
    'possibleCauses': [
      'High humidity (above 70%)',
      'Temperatures between 15–28°C',
      'Dense canopy with poor air circulation',
      'Excessive nitrogen fertilisation',
    ],
    'preventiveMeasures': [
      'Apply preventive copper sprays at start of rains',
      'Plant resistant varieties (Ruiru 11, Batian)',
      'Maintain proper spacing and pruning',
      'Monitor crops every 2 weeks during wet season',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_leaf_rust1.png',
      'assets/diseases/coffee_leaf_rust2.png',
      'assets/diseases/coffee_leaf_rust3.png',
      'assets/diseases/coffee_leaf_rust4.png',
      'assets/diseases/coffee_leaf_rust5.png',
      'assets/diseases/coffee_leaf_rust6.png',
      'assets/diseases/coffee_leaf_rust7.png',
      'assets/diseases/coffee_leaf_rust8.png',
    ],
  },
  'Coffee Berry Disease': {
    'description':
        'CBD (Colletotrichum kahawae) is the most economically damaging coffee disease in Africa. '
            'It infects coffee berries at all development stages, causing total crop loss if unmanaged.',
    'symptoms':
        'Dark, sunken lesions on green berries that turn brown-black and mummify, "ghost" berries remaining on branches, '
            'black pedicels, and premature fruit drop. Infected beans show brown discolouration inside.',
    'chemicalControls': [
      'Copper oxychloride',
      'Carbendazim',
      'Thiophanate-methyl',
      'Cymoxanil + Mancozeb'
    ],
    'biologicalControls': ['Trichoderma spp.', 'Bacillus amyloliquefaciens'],
    'culturalControls': [
      'Remove mummified berries',
      'Timely harvesting',
      'Sanitation pruning'
    ],
    'possibleCauses': [
      'Rainfall and wet conditions during fruit development',
      'Temperatures of 15–25°C',
      'Susceptible Arabica varieties',
      'Poor field hygiene (mummified berries left on plant)',
    ],
    'preventiveMeasures': [
      'Spray copper fungicides at pin-head berry stage',
      'Plant CBD-resistant varieties (Ruiru 11)',
      'Collect and destroy all mummified berries',
      'Maintain field hygiene after harvest',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_berry_disease1.png',
      'assets/diseases/coffee_berry_disease2.png',
      'assets/diseases/coffee_berry_disease3.png',
      'assets/diseases/coffee_berry_disease4.png',
      'assets/diseases/coffee_berry_disease5.png',
      'assets/diseases/coffee_berry_disease6.png',
      'assets/diseases/coffee_berry_disease7.png',
    ],
  },
  'Coffee Wilt Disease': {
    'description':
        'Caused by the soil-borne fungus Gibberella xylarioides (Fusarium xylarioides). '
            'It blocks the water-conducting vessels of the coffee plant, causing rapid wilting and death.',
    'symptoms':
        'Sudden wilting of one or more branches while the rest of the plant appears healthy, yellowing and browning of leaves '
            'on affected branches, brown-red discolouration inside the stem when cut, and eventual death of the whole plant.',
    'chemicalControls': [
      'Carbendazim (soil drench)',
      'Thiophanate-methyl (soil drench)'
    ],
    'biologicalControls': [
      'Trichoderma harzianum (soil application)',
      'Pseudomonas fluorescens'
    ],
    'culturalControls': [
      'Uproot and burn infected plants',
      'Avoid replanting in same hole',
      'Disinfect tools'
    ],
    'possibleCauses': [
      'Contaminated soil or planting material',
      'Infected pruning tools',
      'Waterlogged soil conditions',
      'Wounds from pruning or pests',
    ],
    'preventiveMeasures': [
      'Use certified disease-free planting material',
      'Disinfect all pruning tools with 70% alcohol',
      'Improve soil drainage',
      'Apply Trichoderma to soil at planting',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_wilt1.png',
      'assets/diseases/coffee_wilt2.png',
      'assets/diseases/coffee_wilt3.png',
      'assets/diseases/coffee_wilt4.png',
      'assets/diseases/coffee_wilt5.png',
      'assets/diseases/coffee_wilt6.png',
    ],
  },
  'Coffee Root Rot': {
    'description':
        'A complex of soil-borne pathogens including Phytophthora cinnamomi, Pythium spp., and Fusarium spp. '
            'that attack the roots of coffee plants, disrupting water and nutrient uptake.',
    'symptoms':
        'Yellowing and wilting of leaves despite adequate water, dark-brown discolouration and decay of the roots, '
            'stunted plant growth, and progressive decline. Roots appear slimy and may have a foul smell.',
    'chemicalControls': [
      'Metalaxyl (Ridomil)',
      'Fosetyl-aluminium',
      'Copper oxychloride (soil drench)'
    ],
    'biologicalControls': [
      'Trichoderma viride',
      'Bacillus subtilis',
      'Mycorrhizal inoculants'
    ],
    'culturalControls': [
      'Improve drainage',
      'Avoid overwatering',
      'Mulch with well-composted material'
    ],
    'possibleCauses': [
      'Waterlogged or poorly drained soils',
      'Soil compaction',
      'Overwatering',
      'Contaminated irrigation water',
    ],
    'preventiveMeasures': [
      'Plant on well-drained soils or raised beds',
      'Avoid overwatering especially in wet seasons',
      'Apply Trichoderma soil inoculant at planting',
      'Use certified disease-free seedlings',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_root_rot1.png',
      'assets/diseases/coffee_root_rot2.png',
      'assets/diseases/coffee_root_rot3.png',
      'assets/diseases/coffee_root_rot4.png',
      'assets/diseases/coffee_root_rot5.png',
    ],
  },
  'Coffee Brown Eye Spot': {
    'description':
        'Caused by Cercospora coffeicola, this fungal disease affects leaves, berries, and nursery seedlings. '
            'It is most damaging in nurseries and on plants under nutritional stress.',
    'symptoms':
        'Circular brown spots with a pale tan centre and dark brown border on leaves (resembling an eye), '
            'similar lesions on berries causing premature drop, and in nurseries causing widespread seedling blight.',
    'chemicalControls': ['Copper oxychloride', 'Mancozeb', 'Chlorothalonil'],
    'biologicalControls': ['Trichoderma spp.', 'Neem-based fungicides'],
    'culturalControls': [
      'Shade management',
      'Adequate fertilisation (especially potassium)',
      'Proper nursery hygiene'
    ],
    'possibleCauses': [
      'Nutrient deficiency (especially nitrogen and potassium)',
      'High humidity and rainfall',
      'Excessive shading in nurseries',
      'Poor nursery sanitation',
    ],
    'preventiveMeasures': [
      'Maintain balanced fertilisation programme',
      'Apply preventive fungicide sprays in wet season',
      'Ensure proper nursery hygiene',
      'Provide adequate (not excessive) shade',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_brown_eye_spot1.png',
      'assets/diseases/coffee_brown_eye_spot2.png',
      'assets/diseases/coffee_brown_eye_spot3.png',
      'assets/diseases/coffee_brown_eye_spot4.png',
      'assets/diseases/coffee_brown_eye_spot5.png',
      'assets/diseases/coffee_brown_eye_spot6.png',
    ],
  },
  'Coffee Damping Off': {
    'description':
        'Caused by soil-borne pathogens primarily Pythium spp. and Rhizoctonia solani, '
            'this disease kills coffee seedlings at or just below the soil line in nurseries.',
    'symptoms':
        'Seedlings collapse and die suddenly at ground level (post-emergence damping off), '
            'or fail to emerge at all (pre-emergence). Affected stems show a dark, water-soaked constriction at the soil line. '
            'Patches of dead seedlings spread rapidly in nursery beds.',
    'chemicalControls': [
      'Metalaxyl (Ridomil)',
      'Mancozeb',
      'Carbendazim (soil drench)'
    ],
    'biologicalControls': ['Trichoderma harzianum', 'Bacillus subtilis'],
    'culturalControls': [
      'Sterilise nursery soil',
      'Improve drainage',
      'Avoid overcrowding',
      'Reduce overhead watering'
    ],
    'possibleCauses': [
      'Overwatering or poorly drained nursery beds',
      'Contaminated nursery soil or pots',
      'Overcrowding of seedlings',
      'High humidity under dense shade',
    ],
    'preventiveMeasures': [
      'Sterilise nursery soil with steam or solarisation',
      'Use well-drained growing media',
      'Apply Trichoderma at sowing',
      'Water seedlings in the morning to allow drying',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_damping_off1.png',
      'assets/diseases/coffee_damping_off2.png',
      'assets/diseases/coffee_damping_off3.png',
      'assets/diseases/coffee_damping_off4.png',
      'assets/diseases/coffee_damping_off5.png',
    ],
  },
  'Coffee Sooty Mold': {
    'description':
        'A secondary fungal disease caused by various saprophytic fungi (Capnodium spp., Cladosporium spp.) '
            'that grow on honeydew secreted by sap-sucking pests. It does not directly infect plant tissue.',
    'symptoms':
        'Black, powdery coating on leaves, stems, and berries that can be rubbed off. '
            'Affected leaves show reduced photosynthesis due to light blockage. '
            'Presence of honeydew-producing pests (mealybugs, whiteflies, scale insects) is always associated.',
    'chemicalControls': [
      'Copper-based fungicides (for secondary control)',
      'Control the honeydew-producing pest first'
    ],
    'biologicalControls': [
      'Control underlying pest biologically',
      'Neem oil sprays reduce honeydew pests'
    ],
    'culturalControls': [
      'Wash leaves with water and mild soap',
      'Control ants that protect honeydew pests',
      'Improve air circulation'
    ],
    'possibleCauses': [
      'Infestation of honeydew-producing pests (mealybugs, scale, whiteflies)',
      'Ant presence protecting pest colonies',
      'Poor ventilation and dense canopy',
    ],
    'preventiveMeasures': [
      'Control sap-sucking pests (mealybugs, whiteflies, scale insects)',
      'Manage ant populations',
      'Prune for better airflow',
      'Inspect plants regularly for pest activity',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_sooty_mold1.png',
      'assets/diseases/coffee_sooty_mold2.png',
      'assets/diseases/coffee_sooty_mold3.png',
      'assets/diseases/coffee_sooty_mold4.png',
      'assets/diseases/coffee_sooty_mold5.png',
    ],
  },
  'Coffee Bacterial Blight': {
    'description':
        'Caused by Pseudomonas syringae pv. garcae, this bacterial disease is prevalent in cool, '
            'high-altitude coffee growing regions of East Africa and causes significant leaf and berry damage.',
    'symptoms':
        'Water-soaked spots on leaves that turn brown-black with a greasy appearance, '
            'necrotic streaks along leaf veins, blackening and shrivelling of young shoots (dieback), '
            'dark spots on berries with sunken lesions.',
    'chemicalControls': [
      'Copper oxychloride',
      'Copper hydroxide',
      'Streptomycin sulphate (where registered)'
    ],
    'biologicalControls': [
      'Bacillus subtilis',
      'Pseudomonas fluorescens (antagonistic strains)'
    ],
    'culturalControls': [
      'Remove and destroy infected material',
      'Avoid overhead irrigation',
      'Disinfect pruning tools'
    ],
    'possibleCauses': [
      'Cool temperatures (12–22°C) with high rainfall',
      'High altitudes (above 1500 m)',
      'Wounds from hail, pests, or pruning',
      'Splashing rain spreading bacteria',
    ],
    'preventiveMeasures': [
      'Apply preventive copper sprays before rainy season',
      'Avoid injury to plants during cultivation',
      'Prune for airflow at high altitude farms',
      'Use disease-free planting material',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_bacterial_blight1.png',
      'assets/diseases/coffee_bacterial_blight2.png',
      'assets/diseases/coffee_bacterial_blight3.png',
      'assets/diseases/coffee_bacterial_blight4.png',
      'assets/diseases/coffee_bacterial_blight5.png',
    ],
  },
  'Coffee Anthracnose': {
    'description': 'Caused by Colletotrichum gloeosporioides and related species, '
        'anthracnose affects coffee berries, leaves, and stems especially during warm, wet seasons.',
    'symptoms': 'Sunken, dark-brown to black lesions on berries, leaves, and young shoots. '
        'Lesions on berries may show salmon-pink spore masses in humid conditions. '
        'Post-harvest, it causes rapid blackening and rotting of stored coffee berries.',
    'chemicalControls': [
      'Carbendazim',
      'Thiophanate-methyl',
      'Copper oxychloride',
      'Azoxystrobin'
    ],
    'biologicalControls': [
      'Trichoderma asperellum',
      'Bacillus amyloliquefaciens'
    ],
    'culturalControls': [
      'Harvest ripe berries promptly',
      'Remove infected berries',
      'Improve drainage'
    ],
    'possibleCauses': [
      'Warm, wet conditions during fruiting',
      'Injuries to berries from pests or hail',
      'Poor storage conditions (high moisture)',
      'Dense crop canopy',
    ],
    'preventiveMeasures': [
      'Spray preventive fungicides during berry development',
      'Harvest promptly — avoid overripe berries',
      'Store processed beans at below 12% moisture',
      'Clean and dry all processing equipment',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_anthracnose1.png',
      'assets/diseases/coffee_anthracnose2.png',
      'assets/diseases/coffee_anthracnose3.png',
      'assets/diseases/coffee_anthracnose4.png',
      'assets/diseases/coffee_anthracnose5.png',
      'assets/diseases/coffee_anthracnose6.png',
    ],
  },
  'Coffee Nursery Blight': {
    'description':
        'A complex nursery condition involving multiple fungal pathogens (Rhizoctonia, Phytophthora) '
            'causing widespread seedling collapse in poorly managed coffee nurseries.',
    'symptoms':
        'Mass wilting and death of seedlings in patches, brown water-soaked lesions at the base of stems, '
            'rapid spread through nursery beds, and associated mould growth on affected seedlings.',
    'chemicalControls': [
      'Metalaxyl + Mancozeb (Ridomil Gold)',
      'Copper oxychloride',
      'Carbendazim'
    ],
    'biologicalControls': [
      'Trichoderma harzianum',
      'Bacillus subtilis strain QST 713'
    ],
    'culturalControls': [
      'Sterilise nursery soil',
      'Remove and destroy affected seedlings immediately',
      'Improve drainage'
    ],
    'possibleCauses': [
      'Contaminated nursery soil or compost',
      'Overwatering and poor drainage',
      'Overcrowding of seedlings',
      'Reuse of infected nursery bags',
    ],
    'preventiveMeasures': [
      'Sterilise nursery soil before use',
      'Space seedlings adequately',
      'Use fresh certified nursery bags each season',
      'Apply preventive Trichoderma drench',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_nursery_blight1.png',
      'assets/diseases/coffee_nursery_blight2.png',
      'assets/diseases/coffee_nursery_blight3.png',
      'assets/diseases/coffee_nursery_blight4.png',
    ],
  },
  'Coffee Green Mold': {
    'description':
        'Caused by Penicillium spp. and Aspergillus spp., green and blue-green molds colonise '
            'improperly dried coffee beans during storage, rendering them unmarketable and potentially toxic.',
    'symptoms':
        'Blue-green or grey powdery mold growth on stored coffee beans, musty off-odour, '
            'discolouration of bean surface, and structural deterioration of the bean. '
            'Clumping of beans due to moisture absorption.',
    'chemicalControls': [
      'Proper drying to below 12% moisture (primary control — no chemical treatment for stored beans)'
    ],
    'biologicalControls': [
      'Biocontrol yeasts (experimental)',
      'Competitive exclusion with Pichia spp.'
    ],
    'culturalControls': [
      'Dry beans to correct moisture level',
      'Use airtight storage',
      'Monitor storage humidity',
      'Regular inspection'
    ],
    'possibleCauses': [
      'Storage at above 12% moisture content',
      'High relative humidity in storage',
      'Inadequate drying after processing',
      'Improper storage containers',
    ],
    'preventiveMeasures': [
      'Dry coffee to below 11–12% moisture before storage',
      'Use moisture meters to verify dryness',
      'Store in cool, well-ventilated, dry warehouses',
      'Use hermetic storage bags to exclude moisture',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_green_mold1.png',
      'assets/diseases/coffee_green_mold2.png',
      'assets/diseases/coffee_green_mold3.png',
      'assets/diseases/coffee_green_mold4.png',
    ],
  },
  'Coffee Ochratoxin A Contamination': {
    'description':
        'Ochratoxin A (OTA) is a mycotoxin produced by Aspergillus carbonarius and Aspergillus ochraceus '
            'in improperly stored or dried coffee. It is a serious food safety and export compliance concern.',
    'symptoms':
        'Not directly visible — OTA contamination has no reliable visual symptoms. '
            'Affected batches may show general mold growth, musty smell, or discoloured beans. '
            'Confirmation requires laboratory testing (ELISA or HPLC methods).',
    'chemicalControls': [
      'No chemical treatment for contaminated beans — prevention is the only control'
    ],
    'biologicalControls': [
      'Aflatoxin biocontrol agents (Aflasafe) reduce related mold risk',
      'Lactobacillus spp. fermentation'
    ],
    'culturalControls': [
      'Rapid drying after harvest',
      'Regular warehouse monitoring',
      'Segregation of damaged lots'
    ],
    'possibleCauses': [
      'Slow or incomplete drying of coffee beans',
      'Damaged or overripe berries at processing',
      'High-humidity storage environments',
      'Extended storage without moisture control',
    ],
    'preventiveMeasures': [
      'Harvest only fully ripe, undamaged berries',
      'Dry beans rapidly on raised drying tables',
      'Achieve below 12% moisture before storage',
      'Test beans for OTA before export',
    ],
    'lifecycleImages': [
      'assets/diseases/coffee_ota1.png',
      'assets/diseases/coffee_ota2.png',
      'assets/diseases/coffee_ota3.png',
    ],
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Detection mode enum
// ─────────────────────────────────────────────────────────────────────────────

enum _DetectionMode { none, knownBoth, knownStage, aiScan }

// ─────────────────────────────────────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class CoffeeDiseaseManagementPage extends StatefulWidget {
  final String? diseaseName;
  final String? coffeeStage;

  const CoffeeDiseaseManagementPage(
      {this.diseaseName, this.coffeeStage, super.key});

  @override
  State<CoffeeDiseaseManagementPage> createState() =>
      _CoffeeDiseaseManagementPageState();
}

class _CoffeeDiseaseManagementPageState
    extends State<CoffeeDiseaseManagementPage> with TickerProviderStateMixin {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _darkBrown = Color(0xFF3E2723);
  static const Color _midBrown = Color(0xFF6D4C41);
  static const Color _lightBrown = Color(0xFFA1887F);
  static const Color _cream = Color(0xFFFFF8F2);
  static const Color _amber = Color(0xFFFFCC80);

  // ── State ──────────────────────────────────────────────────────────────────
  _DetectionMode _activeMode = _DetectionMode.none;
  String? _selectedStage;
  String? _selectedDisease;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final ScrollController _scrollController = ScrollController();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _heroController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  late AnimationController _panelController;
  late Animation<double> _panelFade;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _panelController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _panelFade =
        CurvedAnimation(parent: _panelController, curve: Curves.easeOut);

    _heroController.forward();
    _initializeNotifications();

    // Deep-link: arrived with preset disease + stage
    if (widget.diseaseName != null && widget.coffeeStage != null) {
      _selectedStage = widget.coffeeStage;
      _selectedDisease = widget.diseaseName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToResults(
          stage: widget.coffeeStage!,
          disease: widget.diseaseName,
          mode: _DetectionMode.knownBoth,
        );
      });
    }
  }

  @override
  void dispose() {
    _heroController.dispose();
    _panelController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: initSettings);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _setMode(_DetectionMode mode) {
    setState(() {
      _activeMode = _activeMode == mode ? _DetectionMode.none : mode;
      _selectedStage = null;
      _selectedDisease = null;
    });
    _panelController.forward(from: 0);
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _navigateToResults({
    required String stage,
    required String? disease,
    required _DetectionMode mode,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: DiseaseResultsPage(
            selectedStage: stage,
            selectedDisease: disease,
            detectionMode: mode == _DetectionMode.knownBoth
                ? DiseaseDetectionMode.knownBoth
                : DiseaseDetectionMode.knownStage,
            localDiseaseData:
                disease != null && kDiseaseDetails.containsKey(disease)
                    ? _buildLocalDiseaseData(disease)
                    : null,
            notificationsPlugin: _notificationsPlugin,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _navigateToScan() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: DiseaseScanPage(notificationsPlugin: _notificationsPlugin),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  CoffeeDiseaseData _buildLocalDiseaseData(String diseaseName) {
    final d = kDiseaseDetails[diseaseName]!;
    return CoffeeDiseaseData(
      name: diseaseName,
      description: d['description'],
      symptoms: d['symptoms'],
      chemicalControls: List<String>.from(d['chemicalControls']),
      biologicalControls: List<String>.from(d['biologicalControls']),
      culturalControls: List<String>.from(d['culturalControls']),
      possibleCauses: List<String>.from(d['possibleCauses']),
      preventiveMeasures: List<String>.from(d['preventiveMeasures']),
      lifecycleImages: List<String>.from(d['lifecycleImages']),
      mechanicalControls: [],
    );
  }

  // ── Path A proceed ─────────────────────────────────────────────────────────

  void _proceedPathA() {
    if (_selectedStage == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a growth stage.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: _darkBrown,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_selectedDisease == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a disease name.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: _darkBrown,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    _navigateToResults(
      stage: _selectedStage!,
      disease: _selectedDisease,
      mode: _DetectionMode.knownBoth,
    );
  }

  // ── Path B proceed ─────────────────────────────────────────────────────────

  void _proceedPathB() {
    if (_selectedStage == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a growth stage first.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: _darkBrown,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    _navigateToResults(
      stage: _selectedStage!,
      disease: null,
      mode: _DetectionMode.knownStage,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverHero(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionLabel('Choose Detection Method'),
                const SizedBox(height: 12),

                // ── Mode cards ───────────────────────────────────────────────
                _buildModeCard(
                  mode: _DetectionMode.knownBoth,
                  icon: Icons.manage_search_rounded,
                  title: 'I Know the Disease',
                  subtitle:
                      'Select your growth stage and disease name for full management details.',
                  accentColor: const Color(0xFF6D4C41),
                ),
                const SizedBox(height: 10),
                _buildModeCard(
                  mode: _DetectionMode.knownStage,
                  icon: Icons.layers_rounded,
                  title: 'I Know the Growth Stage',
                  subtitle:
                      'AI lists all diseases likely affecting your crop at that stage with images.',
                  accentColor: const Color(0xFF8D6E63),
                ),
                const SizedBox(height: 10),
                _buildModeCard(
                  mode: _DetectionMode.aiScan,
                  icon: Icons.biotech_rounded,
                  title: 'Scan a Disease (AI)',
                  subtitle:
                      'Take or upload a photo — AI identifies the disease and provides treatment guidance.',
                  accentColor: _amber,
                  isActionCard: true,
                ),

                // ── Active input panel ────────────────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: FadeTransition(
                    opacity: _panelFade,
                    child: _activeMode == _DetectionMode.none
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: _activeMode == _DetectionMode.knownBoth
                                ? _buildPathAPanel()
                                : _buildPathBPanel(),
                          ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── History button ────────────────────────────────────────────
                _buildHistoryButton(),
                const SizedBox(height: 12),

                // ── AI info chip ─────────────────────────────────────────────
                _buildAiInfoChip(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver hero ────────────────────────────────────────────────────────────

  SliverAppBar _buildSliverHero() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: _darkBrown,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: SlideTransition(
          position: _heroSlide,
          child: FadeTransition(
            opacity: _heroFade,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3E2723), Color(0xFF6D4C41)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.biotech_rounded,
                            color: _amber, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'AI-POWERED · EAST AFRICA',
                          style: GoogleFonts.poppins(
                            color: _amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Coffee Disease\nDiagnostic Centre',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Identify, understand, and treat diseases attacking your '
                    'coffee crop — using AI image recognition or your knowledge '
                    'of the growth stage.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildStatChip(Icons.coronavirus_rounded, '12 Diseases'),
                      const SizedBox(width: 10),
                      _buildStatChip(Icons.layers_rounded, '4 Stages'),
                      const SizedBox(width: 10),
                      _buildStatChip(Icons.biotech_rounded, 'AI Scan'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _amber, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _darkBrown,
        letterSpacing: 0.2,
      ),
    );
  }

  // ── Mode card ──────────────────────────────────────────────────────────────

  Widget _buildModeCard({
    required _DetectionMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    bool isActionCard = false,
  }) {
    final isActive = _activeMode == mode;

    return GestureDetector(
      onTap: () {
        if (isActionCard) {
          _navigateToScan();
        } else {
          _setMode(mode);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isActive ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? accentColor : const Color(0xFFD7C5BC),
            width: isActive ? 0 : 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: .35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: .18)
                    : accentColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.white : accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : _darkBrown,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isActive
                          ? Colors.white.withValues(alpha: .8)
                          : const Color(0xFF8D6E63),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isActionCard
                  ? Icons.arrow_forward_ios_rounded
                  : (isActive
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded),
              color: isActive ? Colors.white70 : _lightBrown,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── PATH A PANEL ───────────────────────────────────────────────────────────

  Widget _buildPathAPanel() {
    final diseases =
        _selectedStage != null ? (kStageDiseases[_selectedStage] ?? []) : [];

    return _buildInputPanel(
      title: 'Select Your Stage & Disease',
      icon: Icons.checklist_rounded,
      children: [
        _buildStageDropdown(
          onChanged: (val) => setState(() {
            _selectedStage = val;
            _selectedDisease = null;
          }),
        ),
        const SizedBox(height: 14),
        _buildDiseaseDropdown(
          items: List<String>.from(diseases),
          enabled: _selectedStage != null,
          onChanged: (val) => setState(() => _selectedDisease = val),
        ),
        const SizedBox(height: 18),
        _buildProceedButton(
          label: 'View Disease Images & Treatment',
          icon: Icons.search_rounded,
          onTap: _proceedPathA,
        ),
      ],
    );
  }

  // ── PATH B PANEL ───────────────────────────────────────────────────────────

  Widget _buildPathBPanel() {
    return _buildInputPanel(
      title: 'Select the Growth Stage',
      icon: Icons.eco_rounded,
      children: [
        Text(
          'The AI will list all diseases likely affecting coffee at that stage, '
          'display images of each, and let you pick the one you observe.',
          style: GoogleFonts.poppins(
              fontSize: 12.5, color: _midBrown, height: 1.5),
        ),
        const SizedBox(height: 14),
        _buildStageDropdown(
          onChanged: (val) => setState(() {
            _selectedStage = val;
            _selectedDisease = null;
          }),
        ),
        const SizedBox(height: 18),
        _buildProceedButton(
          label: 'Show Possible Diseases for This Stage',
          icon: Icons.auto_fix_high_rounded,
          onTap: _proceedPathB,
        ),
      ],
    );
  }

  // ── Shared panel shell ─────────────────────────────────────────────────────

  Widget _buildInputPanel({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7C5BC)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _darkBrown, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _darkBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.brown.shade100, thickness: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ── Stage dropdown ─────────────────────────────────────────────────────────

  Widget _buildStageDropdown({required ValueChanged<String?> onChanged}) {
    return _buildStyledDropdown<String>(
      label: 'Coffee Growth Stage',
      hint: 'Select a stage',
      value: _selectedStage,
      items: kDiseaseStages,
      itemLabel: (s) => s,
      onChanged: onChanged,
      leadingIcon: Icons.layers_rounded,
    );
  }

  // ── Disease dropdown ───────────────────────────────────────────────────────

  Widget _buildDiseaseDropdown({
    required List<String> items,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: _buildStyledDropdown<String>(
          label: 'Disease Name',
          hint: enabled ? 'Select a disease' : 'Select a stage first',
          value: _selectedDisease,
          items: items,
          itemLabel: (s) => s,
          onChanged: onChanged,
          leadingIcon: Icons.coronavirus_rounded,
        ),
      ),
    );
  }

  // ── Generic styled dropdown ────────────────────────────────────────────────

  Widget _buildStyledDropdown<T>({
    required String label,
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    required IconData leadingIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7C5BC)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(fontSize: 13, color: _midBrown),
          border: InputBorder.none,
          prefixIcon: Icon(leadingIcon, color: _darkBrown, size: 20),
          contentPadding: EdgeInsets.zero,
        ),
        hint: Text(hint,
            style: GoogleFonts.poppins(fontSize: 13, color: _lightBrown)),
        isExpanded: true,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.expand_more_rounded, color: _midBrown),
        style: GoogleFonts.poppins(fontSize: 13.5, color: _darkBrown),
        items: items
            .map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ── Proceed button ─────────────────────────────────────────────────────────

  Widget _buildProceedButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkBrown,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: _darkBrown.withValues(alpha: .4),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
    );
  }

  // ── History button ─────────────────────────────────────────────────────────

  Widget _buildHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CoffeeUserDiseaseHistoryPage()),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkBrown,
          side: const BorderSide(color: _darkBrown, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.history_rounded, size: 18),
        label: Text(
          'View My Disease Diagnosis History',
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
    );
  }

  // ── AI info chip ────────────────────────────────────────────────────────────

  Widget _buildAiInfoChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _midBrown, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Powered by Gemini AI — tuned for East African coffee diseases '
              '(Kenya, Uganda, Tanzania, Ethiopia)',
              style: GoogleFonts.poppins(
                  fontSize: 11.5, color: _midBrown, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
