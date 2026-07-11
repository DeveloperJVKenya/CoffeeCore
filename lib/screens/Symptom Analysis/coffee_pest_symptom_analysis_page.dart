import 'package:coffeecore/screens/Pest%20Management/coffee_pest_management_page.dart';
import 'package:flutter/material.dart';

class CoffeePestSymptomAnalysisPage extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> selectedSymptoms;

  const CoffeePestSymptomAnalysisPage(
      {required this.selectedSymptoms, super.key});

  @override
  State<CoffeePestSymptomAnalysisPage> createState() =>
      _CoffeePestSymptomAnalysisPageState();
}

class _CoffeePestSymptomAnalysisPageState
    extends State<CoffeePestSymptomAnalysisPage> {
  static final Color coffeeBrown = Colors.brown[700]!;
  static final Color backgroundColor = Colors.brown[50]!;
  bool _isLoading = false;
  Map<String, List<bool>> additionalSymptoms = {};
  Map<String, List<Map<String, dynamic>>> filteredPestSymptoms = {};
  Map<String, List<String>> allSelectedSymptoms = {};
  List<String> matchingPests = [];
  int analysisIterations = 0;
  static const int maxIterations = 3;

  final Map<String, Map<String, List<Map<String, dynamic>>>> pestSymptoms = {
    'Coffee Berry Borer': {
      'Fruits': [
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
      ],
    },
    'Coffee Leaf Miner': {
      'Leaves': [
        {
          'symptom': 'Silvery tunnels or trails on leaves',
          'weight': 1.0,
          'cluster': 'unique'
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
      ],
    },
    'Coffee Antestia Bug': {
      'Fruits': [
        {
          'symptom': 'Deformed or discolored cherries',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Tiny insects on fruit surfaces',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {
          'symptom': 'Premature fruit drop due to sap-sucking',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Blackened spots on cherries',
          'weight': 0.6,
          'cluster': 'shared'
        },
      ],
      'Leaves': [
        {
          'symptom': 'Sticky honeydew on leaves',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Ants attracted to leaves',
          'weight': 0.6,
          'cluster': 'shared'
        },
      ],
    },
    'Coffee Stem Borer': {
      'Stems/Branches': [
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
      ],
      'Leaves': [
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
      ],
    },
    'Root-Knot Nematodes': {
      'Roots': [
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
      ],
    },
    'White Flies': {
      'Leaves': [
        {
          'symptom': 'Tiny white insects under leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Sticky honeydew with ants present',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Leaves curling or yellowing',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Sooty mold on leaf surfaces',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Cloud of white insects when plant is disturbed',
          'weight': 0.9,
          'cluster': 'unique'
        },
        {'symptom': 'Premature leaf drop', 'weight': 0.6, 'cluster': 'shared'},
      ],
    },
    'Coffee Mealybug': {
      'Leaves': [
        {
          'symptom': 'White, waxy insects on leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Sticky honeydew and sooty mold',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Leaves curling or wilting',
          'weight': 0.6,
          'cluster': 'shared'
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
      ],
      'Stems/Branches': [
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
      ],
    },
    'Caterpillars': {
      'Leaves': [
        {
          'symptom': 'Irregular holes in leaves',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Skeletonized leaves with veins intact',
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
      ],
      'Fruits': [
        {
          'symptom': 'Irregular holes in fruits',
          'weight': 0.7,
          'cluster': 'shared'
        },
      ],
      'Flowers': [
        {'symptom': 'Chewed flower buds', 'weight': 0.7, 'cluster': 'shared'},
      ],
    },
    'Coffee Weevil': {
      'Fruits': [
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
      ],
    },
    'Ants': {
      'Leaves': [
        {
          'symptom': 'Presence of ants tending pests',
          'weight': 0.8,
          'cluster': 'unique'
        },
        {
          'symptom': 'Sticky honeydew on leaves',
          'weight': 0.6,
          'cluster': 'shared'
        },
      ],
      'Fruits': [
        {
          'symptom': 'Sticky honeydew on fruits',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {'symptom': 'Ant trails on fruits', 'weight': 0.7, 'cluster': 'unique'},
      ],
      'Stems/Branches': [
        {
          'symptom': 'Ant trails on plant stems',
          'weight': 0.7,
          'cluster': 'unique'
        },
      ],
    },
    'Scale Insects': {
      'Leaves': [
        {
          'symptom': 'Small, flat, oval insects on leaves',
          'weight': 1.0,
          'cluster': 'unique'
        },
        {
          'symptom': 'Sticky honeydew on leaves',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Yellowing or wilting leaves',
          'weight': 0.6,
          'cluster': 'shared'
        },
        {
          'symptom': 'Sooty mold from sap-sucking',
          'weight': 0.7,
          'cluster': 'shared'
        },
        {
          'symptom': 'Discolored spots under scales',
          'weight': 0.7,
          'cluster': 'unique'
        },
      ],
      'Stems/Branches': [
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
    },
    'Thrips': {
      'Leaves': [
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
        {'symptom': 'Premature leaf drop', 'weight': 0.6, 'cluster': 'shared'},
      ],
      'Fruits': [
        {
          'symptom': 'Distorted or scarred fruit surfaces',
          'weight': 0.8,
          'cluster': 'shared'
        },
      ],
      'Flowers': [
        {'symptom': 'Deformed flower buds', 'weight': 0.7, 'cluster': 'shared'},
        {
          'symptom': 'Tiny, slender insects on flowers',
          'weight': 1.0,
          'cluster': 'unique'
        },
      ],
    },
  };

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

  @override
  void initState() {
    super.initState();
    allSelectedSymptoms = _convertToSymptomStrings(widget.selectedSymptoms);
    _initializeAdditionalSymptoms();
  }

  Map<String, List<String>> _convertToSymptomStrings(
      Map<String, List<Map<String, dynamic>>> input) {
    Map<String, List<String>> result = {};
    input.forEach((section, symptoms) {
      result[section] = symptoms.map((s) => s['symptom'] as String).toList();
    });
    return result;
  }

  void _initializeAdditionalSymptoms() {
    matchingPests = [];
    for (var pest in pestSymptoms.keys) {
      bool hasMatch = false;
      for (var section in allSelectedSymptoms.keys) {
        if (pestSymptoms[pest]!.containsKey(section)) {
          for (var symptom in allSelectedSymptoms[section]!) {
            if (pestSymptoms[pest]![section]!
                .any((s) => s['symptom'] == symptom)) {
              hasMatch = true;
              break;
            }
          }
        }
        if (hasMatch) break;
      }
      if (hasMatch) {
        matchingPests.add(pest);
      }
    }

    filteredPestSymptoms = {};
    for (var pest in matchingPests) {
      for (var section in pestSymptoms[pest]!.keys) {
        if (!filteredPestSymptoms.containsKey(section)) {
          filteredPestSymptoms[section] = [];
        }
        var additional = pestSymptoms[pest]![section]!
            .where((s) => !allSelectedSymptoms[section]!.contains(s['symptom']))
            .toList();
        filteredPestSymptoms[section]!.addAll(additional);
      }
    }

    for (var section in filteredPestSymptoms.keys.toList()) {
      filteredPestSymptoms[section] =
          filteredPestSymptoms[section]!.toSet().toList();
      if (filteredPestSymptoms[section]!.isEmpty) {
        filteredPestSymptoms.remove(section);
      }
    }

    for (var section in filteredPestSymptoms.keys) {
      additionalSymptoms[section] =
          List.filled(filteredPestSymptoms[section]!.length, false);
    }
  }

  void _resetSymptoms() {
    setState(() {
      for (var section in additionalSymptoms.keys) {
        additionalSymptoms[section] =
            List.filled(additionalSymptoms[section]!.length, false);
      }
      analysisIterations = 0;
    });
  }

  void _analyzePests() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    // Check if any additional symptoms are selected
    bool hasNewSymptoms = false;
    for (var section in additionalSymptoms.keys) {
      if (additionalSymptoms[section]!.any((selected) => selected)) {
        hasNewSymptoms = true;
        break;
      }
    }

    if (!hasNewSymptoms && analysisIterations > 0) {
      setState(() => _isLoading = false);
      StringBuffer resultMessage = StringBuffer();
      resultMessage.writeln(
          'No new symptoms selected. Please select additional symptoms and press the search icon to continue analysis.');
      resultMessage.writeln('\nCurrent matching pests:');
      for (var pest in matchingPests) {
        resultMessage.writeln('  • **$pest**');
      }
      _showResult(
        resultMessage.toString(),
        [
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CoffeePestManagementPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: coffeeBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Explore Pest Management'),
          ),
        ],
        null,
        null,
      );
      return;
    }

    // Update allSelectedSymptoms with new selections
    allSelectedSymptoms = _convertToSymptomStrings(widget.selectedSymptoms);
    for (var section in filteredPestSymptoms.keys) {
      if (!allSelectedSymptoms.containsKey(section)) {
        allSelectedSymptoms[section] = [];
      }
      for (int i = 0; i < filteredPestSymptoms[section]!.length; i++) {
        if (additionalSymptoms[section]![i]) {
          allSelectedSymptoms[section]!
              .add(filteredPestSymptoms[section]![i]['symptom']);
        }
      }
    }

    // Increment iteration count
    analysisIterations++;
    if (analysisIterations > maxIterations) {
      StringBuffer resultMessage = StringBuffer();
      resultMessage.writeln(
          'Unable to narrow down to a single pest after $maxIterations attempts.');
      resultMessage.writeln('Multiple pests match the symptoms:');
      for (var pest in matchingPests) {
        resultMessage.writeln('  • **$pest**');
      }
      resultMessage.writeln('\nExplore pest management for these pests.');
      setState(() => _isLoading = false);
      _showResult(
        resultMessage.toString(),
        [
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CoffeePestManagementPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: coffeeBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Explore Pest Management'),
          ),
        ],
        null,
        null,
      );
      return;
    }

    // Calculate pest scores with emphasis on unique symptoms
    Map<String, Map<String, dynamic>> pestMatches = {};
    for (var pest in pestSymptoms.keys) {
      double score = 0.0;
      List<String> matchedSymptoms = [];
      for (var section in pestSymptoms[pest]!.keys) {
        for (var symptom in allSelectedSymptoms[section] ?? []) {
          var matchingSymptom = pestSymptoms[pest]![section]!.firstWhere(
            (s) => s['symptom'] == symptom,
            orElse: () => {'symptom': '', 'weight': 0.0, 'cluster': ''},
          );
          if (matchingSymptom['symptom'].isNotEmpty) {
            double weight = matchingSymptom['weight'] as double;
            if (matchingSymptom['cluster'] == 'unique') {
              weight *= 1.5;
            }
            score += weight;
            matchedSymptoms.add(
                '${matchingSymptom['symptom']} (${matchingSymptom['cluster']}, Weight: ${matchingSymptom['weight']})');
          }
        }
      }
      if (score > 0) {
        double maxScore = pestSymptoms[pest]!.values.fold(
            0.0,
            (sum, symptoms) =>
                sum +
                symptoms.fold(
                    0.0,
                    (s, sym) =>
                        s +
                        (sym['cluster'] == 'unique'
                            ? sym['weight'] * 1.5
                            : sym['weight'])));
        pestMatches[pest] = {
          'score': score,
          'matchedSymptoms': matchedSymptoms,
          'confidence': (score / maxScore) * 100,
        };
      }
    }

    if (pestMatches.isEmpty) {
      _showResult(
          'No specific pest identified. Explore pest management options.',
          [],
          null,
          null);
      setState(() => _isLoading = false);
      return;
    }

    var sortedPests = pestMatches.entries.toList()
      ..sort((a, b) => b.value['score'].compareTo(a.value['score']));
    var topPests = sortedPests.take(3).toList();

    matchingPests = topPests.map((e) => e.key).toList();

    bool isConclusive = topPests.length == 1 ||
        (topPests.length > 1 &&
            topPests[0].value['score'] > topPests[1].value['score'] * 1.5);

    if (isConclusive) {
      StringBuffer resultMessage = StringBuffer();
      List<Widget> navigationButtons = [];
      var pestEntry = topPests[0];
      String pest = pestEntry.key;
      double score = pestEntry.value['score'];
      double confidence = pestEntry.value['confidence'];
      List<String> matchedSymptoms = pestEntry.value['matchedSymptoms'];
      resultMessage.writeln('Top Matching Pest:');
      resultMessage.writeln(
          '**$pest** (Score: ${score.toStringAsFixed(1)}, Confidence: ${confidence.toStringAsFixed(1)}%)');
      resultMessage.writeln('Matching Symptoms:');
      for (var symptom in matchedSymptoms) {
        resultMessage.writeln('  • $symptom');
      }
      String? coffeeStage;
      for (var stage in _stagePests.keys) {
        if (_stagePests[stage]!.contains(pest)) {
          coffeeStage = stage;
          break;
        }
      }
      navigationButtons.add(
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoffeePestManagementPage(
                pestName: pest,
                coffeeStage: coffeeStage,
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: coffeeBrown,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Manage $pest'),
        ),
      );
      analysisIterations = 0;
      _showResult(
          resultMessage.toString(), navigationButtons, pest, coffeeStage);
    } else {
      filteredPestSymptoms = {};
      for (var pest in matchingPests) {
        for (var section in pestSymptoms[pest]!.keys) {
          if (!filteredPestSymptoms.containsKey(section)) {
            filteredPestSymptoms[section] = [];
          }
          var additional = pestSymptoms[pest]![section]!
              .where(
                  (s) => !allSelectedSymptoms[section]!.contains(s['symptom']))
              .toList();
          filteredPestSymptoms[section]!.addAll(additional);
        }
      }
      for (var section in filteredPestSymptoms.keys.toList()) {
        filteredPestSymptoms[section] =
            filteredPestSymptoms[section]!.toSet().toList();
        if (filteredPestSymptoms[section]!.isEmpty) {
          filteredPestSymptoms.remove(section);
        }
      }
      for (var section in filteredPestSymptoms.keys) {
        additionalSymptoms[section] =
            List.filled(filteredPestSymptoms[section]!.length, false);
      }

      StringBuffer resultMessage = StringBuffer();
      List<Widget> navigationButtons = [];
      resultMessage.writeln('Multiple pests match the symptoms:');
      for (var pestEntry in topPests) {
        String pest = pestEntry.key;
        double score = pestEntry.value['score'];
        double confidence = pestEntry.value['confidence'];
        List<String> matchedSymptoms = pestEntry.value['matchedSymptoms'];
        resultMessage.writeln(
            '**$pest** (Score: ${score.toStringAsFixed(1)}, Confidence: ${confidence.toStringAsFixed(1)}%)');
        resultMessage.writeln('Matching Symptoms:');
        for (var symptom in matchedSymptoms) {
          resultMessage.writeln('  • $symptom');
        }
        resultMessage.writeln();
      }
      if (filteredPestSymptoms.isEmpty) {
        resultMessage.writeln(
            'No additional symptoms available to narrow down the pest.');
        resultMessage.writeln(
            'Explore pest management for the identified pests or select different symptoms.');
        navigationButtons.add(
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CoffeePestManagementPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: coffeeBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Explore Pest Management'),
          ),
        );
        analysisIterations = 0;
      } else {
        resultMessage.writeln(
            'Select additional symptoms below and press the search icon to continue analysis.');
        navigationButtons.add(
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: coffeeBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Select More Symptoms'),
          ),
        );
      }
      _showResult(resultMessage.toString(), navigationButtons, null, null);
    }

    setState(() => _isLoading = false);
  }

  void _showResult(String message, List<Widget> navigationButtons,
      String? topPest, String? coffeeStage) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pest Analysis Result',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analysis Results',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: coffeeBrown)),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                    children: _parseMessageToSpans(message),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ...navigationButtons,
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: coffeeBrown)),
            ),
          ],
        ),
      );
    }
  }

  List<TextSpan> _parseMessageToSpans(String message) {
    List<TextSpan> spans = [];
    final lines = message.split('\n');
    for (var line in lines) {
      if (line.contains('**')) {
        final parts = line.split('**');
        for (int i = 0; i < parts.length; i++) {
          if (i % 2 == 0) {
            spans.add(TextSpan(text: parts[i]));
          } else {
            spans.add(TextSpan(
              text: parts[i],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ));
          }
        }
        spans.add(const TextSpan(text: '\n'));
      } else {
        spans.add(TextSpan(text: '$line\n'));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pest Symptom Analysis',
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
                  Text(
                    'Closely Matching Pests',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: coffeeBrown),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: matchingPests.isEmpty
                            ? [
                                const Text(
                                  'No pests identified yet. Select symptoms to analyze.',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ]
                            : matchingPests
                                .map((pest) => Text('• **$pest**',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)))
                                .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Additional Symptoms for Deeper Analysis',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: coffeeBrown),
                  ),
                  const SizedBox(height: 8),
                  if (filteredPestSymptoms.isEmpty)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text(
                          'No additional symptoms available. Try exploring pest management or selecting different symptoms.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...filteredPestSymptoms.entries.map((entry) {
                      String section = entry.key;
                      List<Map<String, dynamic>> symptoms = entry.value;
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: coffeeBrown),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(symptoms.length, (index) {
                                return CheckboxListTile(
                                  title: Text(symptoms[index]['symptom'],
                                      style: const TextStyle(fontSize: 14)),
                                  value: additionalSymptoms[section]![index],
                                  onChanged: (bool? value) {
                                    setState(() {
                                      additionalSymptoms[section]![index] =
                                          value!;
                                    });
                                  },
                                  activeColor: coffeeBrown,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  dense: true,
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _resetSymptoms,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: coffeeBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reset Additional Symptoms'),
                  ),
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
        onPressed: _isLoading ? null : _analyzePests,
        backgroundColor: coffeeBrown,
        tooltip: 'Analyze Pests',
        child: const Icon(Icons.search, color: Colors.white),
      ),
    );
  }
}
