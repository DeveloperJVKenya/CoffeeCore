import 'package:coffeecore/screens/Symptom%20Analysis/coffee_disease_symptom_analysis_page.dart';
import 'package:coffeecore/screens/Symptom%20Analysis/coffee_pest_symptom_analysis_page.dart';
import 'package:flutter/material.dart';

class CoffeeSymptomCheckerPage extends StatefulWidget {
  const CoffeeSymptomCheckerPage({super.key});

  @override
  State<CoffeeSymptomCheckerPage> createState() =>
      _CoffeeSymptomCheckerPageState();
}

class _CoffeeSymptomCheckerPageState extends State<CoffeeSymptomCheckerPage>
    with SingleTickerProviderStateMixin {
  static final Color coffeeBrown = Colors.brown[700]!;
  static final Color backgroundColor = Colors.brown[50]!;

  final Map<String, Map<String, List<Map<String, dynamic>>>> symptoms = {
    'Roots': {
      'Pests': [
        {
          'symptom': 'Swollen or knotted roots',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Wilting despite adequate watering',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Tiny worms in soil near roots',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Yellowing lower leaves',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {'symptom': 'Stunted root growth', 'weight': 0.8, 'cluster': 'unique'},
        {
          'symptom': 'Roots with small, irregular tunnels or holes',
          'weight': 0.8,
          'cluster': 'unique'
        },
      ],
      'Diseases': [
        {
          'symptom': 'Blackened or rotten roots',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Soft, mushy roots with a foul smell',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'White fungal threads or growth on roots',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Stunted growth in wet conditions',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Roots discolored brown or gray',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Plant collapses suddenly',
          'weight': 0.9,
          'cluster': 'unique'
        },
      ],
    },
    'Stems/Branches': {
      'Pests': [
        {
          'symptom': 'Small holes bored into stems',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Sawdust-like frass around stem base',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Visible larvae inside stems',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Weakened or snapping branches',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Hollowed-out stem interiors',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'White, waxy insects on stems',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Cotton-like masses on stems',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Ant trails on plant stems',
          'weight': 0.7,
          'cluster': 'unique'
        },
        {
          'symptom': 'Small, flat, oval insects on stems',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Hard, waxy shells on stems',
          'weight': 0.9,
          'cluster': 'unique'
        },
      ],
      'Diseases': [
        {
          'symptom': 'Dark, sunken cankers or lesions on stems',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'White or gray mold covering stems',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Stems splitting or cracking abnormally',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Oozing sap from stems',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Dark streaks at stem base',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Brittle stems near base',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Branch lesions in severe cases',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Dark lesions on stems',
          'weight': 0.8,
          'cluster': 'shared'
        },
        {
          'symptom': 'Rapid wilting in wet weather',
          'weight': 0.8,
          'cluster': 'unique'
        },
      ],
    },
    'Leaves': {
      'Pests': [
        {
          'symptom': 'Irregular holes in leaves',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Silvery tunnels or trails on leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Sticky honeydew with ants present',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Tiny white insects under leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Leaves curling or yellowing',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Skeletonized leaves with veins intact',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Yellowing leaves above bored stems',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Wilting leaves above affected stems',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Leaves with irregular, winding patterns',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Premature leaf drop with miner damage',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Tiny larvae visible inside leaf tissue',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Yellowing leaves with serpentine trails',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'White, waxy insects on leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Ants tending mealybugs',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Cotton-like masses on leaves',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Visible caterpillars on leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Silk threads on leaves',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Fecal pellets on leaves',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Presence of ants tending pests',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Small, flat, oval insects on leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Discolored spots under scales',
          'weight': 0.7,
          'cluster': 'unique'
        },
        {
          'symptom': 'Silvering or bronzing of leaves',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Tiny, slender insects on leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Black fecal spots on leaves',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Cloud of white insects when plant is disturbed',
          'weight': 0.9,
          'cluster': 'unique'
        },
      ],
      'Diseases': [
        {
          'symptom': 'Orange-yellow rust spots on leaf undersides',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Black or brown spots with yellow halos',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Powdery white coating on leaves',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Water-soaked, wilting leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Sooty black mold on leaf surfaces',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Premature leaf drop with no pest signs',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Yellowing leaves with no pest damage',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Plant collapses suddenly',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Spots spreading in humid conditions',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Reduced photosynthesis from leaf damage',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Round brown spots with yellow halos',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Spots on leaves in humid conditions',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {'symptom': 'Reduced leaf vigor', 'weight': 0.6, 'cluster': 'shared'},
        {
          'symptom': 'Leaves dropping early without pest marks',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Spots on leaves in wet seasons',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'No insect activity visible',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Yellowing leaves with root decay',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Wilting with no pest signs',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Sticky honeydew with fungal growth',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Reduced photosynthesis, no direct pest damage',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Mold linked to pest activity',
          'weight': 0.8,
          'cluster': 'unique'
        },
      ],
    },
    'Fruits': {
      'Pests': [
        {
          'symptom': 'Small entry holes in coffee cherries',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Larvae inside cherries, often with frass',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Deformed or discolored cherries',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Premature fruit drop due to sap-sucking',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Tiny insects on fruit surfaces',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Premature fruit drop with tiny holes',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Small beetles in cherries',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Powdery frass in cherry cavities',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Blackened spots on cherries',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Irregular holes in fruits',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Small holes in stored coffee beans',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Damaged or hollowed-out beans',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Presence of weevils in storage',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Powdery debris in storage',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Infested beans with larvae',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Sticky honeydew on fruits',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {'symptom': 'Ant trails on fruits', 'weight': 0.7, 'cluster': 'unique'},
        {
          'symptom': 'Distorted or scarred fruit surfaces',
          'weight': 0.8,
          'cluster': 'shared'
        },
      ],
      'Diseases': [
        {
          'symptom': 'Black, sunken lesions on cherries',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Soft, rotting cherries with fungal growth',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Brown spots or shriveled berries',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'White or gray mold on fruit surfaces',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Fruit cracking with dark lesions',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Foul odor from decaying cherries',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Premature fruit drop with fungal signs',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Rotting cherries with no insect holes',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Spots worsening in wet weather',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Sunken, black spots on cherries',
          'weight': 0.9,
          'cluster': 'unique'
        },
      ],
    },
    'Flowers': {
      'Pests': [
        {
          'symptom': 'Tiny, slender insects on flowers',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Flower buds dropping due to sap-sucking',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {'symptom': 'Chewed flower buds', 'weight': 0.7, 'cluster': 'shared'},
        {
          'symptom': 'Sticky honeydew on flowers',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Presence of ants tending pests',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {'symptom': 'Deformed flower buds', 'weight': 0.7, 'cluster': 'shared'},
      ],
      'Diseases': [
        {
          'symptom': 'Brown or black spots on flower buds',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Wilting or drooping flowers',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'White fungal coating on buds',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Flowers rotting before opening',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Premature flower drop with no pest signs',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Discolored or shriveled buds',
          'weight': 0.8,
          'cluster': 'unique'
        },
      ],
    },
  };

  Map<String, List<bool>> selectedSymptoms = {
    'Roots': [],
    'Stems/Branches': [],
    'Leaves': [],
    'Fruits': [],
    'Flowers': [],
  };

  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<int> _guideTextAnimation;
  final String _guideText =
      'Welcome to the Symptom Checker! Select the symptoms you observe on your coffee plant by checking the boxes below. Choose symptoms from Roots, Stems/Branches, Leaves, Fruits, or Flowers. Once done, press the floating button to analyze whether it’s a pest or disease issue.';
  String _currentGuideText = '';

  @override
  void initState() {
    super.initState();
    symptoms.forEach((section, categories) {
      int totalSymptoms =
          categories['Pests']!.length + categories['Diseases']!.length;
      selectedSymptoms[section] = List.filled(totalSymptoms, false);
    });

    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _guideTextAnimation = StepTween(
      begin: 0,
      end: _guideText.length,
    ).animate(_animationController)
      ..addListener(() {
        setState(() {
          _currentGuideText =
              _guideText.substring(0, _guideTextAnimation.value);
        });
      });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _resetSymptoms() {
    setState(() {
      selectedSymptoms.forEach((section, value) {
        selectedSymptoms[section] = List.filled(value.length, false);
      });
    });
  }

  void _analyzeSymptoms() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    double pestScore = 0.0;
    double diseaseScore = 0.0;
    int totalSelected = 0;
    Map<String, List<Map<String, dynamic>>> symptomDetails = {};

    symptoms.forEach((section, categories) {
      List<Map<String, dynamic>> allSymptoms = [
        ...categories['Pests']!,
        ...categories['Diseases']!
      ];
      symptomDetails[section] = [];
      for (int i = 0; i < allSymptoms.length; i++) {
        if (selectedSymptoms[section]![i]) {
          totalSelected++;
          symptomDetails[section]!.add(allSymptoms[i]);
          double weight = allSymptoms[i]['weight'] as double;
          if (allSymptoms[i]['cluster'] == 'unique') {
            weight *= 1.2; // Boost unique symptoms
          }
          if (i < categories['Pests']!.length) {
            pestScore += weight;
          } else {
            diseaseScore += weight;
          }
        }
      }
    });

    String resultMessage;
    Widget navigationButton;

    if (totalSelected == 0) {
      resultMessage = 'Please select at least one symptom to analyze.';
      navigationButton = const SizedBox.shrink();
    } else {
      double totalScore = pestScore + diseaseScore;
      double pestPercentage =
          totalScore > 0 ? (pestScore / totalScore) * 100 : 0;
      double diseasePercentage =
          totalScore > 0 ? (diseaseScore / totalScore) * 100 : 0;

      StringBuffer details = StringBuffer();
      symptomDetails.forEach((section, symptoms) {
        if (symptoms.isNotEmpty) {
          details.writeln('$section:');
          for (var symptom in symptoms) {
            bool isPest = false;
            bool isDisease = false;
            if (this
                .symptoms[section]!['Pests']!
                .any((s) => s['symptom'] == symptom['symptom'])) {
              isPest = true;
            }
            if (this
                .symptoms[section]!['Diseases']!
                .any((s) => s['symptom'] == symptom['symptom'])) {
              isDisease = true;
            }
            String type = isPest && isDisease
                ? 'Pest & Disease'
                : isPest
                    ? 'Pest'
                    : 'Disease';
            details.writeln(
                '  • ${symptom['symptom']} ($type, Weight: ${symptom['weight']}, Cluster: ${symptom['cluster']})');
          }
        }
      });

      resultMessage = 'Analysis Results:\n'
          'Pest-related symptoms: ${pestPercentage.toStringAsFixed(1)}% (Score: ${pestScore.toStringAsFixed(1)})\n'
          'Disease-related symptoms: ${diseasePercentage.toStringAsFixed(1)}% (Score: ${diseaseScore.toStringAsFixed(1)})\n\n'
          'Selected Symptoms:\n${details.toString()}';

      if (pestScore > diseaseScore + 0.5) {
        resultMessage +=
            '\nThe symptoms lean toward a pest issue. Proceed to pest analysis for details.';
        navigationButton = ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoffeePestSymptomAnalysisPage(
                  selectedSymptoms: _getSelectedSymptoms()),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: coffeeBrown,
            foregroundColor: Colors.white,
          ),
          child: const Text('Analyze Pests Further'),
        );
      } else if (diseaseScore > pestScore + 0.5) {
        resultMessage +=
            '\nThe symptoms lean toward a disease issue. Proceed to disease analysis for details.';
        navigationButton = ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoffeeDiseaseSymptomAnalysisPage(
                  selectedSymptoms: _getSelectedSymptoms()),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: coffeeBrown,
            foregroundColor: Colors.white,
          ),
          child: const Text('Analyze Diseases Further'),
        );
      } else {
        resultMessage +=
            '\nThe symptoms are inconclusive due to overlap. Explore both pest and disease analysis.';
        navigationButton = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CoffeePestSymptomAnalysisPage(
                        selectedSymptoms: _getSelectedSymptoms())),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: coffeeBrown,
                foregroundColor: Colors.white,
              ),
              child: const Text('Pests'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CoffeeDiseaseSymptomAnalysisPage(
                        selectedSymptoms: _getSelectedSymptoms())),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: coffeeBrown,
                foregroundColor: Colors.white,
              ),
              child: const Text('Diseases'),
            ),
          ],
        );
      }
    }

    setState(() => _isLoading = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Symptom Analysis',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Analysis Results',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown)),
                const SizedBox(height: 8),
                Text(
                  resultMessage.split('\nSelected Symptoms:')[0],
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Text('Selected Symptoms',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown)),
                const SizedBox(height: 8),
                Text(
                  resultMessage.split('\nSelected Symptoms:')[1],
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            navigationButton,
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.brown)),
            ),
          ],
        ),
      );
    }
  }

  Map<String, List<Map<String, dynamic>>> _getSelectedSymptoms() {
    Map<String, List<Map<String, dynamic>>> selected = {};
    symptoms.forEach((section, categories) {
      List<Map<String, dynamic>> allSymptoms = [
        ...categories['Pests']!,
        ...categories['Diseases']!
      ];
      selected[section] = allSymptoms
          .asMap()
          .entries
          .where((entry) => selectedSymptoms[section]![entry.key])
          .map((entry) => entry.value)
          .toList();
    });
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Symptom Checker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: coffeeBrown,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Container(
            color: backgroundColor,
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        _currentGuideText,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _resetSymptoms,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: coffeeBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reset Symptoms'),
                  ),
                  const SizedBox(height: 16),
                  _buildSection('Roots'),
                  const SizedBox(height: 16),
                  _buildSection('Stems/Branches'),
                  const SizedBox(height: 16),
                  _buildSection('Leaves'),
                  const SizedBox(height: 16),
                  _buildSection('Fruits'),
                  const SizedBox(height: 16),
                  _buildSection('Flowers'),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(coffeeBrown)),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _analyzeSymptoms,
        backgroundColor: coffeeBrown,
        tooltip: 'Analyze Symptoms',
        child: const Icon(Icons.search, color: Colors.white),
      ),
    );
  }

  Widget _buildSection(String section) {
    final pestSymptoms = symptoms[section]!['Pests']!;
    final diseaseSymptoms = symptoms[section]!['Diseases']!;
    final allSymptoms = [...pestSymptoms, ...diseaseSymptoms];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: coffeeBrown),
            ),
            const SizedBox(height: 8),
            ...List.generate(allSymptoms.length, (index) {
              return CheckboxListTile(
                title: Text(allSymptoms[index]['symptom'],
                    style: const TextStyle(fontSize: 14)),
                value: selectedSymptoms[section]![index],
                onChanged: (bool? value) {
                  setState(() {
                    selectedSymptoms[section]![index] = value!;
                  });
                },
                activeColor: coffeeBrown,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            }),
          ],
        ),
      ),
    );
  }
}
