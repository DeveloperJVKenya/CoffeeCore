import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:coffeecore/models/coffee_pest_models.dart';
import 'package:coffeecore/screens/Pest%20Management/coffee_intervention_page.dart';
import 'package:coffeecore/screens/Pest%20Management/coffee_user_pest_history.dart';

class CoffeePestManagementPage extends StatefulWidget {
  final String? pestName;
  final String? coffeeStage;

  const CoffeePestManagementPage({this.pestName, this.coffeeStage, super.key});

  @override
  State<CoffeePestManagementPage> createState() => _CoffeePestManagementPageState();
}

class _CoffeePestManagementPageState extends State<CoffeePestManagementPage> {
  static final Color coffeeBrown = Colors.brown[700]!;
  static final Color backgroundColor = Colors.brown[50]!;
  String? _selectedStage;
  String? _selectedPest;
  CoffeePestData? _pestData;
  bool _showPestDetails = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _hintsKey = GlobalKey();

  // Coffee growth stages
  final List<String> _stages = [
    'Vegetative Stage',
    'Flowering & Fruit Development',
    'Post-harvest / Storage',
  ];

  // Pests by stage
  final Map<String, List<String>> _stagePests = {
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

  // Pest details with lifecycle stages
  final Map<String, Map<String, dynamic>> _pestDetails = {
    'Coffee Berry Borer': {
      'description': 'A small beetle that bores into coffee cherries to lay eggs, and the larvae feed on the beans inside.',
      'symptoms': 'Infested cherries have small holes, and the beans are damaged, with powdery frass or larvae inside.',
      'chemicalControls': ['Imidacloprid', 'Lambda-cyhalothrin'],
      'mechanicalControls': ['Pheromone traps'],
      'biologicalControls': ['Parasitoid wasps'],
      'possibleCauses': ['Warm temperatures (25-30°C)', 'High humidity', 'Poor sanitation'],
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
      'symptoms': 'Irregular, silvery streaks or tunnels on leaves, with premature leaf drop in severe cases.',
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
      'symptoms': 'Deformed or discolored cherries, premature fruit drop, sticky honeydew on leaves or fruits.',
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
      'symptoms': 'Yellowing leaves, sticky honeydew, sooty mold, cloud of white insects when disturbed.',
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
      'symptoms': 'White, waxy insects or cotton-like masses on leaves or stems, sticky honeydew, sooty mold.',
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
      'symptoms': 'Irregular holes in leaves or fruits, skeletonized leaves, visible caterpillars, silk threads.',
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
      'symptoms': 'Holes in stored coffee beans, damaged or hollowed-out beans, powdery debris in storage.',
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
      'symptoms': 'Small, flat, oval insects or waxy shells on leaves or stems, sticky honeydew, sooty mold.',
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

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    if (widget.pestName != null && widget.coffeeStage != null) {
      _selectedPest = widget.pestName;
      _selectedStage = widget.coffeeStage;
      _updatePestDetails();
      _showPestDetails = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHints());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: initSettings);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _updatePestDetails() {
    if (_selectedPest != null && _pestDetails.containsKey(_selectedPest!)) {
      setState(() {
        _pestData = CoffeePestData(
          name: _selectedPest!,
          description: _pestDetails[_selectedPest!]!['description'],
          symptoms: _pestDetails[_selectedPest!]!['symptoms'],
          chemicalControls: List<String>.from(_pestDetails[_selectedPest!]!['chemicalControls']),
          mechanicalControls: List<String>.from(_pestDetails[_selectedPest!]!['mechanicalControls']),
          biologicalControls: List<String>.from(_pestDetails[_selectedPest!]!['biologicalControls']),
          possibleCauses: List<String>.from(_pestDetails[_selectedPest!]!['possibleCauses']),
          preventiveMeasures: List<String>.from(_pestDetails[_selectedPest!]!['preventiveMeasures']),
          lifecycleImages: List<String>.from(_pestDetails[_selectedPest!]!['lifecycleImages']),
        );
      });
    }
  }

  void _scrollToHints() {
    if (_showPestDetails && _hintsKey.currentContext != null) {
      final RenderBox box = _hintsKey.currentContext!.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero).dy + _scrollController.offset - 100;
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffee Pest Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: coffeeBrown,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: backgroundColor,
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.pestName == null) ...[
                _buildDropdown('Coffee Stage', _stages, _selectedStage, (val) {
                  setState(() {
                    _selectedStage = val;
                    _selectedPest = null;
                    _pestData = null;
                    _showPestDetails = false;
                  });
                }),
                const SizedBox(height: 16),
                _buildDropdown('Select Pest', _selectedStage != null ? _stagePests[_selectedStage]! : [], _selectedPest, (val) {
                  setState(() {
                    _selectedPest = val;
                    _updatePestDetails();
                    _showPestDetails = false;
                  });
                }),
              ],
              if (_pestData != null) ...[
                const SizedBox(height: 16),
                _buildLifecycleCarousel(_pestData!.lifecycleImages),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (_pestData != null) {
                    setState(() {
                      _showPestDetails = !_showPestDetails;
                      if (_showPestDetails) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHints());
                      }
                    });
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please select a pest first')));
                  }
                },
                child: Text(
                  _showPestDetails ? 'Hide Pest Management Details' : 'View Pest Management Details',
                  style: TextStyle(
                    color: coffeeBrown,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CoffeeUserPestHistoryPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: coffeeBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View My Pest History'),
              ),
              if (_showPestDetails && _pestData != null) ...[
                const SizedBox(height: 8),
                Column(
                  key: _hintsKey,
                  children: [
                    _buildHintCard('Description', _pestData!.description, Icons.info),
                    _buildHintCard('Symptoms', _pestData!.symptoms, Icons.warning),
                    _buildHintCard('Chemical Controls', _pestData!.chemicalControls.join('\n'), Icons.science),
                    _buildHintCard('Mechanical Controls', _pestData!.mechanicalControls.isEmpty ? 'None' : _pestData!.mechanicalControls.join('\n'), Icons.build),
                    _buildHintCard('Biological Controls', _pestData!.biologicalControls.isEmpty ? 'None' : _pestData!.biologicalControls.join('\n'), Icons.eco),
                    _buildHintCard('Possible Causes', _pestData!.possibleCauses.join('\n'), Icons.search),
                    _buildHintCard('Preventive Measures', _pestData!.preventiveMeasures.join('\n'), Icons.shield),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CoffeeInterventionPage(
                                pestData: _pestData!,
                                cropStage: _selectedStage ?? '',
                                notificationsPlugin: _notificationsPlugin,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: coffeeBrown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Manage Pest'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLifecycleCarousel(List<String> images) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pest Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: coffeeBrown)),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.asset(
                      images[index],
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 120),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintCard(String title, String content, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: coffeeBrown, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: coffeeBrown)),
                  const SizedBox(height: 8),
                  Text(content, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}