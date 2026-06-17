import 'package:coffeecore/screens/pests/pest_results_page.dart';
import 'package:coffeecore/screens/pests/pest_scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coffeecore/models/coffee_pest_models.dart';
//import 'package:coffeecore/screens/Pest%20Management/pest_scan_page.dart';
//import 'package:coffeecore/screens/Pest%20Management/pest_results_page.dart';
import 'package:coffeecore/screens/Pest%20Management/coffee_user_pest_history.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHARED PEST DATA — accessed by PestResultsPage as a local fallback
// ─────────────────────────────────────────────────────────────────────────────

const List<String> kCoffeeStages = [
  'Vegetative Stage',
  'Flowering & Fruit Development',
  'Post-harvest / Storage',
];

const Map<String, List<String>> kStagePests = {
  'Vegetative Stage': [
    'Coffee Leaf Miner',
    'Coffee Stem Borer',
    'Root-Knot Nematodes',
    'White Flies',
    'Coffee Mealybug',
    'Caterpillars',
    'Ants',
    'Scale Insects',
    'Thrips',
  ],
  'Flowering & Fruit Development': [
    'Coffee Berry Borer',
    'Coffee Antestia Bug',
    'White Flies',
    'Coffee Mealybug',
    'Caterpillars',
    'Ants',
    'Scale Insects',
    'Thrips',
  ],
  'Post-harvest / Storage': ['Coffee Weevil'],
};

