import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:coffeecore/models/coffee_disease_models.dart';
import 'package:coffeecore/screens/Disease%20Management/coffee_disease_intervention_page.dart';
import 'package:coffeecore/screens/Disease%20Management/coffee_user_disease_history_page.dart';

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
    extends State<CoffeeDiseaseManagementPage> {
  static final Color coffeeBrown = Colors.brown[700]!;
  static final Color backgroundColor = Colors.brown[50]!;
  String? _selectedStage;
  String? _selectedDisease;
  CoffeeDiseaseData? _diseaseData;
  bool _showDiseaseDetails = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _hintsKey = GlobalKey();

  final List<String> _stages = [
    'Vegetative Stage',
    'Flowering & Fruit Development',
    'Post-harvest / Storage',
  ];

  final Map<String, List<String>> _stageDiseases = {
    'Vegetative Stage': [
      'Coffee Leaf Rust',
      'Coffee Wilt Disease',
      'Cercospora Leaf Spot',
      'Brown Eye Spot',
      'Phytophthora Root Rot',
      'Bacterial Blight',
      'Coffee Sooty Mold',
      'Fusarium Root Rot',
    ],
    'Flowering & Fruit Development': [
      'Coffee Berry Disease',
      'Anthracnose',
      'Coffee Sooty Mold',
      'Bacterial Blight',
    ],
    'Post-harvest / Storage': [],
  };

  final Map<String, Map<String, dynamic>> _diseaseDetails = {
    'Coffee Leaf Rust': {
      'description':
          'A fungal disease that primarily affects the leaves of coffee plants.',
      'symptoms': 'Orange-yellow spots on the underside of leaves, leaf drop.',
      'chemicalControls': ['Copper-based', 'Trifloxystrobin', 'Tebuconazole'],
      'mechanicalControls': ['Pruning of infected leaves'],
      'biologicalControls': ['Resistant varieties (e.g., SL28)'],
      'possibleCauses': [
        'High humidity',
        'Warm temperatures (20-28°C)',
        'Dense foliage'
      ],
      'preventiveMeasures': [
        'Improve air circulation',
        'Apply mulch',
        'Use resistant varieties'
      ],
      'lifecycleImages': [
        'assets/diseases/coffee_leaf_rust1.png',
        'assets/diseases/coffee_leaf_rust2.png',
        'assets/diseases/coffee_leaf_rust3.png',
        'assets/diseases/coffee_leaf_rust4.png',
      ],
    },
    'Coffee Wilt Disease': {
      'description':
          'A soil-borne fungal infection that causes rapid wilting and death of coffee plants.',
      'symptoms': 'Sudden wilting, yellowing of leaves, and rotting of roots.',
      'chemicalControls': ['Thiophanate methyl', 'Carbendazim'],
      'mechanicalControls': ['Removal of infected plants'],
      'biologicalControls': ['Soil sterilization'],
      'possibleCauses': ['Wet soil', 'Poor drainage', 'Contaminated tools'],
      'preventiveMeasures': [
        'Improve drainage',
        'Sanitize tools',
        'Avoid overwatering'
      ],
      'lifecycleImages': [
        'assets/diseases/coffee_wilt_disease1.png',
        'assets/diseases/coffee_wilt_disease2.png',
        'assets/diseases/coffee_wilt_disease3.png',
        'assets/diseases/coffee_wilt_disease4.png',
      ],
    },
    'Coffee Berry Disease': {
      'description':
          'A fungal disease that causes dark lesions on coffee berries.',
      'symptoms': 'Black lesions on coffee cherries, premature fruit drop.',
      'chemicalControls': ['Azoxystrobin', 'Tebuconazole', 'Difenoconazole'],
      'mechanicalControls': ['Pruning and sanitation'],
      'biologicalControls': [],
      'possibleCauses': [
        'High rainfall',
        'Warm temperatures',
        'Poor sanitation'
      ],
      'preventiveMeasures': [
        'Regular pruning',
        'Remove fallen berries',
        'Improve air flow'
      ],
      'lifecycleImages': [
        'assets/diseases/coffee_berry_disease1.png',
        'assets/diseases/coffee_berry_disease2.png',
        'assets/diseases/coffee_berry_disease3.png',
        'assets/diseases/coffee_berry_disease4.png',
        'assets/diseases/coffee_berry_disease5.png',
        'assets/diseases/coffee_berry_disease6.png',
        'assets/diseases/coffee_berry_disease7.png',
        'assets/diseases/coffee_berry_disease8.png',
        'assets/diseases/coffee_berry_disease9.png',
        'assets/diseases/coffee_berry_disease10.png',
      ],
    },
    'Cercospora Leaf Spot': {
      'description': 'A fungal disease that affects coffee leaves.',
      'symptoms':
          'Dark brown to black lesions with yellow halos on the leaves.',
      'chemicalControls': ['Chlorothalonil', 'Mancozeb', 'Copper-based'],
      'mechanicalControls': ['Pruning of infected leaves'],
      'biologicalControls': [],
      'possibleCauses': [
        'High humidity',
        'Overcrowded plants',
        'Nutrient deficiency'
      ],
      'preventiveMeasures': [
        'Balance fertilization',
        'Prune regularly',
        'Avoid overhead watering'
      ],
      'lifecycleImages': [
        'assets/diseases/cercospora_leaf_spot1.png',
        'assets/diseases/cercospora_leaf_spot2.png',
        'assets/diseases/cercospora_leaf_spot3.png',
        'assets/diseases/cercospora_leaf_spot4.png',
        'assets/diseases/cercospora_leaf_spot5.png',
        'assets/diseases/cercospora_leaf_spot6.png',
        'assets/diseases/cercospora_leaf_spot7.png',
        'assets/diseases/cercospora_leaf_spot8.png',
        'assets/diseases/cercospora_leaf_spot9.png',
        'assets/diseases/cercospora_leaf_spot10.png',
        'assets/diseases/cercospora_leaf_spot11.png',
      ],
    },
    'Brown Eye Spot': {
      'description': 'A form of Cercospora disease affecting coffee plants.',
      'symptoms':
          'Round brown lesions surrounded by yellow halos, premature leaf drop.',
      'chemicalControls': ['Mancozeb', 'Chlorothalonil', 'Copper-based'],
      'mechanicalControls': ['Removal of infected leaves'],
      'biologicalControls': [],
      'possibleCauses': [
        'Wet conditions',
        'Poor air circulation',
        'Nutrient imbalance'
      ],
      'preventiveMeasures': [
        'Improve ventilation',
        'Monitor soil nutrients',
        'Remove debris'
      ],
      'lifecycleImages': [
        'assets/diseases/brown_eye_spot1.png',
        'assets/diseases/brown_eye_spot2.png',
        'assets/diseases/brown_eye_spot3.png',
        'assets/diseases/brown_eye_spot4.png',
      ],
    },
    'Anthracnose': {
      'description':
          'A fungal disease that affects coffee fruits, causing lesions and decay.',
      'symptoms': 'Sunken, dark lesions on fruit and branches.',
      'chemicalControls': ['Azoxystrobin', 'Tebuconazole', 'Difenoconazole'],
      'mechanicalControls': ['Removal of affected fruit'],
      'biologicalControls': [],
      'possibleCauses': ['High rainfall', 'Warm weather', 'Injured fruit'],
      'preventiveMeasures': [
        'Harvest carefully',
        'Sanitize tools',
        'Prune affected areas'
      ],
      'lifecycleImages': [
        'assets/diseases/anthracnose1.png',
        'assets/diseases/anthracnose2.png',
        'assets/diseases/anthracnose3.png',
        'assets/diseases/anthracnose4.png',
        'assets/diseases/anthracnose5.png',
        'assets/diseases/anthracnose6.png',
        'assets/diseases/anthracnose7.png',
        'assets/diseases/anthracnose8.png',
      ],
    },
    'Phytophthora Root Rot': {
      'description':
          'A waterborne pathogen that attacks the roots of coffee plants, causing rot.',
      'symptoms':
          'Yellowing of leaves, stunted growth, root decay, and poor plant vigor.',
      'chemicalControls': ['Metalaxyl', 'Phosphonates'],
      'mechanicalControls': ['Proper drainage to avoid waterlogging'],
      'biologicalControls': [],
      'possibleCauses': ['Excessive water', 'Poor drainage', 'High rainfall'],
      'preventiveMeasures': [
        'Improve soil drainage',
        'Avoid planting in low areas',
        'Mulch roots'
      ],
      'lifecycleImages': [
        'assets/diseases/phytophthora_root_rot1.png',
        'assets/diseases/phytophthora_root_rot2.png',
        'assets/diseases/phytophthora_root_rot3.png',
        'assets/diseases/phytophthora_root_rot4.png',
        'assets/diseases/phytophthora_root_rot5.png',
        'assets/diseases/phytophthora_root_rot6.png',
        'assets/diseases/phytophthora_root_rot7.png',
      ],
    },
    'Bacterial Blight': {
      'description': 'A bacterial infection that affects the coffee plant.',
      'symptoms':
          'Water-soaked lesions on leaves and stems, leading to wilting.',
      'chemicalControls': ['Copper-based bactericides'],
      'mechanicalControls': ['Removal of infected plant parts'],
      'biologicalControls': [],
      'possibleCauses': [
        'Wet conditions',
        'Wounds from pruning',
        'Contaminated tools'
      ],
      'preventiveMeasures': [
        'Sanitize equipment',
        'Avoid overhead irrigation',
        'Prune in dry weather'
      ],
      'lifecycleImages': [
        'assets/diseases/bacterial_blight1.png',
        'assets/diseases/bacterial_blight2.png',
        'assets/diseases/bacterial_blight3.png',
        'assets/diseases/bacterial_blight4.png',
        'assets/diseases/bacterial_blight5.png',
        'assets/diseases/bacterial_blight6.png',
        'assets/diseases/bacterial_blight7.png',
      ],
    },
    'Coffee Sooty Mold': {
      'description':
          'A fungal disease caused by mold growing on honeydew from sap-sucking insects.',
      'symptoms':
          'Black sooty growth on leaves and branches, reduced photosynthesis.',
      'chemicalControls': ['Insecticides (for sap-sucking pests)'],
      'mechanicalControls': ['Cleaning affected parts'],
      'biologicalControls': [],
      'possibleCauses': [
        'Presence of pests (e.g., mealybugs)',
        'High humidity',
        'Poor ventilation'
      ],
      'preventiveMeasures': [
        'Control pest populations',
        'Improve air circulation',
        'Clean leaves'
      ],
      'lifecycleImages': [
        'assets/diseases/coffee_sooty_mold1.png',
        'assets/diseases/coffee_sooty_mold2.png',
        'assets/diseases/coffee_sooty_mold3.png',
        'assets/diseases/coffee_sooty_mold4.png',
        'assets/diseases/coffee_sooty_mold5.png',
        'assets/diseases/coffee_sooty_mold6.png',
        'assets/diseases/coffee_sooty_mold7.png',
      ],
    },
    'Fusarium Root Rot': {
      'description':
          'A soil-borne fungal disease that attacks the roots and lower stems of coffee plants.',
      'symptoms':
          'Wilting, yellowing, and dieback of plants, with roots showing signs of rotting.',
      'chemicalControls': ['Thiophanate methyl', 'Carbendazim'],
      'mechanicalControls': ['Proper drainage', 'Removal of infected plants'],
      'biologicalControls': [],
      'possibleCauses': ['Wet soil', 'Poor drainage', 'Contaminated soil'],
      'preventiveMeasures': [
        'Enhance drainage',
        'Rotate crops',
        'Remove infected plants'
      ],
      'lifecycleImages': [
        'assets/diseases/fusarium_root_rot1.png',
        'assets/diseases/fusarium_root_rot2.png',
        'assets/diseases/fusarium_root_rot3.png',
        'assets/diseases/fusarium_root_rot4.png',
        'assets/diseases/fusarium_root_rot5.png',
        'assets/diseases/fusarium_root_rot6.png',
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    if (widget.diseaseName != null && widget.coffeeStage != null) {
      _selectedDisease = widget.diseaseName;
      _selectedStage = widget.coffeeStage;
      _updateDiseaseDetails();
      _showDiseaseDetails = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHints());
    }
  }

  @override
  void dispose() {
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

  void _updateDiseaseDetails() {
    if (_selectedDisease != null &&
        _diseaseDetails.containsKey(_selectedDisease!)) {
      setState(() {
        _diseaseData = CoffeeDiseaseData(
          name: _selectedDisease!,
          description: _diseaseDetails[_selectedDisease!]!['description'],
          symptoms: _diseaseDetails[_selectedDisease!]!['symptoms'],
          chemicalControls: List<String>.from(
              _diseaseDetails[_selectedDisease!]!['chemicalControls']),
          mechanicalControls: List<String>.from(
              _diseaseDetails[_selectedDisease!]!['mechanicalControls']),
          biologicalControls: List<String>.from(
              _diseaseDetails[_selectedDisease!]!['biologicalControls']),
          possibleCauses: List<String>.from(
              _diseaseDetails[_selectedDisease!]!['possibleCauses']),
          preventiveMeasures: List<String>.from(
              _diseaseDetails[_selectedDisease!]!['preventiveMeasures']),
          //lifecycleImages: List<String>.from(_diseaseDetails[_selectedDisease!]!['lifecycleImages']),
        );
      });
    }
  }

  void _scrollToHints() {
    if (_showDiseaseDetails && _hintsKey.currentContext != null) {
      final RenderBox box =
          _hintsKey.currentContext!.findRenderObject() as RenderBox;
      final position =
          box.localToGlobal(Offset.zero).dy + _scrollController.offset - 100;
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
        title: const Text('Coffee Disease Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              if (widget.diseaseName == null) ...[
                _buildDropdown('Coffee Stage', _stages, _selectedStage, (val) {
                  setState(() {
                    _selectedStage = val;
                    _selectedDisease = null;
                    _diseaseData = null;
                    _showDiseaseDetails = false;
                  });
                }),
                const SizedBox(height: 16),
                _buildDropdown(
                    'Select Disease',
                    _selectedStage != null
                        ? _stageDiseases[_selectedStage]!
                        : [],
                    _selectedDisease, (val) {
                  setState(() {
                    _selectedDisease = val;
                    _updateDiseaseDetails();
                    _showDiseaseDetails = false;
                  });
                }),
              ],
              if (_diseaseData != null) ...[
                const SizedBox(height: 16),
                //_buildLifecycleCarousel(_diseaseData!.lifecycleImages),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (_diseaseData != null) {
                    setState(() {
                      _showDiseaseDetails = !_showDiseaseDetails;
                      if (_showDiseaseDetails) {
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _scrollToHints());
                      }
                    });
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(
                        content: Text('Please select a disease first')));
                  }
                },
                child: Text(
                  _showDiseaseDetails
                      ? 'Hide Disease Management Details'
                      : 'View Disease Management Details',
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
                    MaterialPageRoute(
                        builder: (context) =>
                            const CoffeeUserDiseaseHistoryPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: coffeeBrown,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View My Disease History'),
              ),
              if (_showDiseaseDetails && _diseaseData != null) ...[
                const SizedBox(height: 8),
                Column(
                  key: _hintsKey,
                  children: [
                    _buildHintCard(
                        'Description', _diseaseData!.description, Icons.info),
                    _buildHintCard(
                        'Symptoms', _diseaseData!.symptoms, Icons.warning),
                    _buildHintCard(
                        'Chemical Controls',
                        _diseaseData!.chemicalControls.join('\n'),
                        Icons.science),
                    _buildHintCard(
                        'Mechanical Controls',
                        _diseaseData!.mechanicalControls.isEmpty
                            ? 'None'
                            : _diseaseData!.mechanicalControls.join('\n'),
                        Icons.build),
                    _buildHintCard(
                        'Biological Controls',
                        _diseaseData!.biologicalControls.isEmpty
                            ? 'None'
                            : _diseaseData!.biologicalControls.join('\n'),
                        Icons.eco),
                    _buildHintCard('Possible Causes',
                        _diseaseData!.possibleCauses.join('\n'), Icons.search),
                    _buildHintCard(
                        'Preventive Measures',
                        _diseaseData!.preventiveMeasures.join('\n'),
                        Icons.shield),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CoffeeDiseaseInterventionPage(
                                diseaseData: _diseaseData!,
                                cropStage: _selectedStage ?? '',
                                notificationsPlugin: _notificationsPlugin,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: coffeeBrown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Manage Disease'),
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

  Widget _buildDropdown(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
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

  /*Widget _buildLifecycleCarousel(List<String> images) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Disease Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: coffeeBrown)),
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
  }*/

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
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: coffeeBrown)),
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