final Map<String, Map<String, dynamic>> kPestDetails = {
  'Coffee Berry Borer': {
    'description':
        'A small beetle that bores into coffee cherries to lay eggs, and the larvae feed on the beans inside.',
    'symptoms':
        'Infested cherries have small holes, and the beans are damaged, with powdery frass or larvae inside.',
    'chemicalControls': ['Imidacloprid', 'Lambda-cyhalothrin'],
    'mechanicalControls': ['Pheromone traps'],
    'biologicalControls': ['Parasitoid wasps'],
    'possibleCauses': ['Warm temperatures (25–30°C)', 'High humidity', 'Poor sanitation'],
    'preventiveMeasures': ['Regular harvesting', 'Sanitation of fallen cherries', 'Shade management'],
    'lifecycleImages': [
      'assets/pests/coffee_berry_borer1.png',
      'assets/pests/coffee_berry_borer2.png',
      'assets/pests/coffee_berry_borer3.png',
      'assets/pests/coffee_berry_borer4.png',
      'assets/pests/coffee_berry_borers.png',
      'assets/pests/coffee_berry_borer5.png',
      'assets/pests/coffee_berry_borer6.png',
      'assets/pests/coffee_berry_borer7.png',
      'assets/pests/coffee_berry_borer8.png',
      'assets/pests/coffee_berry_borer9.png',
      'assets/pests/coffee_berry_borer10.png',
    ],
  },
  'Coffee Leaf Miner': {
    'description': 'A small moth whose larvae mine the leaves of coffee plants.',
    'symptoms':
        'Irregular, silvery streaks or tunnels on leaves, with premature leaf drop in severe cases.',
    'chemicalControls': ['Malathion', 'Permethrin'],
    'mechanicalControls': [],
    'biologicalControls': ['Parasitoid wasps'],
    'possibleCauses': ['Warm, dry conditions', 'Overcrowded plants'],
    'preventiveMeasures': ['Monitor leaf health', 'Avoid dense planting'],
    'lifecycleImages': [
      'assets/pests/coffee_leaf_miner1.png',
      'assets/pests/coffee_leaf_miner2.png',
      'assets/pests/coffee_leaf_miner3.png',
      'assets/pests/coffee_leaf_miner4.png',
      'assets/pests/coffee_leaf_miner5.png',
      'assets/pests/coffee_leaf_miner6.png',
      'assets/pests/coffee_leaf_miner7.png',
      'assets/pests/coffee_leaf_miner8.png',
      'assets/pests/coffee_leaf_miner9.png',
      'assets/pests/coffee_leaf_miner10.png',
    ],
  },
  'Coffee Antestia Bug': {
    'description': 'A sap-sucking bug that damages coffee berries.',
    'symptoms':
        'Deformed or discolored cherries, premature fruit drop, sticky honeydew on leaves or fruits.',
    'chemicalControls': ['Cypermethrin', 'Lambda-cyhalothrin', 'Deltamethrin'],
    'mechanicalControls': ['Pruning and cleaning practices'],
    'biologicalControls': [],
    'possibleCauses': ['High rainfall', 'Poor pruning'],
    'preventiveMeasures': ['Regular pruning', 'Field hygiene'],
    'lifecycleImages': [
      'assets/pests/coffee_antestia_bug1.png',
      'assets/pests/coffee_antestia_bug2.png',
      'assets/pests/coffee_antestia_bug3.png',
      'assets/pests/coffee_antestia_bug4.png',
      'assets/pests/coffee_antestia_bug5.png',
      'assets/pests/coffee_antestia_bug6.png',
    ],
  },
  'Coffee Stem Borer': {
    'description': 'A beetle that bores into the stems and branches of coffee plants.',
    'symptoms': 'Holes in stems or branches, sawdust-like frass, weakened or snapping branches.',
    'chemicalControls': ['Carbaryl', 'Permethrin'],
    'mechanicalControls': ['Pruning of infested branches'],
    'biologicalControls': [],
    'possibleCauses': ['High altitude', 'Old plants'],
    'preventiveMeasures': ['Remove infested branches', 'Plant health monitoring'],
    'lifecycleImages': [
      'assets/pests/coffee_stem_borer1.png',
      'assets/pests/coffee_stem_borer2.png',
      'assets/pests/coffee_stem_borer3.png',
      'assets/pests/coffee_stem_borer4.png',
      'assets/pests/coffee_stem_borer5.png',
      'assets/pests/coffee_stem_borer6.png',
      'assets/pests/coffee_stem_borer7.png',
      'assets/pests/coffee_stem_borer8.png',
    ],
  },
  'Root-Knot Nematodes': {
    'description': 'Nematodes that attack the roots of coffee plants, causing galls.',
    'symptoms': 'Swollen or knotted roots, yellowing leaves, wilting despite adequate watering.',
    'chemicalControls': ['Fenamiphos', 'Oxamyl', 'Carbofuran'],
    'mechanicalControls': [],
    'biologicalControls': [],
    'possibleCauses': ['Warm, moist soil', 'Continuous cropping'],
    'preventiveMeasures': ['Crop rotation', 'Soil solarization'],
    'lifecycleImages': [
      'assets/pests/root_knot_nematodes1.png',
      'assets/pests/root_knot_nematodes2.png',
      'assets/pests/root_knot_nematodes3.png',
      'assets/pests/root_knot_nematodes4.png',
      'assets/pests/root_knot_nematodes5.png',
      'assets/pests/root_knot_nematodes6.png',
      'assets/pests/root_knot_nematodes7.png',
    ],
  },
  'White Flies': {
    'description': 'Tiny white flying insects that suck sap from coffee plants.',
    'symptoms':
        'Yellowing leaves, sticky honeydew, sooty mold, cloud of white insects when disturbed.',
    'chemicalControls': ['Imidacloprid', 'Lambda-cyhalothrin'],
    'mechanicalControls': [],
    'biologicalControls': ['Natural predators like ladybugs'],
    'possibleCauses': ['Warm, humid conditions', 'Poor ventilation'],
    'preventiveMeasures': ['Encourage natural predators', 'Improve air circulation'],
    'lifecycleImages': [
      'assets/pests/white_flies1.png',
      'assets/pests/white_flies2.png',
      'assets/pests/white_flies3.png',
      'assets/pests/white_flies4.png',
      'assets/pests/white_flies5.png',
      'assets/pests/white_flies6.png',
      'assets/pests/white_flies7.png',
      'assets/pests/white_flies8.png',
    ],
  },
  'Coffee Mealybug': {
    'description': 'Sap-sucking insect covered with a waxy coating.',
    'symptoms':
        'White, waxy insects or cotton-like masses on leaves or stems, sticky honeydew, sooty mold.',
    'chemicalControls': ['Imidacloprid', 'Pyrethrins', 'Malathion'],
    'mechanicalControls': [],
    'biologicalControls': ['Parasitoid wasps'],
    'possibleCauses': ['High humidity', 'Ant presence'],
    'preventiveMeasures': ['Control ant populations', 'Monitor plant health'],
    'lifecycleImages': [
      'assets/pests/coffee_mealybug1.png',
      'assets/pests/coffee_mealybug2.png',
      'assets/pests/coffee_mealybug3.png',
      'assets/pests/coffee_mealybug4.png',
      'assets/pests/coffee_mealybug5.png',
      'assets/pests/coffee_mealybug6.png',
      'assets/pests/coffee_mealybug7.png',
      'assets/pests/coffee_mealybug8.png',
      'assets/pests/coffee_mealybug9.png',
      'assets/pests/coffee_mealybug10.png',
    ],
  },
  'Caterpillars': {
    'description': 'Larvae of moths that feed on coffee leaves and fruit.',
    'symptoms':
        'Irregular holes in leaves or fruits, skeletonized leaves, visible caterpillars, silk threads.',
    'chemicalControls': ['Bacillus thuringiensis (Bt)'],
    'mechanicalControls': [],
    'biologicalControls': ['Trichogramma spp.'],
    'possibleCauses': ['Warm, wet conditions', 'Nearby host plants'],
    'preventiveMeasures': ['Remove debris', 'Monitor for eggs'],
    'lifecycleImages': [
      'assets/pests/caterpillar1.png',
      'assets/pests/caterpillar2.png',
      'assets/pests/caterpillar3.png',
      'assets/pests/caterpillar4.png',
      'assets/pests/caterpillar5.png',
      'assets/pests/caterpillar6.png',
      'assets/pests/caterpillar7.png',
      'assets/pests/caterpillar8.png',
      'assets/pests/caterpillar9.png',
      'assets/pests/caterpillar10.png',
    ],
  },
  'Coffee Weevil': {
    'description': 'A pest that attacks stored coffee beans.',
    'symptoms':
        'Holes in stored coffee beans, damaged or hollowed-out beans, powdery debris in storage.',
    'chemicalControls': ['Permethrin'],
    'mechanicalControls': ['Proper storage conditions', 'Fumigation'],
    'biologicalControls': [],
    'possibleCauses': ['High moisture in storage', 'Infested beans'],
    'preventiveMeasures': ['Dry beans thoroughly', 'Use airtight storage'],
    'lifecycleImages': [
      'assets/pests/coffee_weevil1.png',
      'assets/pests/coffee_weevil2.png',
      'assets/pests/coffee_weevil3.png',
      'assets/pests/coffee_weevil4.png',
      'assets/pests/coffee_weevil5.png',
      'assets/pests/coffee_weevil6.png',
    ],
  },
  'Ants': {
    'description': 'Certain ants protect and farm pests like aphids or mealybugs.',
    'symptoms': 'Presence of ants tending pests, sticky honeydew on leaves or fruits, ant trails on stems.',
    'chemicalControls': ['Permethrin', 'Cypermethrin'],
    'mechanicalControls': ['Ant baits'],
    'biologicalControls': [],
    'possibleCauses': ['Presence of sap-sucking pests', 'Warm weather'],
    'preventiveMeasures': ['Control sap-sucking pests', 'Use ant barriers'],
    'lifecycleImages': [
      'assets/pests/ants1.png',
      'assets/pests/ants2.png',
      'assets/pests/ants3.png',
      'assets/pests/ants4.png',
      'assets/pests/antaffectedplant.png',
      'assets/pests/ants5.png',
      'assets/pests/ants6.png',
      'assets/pests/ants7.png',
      'assets/pests/ants8.png',
    ],
  },
  'Scale Insects': {
    'description': 'Small insects with waxy shells that suck sap from coffee plants.',
    'symptoms':
        'Small, flat, oval insects or waxy shells on leaves or stems, sticky honeydew, sooty mold.',
    'chemicalControls': ['Imidacloprid', 'Horticultural oil'],
    'mechanicalControls': ['Pruning affected parts'],
    'biologicalControls': ['Ladybugs', 'Parasitoid wasps'],
    'possibleCauses': ['Warm, humid conditions', 'Poor plant health'],
    'preventiveMeasures': ['Monitor plant health', 'Improve air circulation'],
    'lifecycleImages': [
      'assets/pests/scale_insects1.png',
      'assets/pests/scale_insects2.png',
      'assets/pests/scale_insects3.png',
      'assets/pests/scale_insects4.png',
      'assets/pests/scale_insects5.png',
      'assets/pests/scale_insects6.png',
    ],
  },
  'Thrips': {
    'description': 'Tiny, slender insects that feed on leaves, fruits, and flowers.',
    'symptoms': 'Silvering or bronzing of leaves, tiny insects on leaves or flowers, deformed buds.',
    'chemicalControls': ['Spinosad', 'Imidacloprid'],
    'mechanicalControls': [],
    'biologicalControls': ['Predatory mites'],
    'possibleCauses': ['Dry conditions', 'Nearby host plants'],
    'preventiveMeasures': ['Remove weeds', 'Monitor for early signs'],
    'lifecycleImages': [
      'assets/pests/thrips1.png',
      'assets/pests/thrips2.png',
      'assets/pests/thrips3.png',
      'assets/pests/thrips4.png',
      'assets/pests/thrips5.png',
      'assets/pests/thrips6.png',
      'assets/pests/thrips7.png',
      'assets/pests/thrips8.png',
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

class CoffeePestManagementPage extends StatefulWidget {
  final String? pestName;
  final String? coffeeStage;

  const CoffeePestManagementPage({this.pestName, this.coffeeStage, super.key});

  @override
  State<CoffeePestManagementPage> createState() =>
      _CoffeePestManagementPageState();
}

class _CoffeePestManagementPageState extends State<CoffeePestManagementPage>
    with TickerProviderStateMixin {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _darkBrown = Color(0xFF3E2723);
  static const Color _midBrown = Color(0xFF6D4C41);
  static const Color _lightBrown = Color(0xFFA1887F);
  static const Color _cream = Color(0xFFFFF8F2);
  static const Color _amber = Color(0xFFFFCC80);

  // ── State ──────────────────────────────────────────────────────────────────
  _DetectionMode _activeMode = _DetectionMode.none;
  String? _selectedStage;
  String? _selectedPest;

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
    _heroFade =
        CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _panelController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _panelFade =
        CurvedAnimation(parent: _panelController, curve: Curves.easeOut);

    _heroController.forward();
    _initializeNotifications();

    // Deep-link: arrived with preset pest + stage
    if (widget.pestName != null && widget.coffeeStage != null) {
      _selectedStage = widget.coffeeStage;
      _selectedPest = widget.pestName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToResults(
          stage: widget.coffeeStage!,
          pest: widget.pestName,
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
      _selectedPest = null;
    });
    _panelController.forward(from: 0);
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _navigateToResults({
    required String stage,
    required String? pest,
    required _DetectionMode mode,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: PestResultsPage(
            selectedStage: stage,
            selectedPest: pest,
            detectionMode: mode == _DetectionMode.knownBoth
                ? PestDetectionMode.knownBoth
                : PestDetectionMode.knownStage,
            localPestData: pest != null && kPestDetails.containsKey(pest)
                ? _buildLocalPestData(pest)
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
          child: PestScanPage(notificationsPlugin: _notificationsPlugin),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  CoffeePestData _buildLocalPestData(String pestName) {
    final d = kPestDetails[pestName]!;
    return CoffeePestData(
      name: pestName,
      description: d['description'],
      symptoms: d['symptoms'],
      chemicalControls: List<String>.from(d['chemicalControls']),
      mechanicalControls: List<String>.from(d['mechanicalControls']),
      biologicalControls: List<String>.from(d['biologicalControls']),
      possibleCauses: List<String>.from(d['possibleCauses']),
      preventiveMeasures: List<String>.from(d['preventiveMeasures']),
      lifecycleImages: List<String>.from(d['lifecycleImages']),
    );
  }

  // ── Proceed guard for Path A ───────────────────────────────────────────────

  void _proceedPathA() {
    if (_selectedStage == null) {
      _showSnack('Please select a growth stage first.');
      return;
    }
    if (_selectedPest == null) {
      _showSnack('Please select a pest to continue.');
      return;
    }
    _navigateToResults(
      stage: _selectedStage!,
      pest: _selectedPest,
      mode: _DetectionMode.knownBoth,
    );
  }

  // ── Proceed guard for Path B ───────────────────────────────────────────────

  void _proceedPathB() {
    if (_selectedStage == null) {
      _showSnack('Please select a growth stage first.');
      return;
    }
    _navigateToResults(
      stage: _selectedStage!,
      pest: null,
      mode: _DetectionMode.knownStage,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.poppins())));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroHeader(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionLabel('How would you like to identify the pest?'),
                  const SizedBox(height: 12),

                  // ── Three mode cards ──────────────────────────────────────
                  _buildModeCard(
                    mode: _DetectionMode.knownBoth,
                    icon: Icons.checklist_rounded,
                    title: 'I Know the Stage & Pest',
                    subtitle:
                        'Select the growth stage and the specific pest you are seeing.',
                    accentColor: _darkBrown,
                  ),
                  const SizedBox(height: 10),
                  _buildModeCard(
                    mode: _DetectionMode.knownStage,
                    icon: Icons.eco_rounded,
                    title: 'I Know Only the Growth Stage',
                    subtitle:
                        'Select the stage — AI will list likely pests with images to help you identify.',
                    accentColor: _midBrown,
                  ),
                  const SizedBox(height: 10),
                  _buildModeCard(
                    mode: _DetectionMode.aiScan,
                    icon: Icons.document_scanner_rounded,
                    title: 'Scan/Capture with Camera',
                    subtitle:
                        'Take or upload a photo of the affected crop — CoffeeCore AI will identify the pest.',
                    accentColor: _lightBrown,
                    isActionCard: true,
                  ),

                  // ── Expanding panel ───────────────────────────────────────
                  if (_activeMode == _DetectionMode.knownBoth) ...[
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _panelFade,
                      child: _buildPathAPanel(),
                    ),
                  ],
                  if (_activeMode == _DetectionMode.knownStage) ...[
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _panelFade,
                      child: _buildPathBPanel(),
                    ),
                  ],

                  const SizedBox(height: 24),
                  _buildHistoryButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _darkBrown,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Pest Management',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: 0.3,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'My Pest History',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CoffeeUserPestHistoryPage()),
          ),
          icon: const Icon(Icons.history_rounded, color: Colors.white),
        ),
      ],
    );
  }

  // ── Hero Header ────────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return SlideTransition(
      position: _heroSlide,
      child: FadeTransition(
        opacity: _heroFade,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_darkBrown, _midBrown],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _amber.withValues(alpha: .5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: _amber, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Powered by CoffeeCore AI',
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
              const SizedBox(height: 16),
              Text(
                'Coffee Pest\nDiagnostic Centre',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Identify, understand, and manage pests attacking your '
                'coffee crop — using AI image recognition or your knowledge '
                'of the growth stage.',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Quick-stat row
              Row(
                children: [
                  _buildStatChip(Icons.bug_report_rounded, '12 Pests'),
                  const SizedBox(width: 10),
                  _buildStatChip(Icons.layers_rounded, '3 Stages'),
                  const SizedBox(width: 10),
                  _buildStatChip(Icons.camera_alt_rounded, 'AI Scan'),
                ],
              ),
            ],
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
            // Icon bubble
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

            // Text
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

            // Arrow / chevron
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

  // ── PATH A PANEL — Both stage & pest known ─────────────────────────────────

  Widget _buildPathAPanel() {
    final pests =
        _selectedStage != null ? (kStagePests[_selectedStage] ?? []) : [];

    return _buildInputPanel(
      title: 'Select Your Stage & Pest',
      icon: Icons.checklist_rounded,
      children: [
        _buildStageDropdown(
          onChanged: (val) => setState(() {
            _selectedStage = val;
            _selectedPest = null;
          }),
        ),
        const SizedBox(height: 14),
        _buildPestDropdown(
          items: List<String>.from(pests),
          enabled: _selectedStage != null,
          onChanged: (val) => setState(() => _selectedPest = val),
        ),
        const SizedBox(height: 18),
        _buildProceedButton(
          label: 'View Pest Images & Management',
          icon: Icons.search_rounded,
          onTap: _proceedPathA,
        ),
      ],
    );
  }

  // ── PATH B PANEL — Stage known, pest unknown ───────────────────────────────

  Widget _buildPathBPanel() {
    return _buildInputPanel(
      title: 'Select the Growth Stage',
      icon: Icons.eco_rounded,
      children: [
        Text(
          'The AI will list all pests likely attacking coffee at that stage, '
          'display images of each, and let you pick the one you see.',
          style: GoogleFonts.poppins(
              fontSize: 12.5, color: _midBrown, height: 1.5),
        ),
        const SizedBox(height: 14),
        _buildStageDropdown(
          onChanged: (val) => setState(() {
            _selectedStage = val;
            _selectedPest = null;
          }),
        ),
        const SizedBox(height: 18),
        _buildProceedButton(
          label: 'Show Possible Pests for This Stage',
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
      items: kCoffeeStages,
      itemLabel: (s) => s,
      onChanged: onChanged,
      leadingIcon: Icons.layers_rounded,
    );
  }

  // ── Pest dropdown ──────────────────────────────────────────────────────────

  Widget _buildPestDropdown({
    required List<String> items,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: _buildStyledDropdown<String>(
          label: 'Pest Name',
          hint: enabled ? 'Select a pest' : 'Select a stage first',
          value: _selectedPest,
          items: items,
          itemLabel: (s) => s,
          onChanged: onChanged,
          leadingIcon: Icons.bug_report_rounded,
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
          labelStyle:
              GoogleFonts.poppins(fontSize: 13, color: _midBrown),
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
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
    );
  }

  // ── History button ─────────────────────────────────────────────────────────

  Widget _buildHistoryButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CoffeeUserPestHistoryPage()),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _darkBrown,
        side: const BorderSide(color: _darkBrown, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.history_rounded, size: 18),
      label: Text(
        'View My Pest Diagnosis History',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    );
  }
}