import 'dart:developer' as developer;
import 'package:coffeecore/models/coffee_soil_data.dart';
import 'package:coffeecore/screens/Field%20Data/gemini_soil_ai_service.dart';
import 'package:coffeecore/screens/Field%20Data/helpers/nutrient_analysis_helper.dart';
import 'package:coffeecore/screens/Field%20Data/coffee_soil_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timezone/timezone.dart' as tz;

class CoffeeSoilForm extends StatefulWidget {
  final String userId;
  final String plotId;
  final FlutterLocalNotificationsPlugin notificationsPlugin;
  final Function(String, String) onSave;
  final VoidCallback? onInputInteraction;

  /// ⑥ Called whenever nutrient values, stage, or soil type change so the
  /// parent can pass context to the Soil Advisor chat FAB.
  final void Function(
    Map<String, double> nutrients,
    String stage,
    String? soilType,
  )? onNutrientsChanged;

  const CoffeeSoilForm({
    required this.userId,
    required this.plotId,
    required this.notificationsPlugin,
    required this.onSave,
    this.onInputInteraction,
    this.onNutrientsChanged,
    super.key,
  });

  @override
  State<CoffeeSoilForm> createState() => _CoffeeSoilFormState();
}

class _CoffeeSoilFormState extends State<CoffeeSoilForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _nutrientStatus = {};
  final Map<String, Map<String, String>> _allRecommendations = {};
  final Map<String, bool> _expandedRecommendations = {};

  String? _selectedSoilType;
  String _selectedStage = 'Establishment/Seedling';
  int _plantDensity = 1000;
  bool _isPerPlant = false;
  bool _saveWithRecommendations = false;

  String? _interventionMethod;
  String? _interventionQuantity;
  String? _interventionUnit;
  DateTime? _interventionFollowUpDate;

  // ── ① Soil scanner state ─────────────────────────────────────────────────
  bool _isScanningImage = false;

  // ── ② AI Analysis state ──────────────────────────────────────────────────
  SoilAnalysisResult? _aiAnalysisResult;
  bool _isRunningAiAnalysis = false;

  // ── ③ Fertilization plan state ───────────────────────────────────────────
  bool _isGeneratingPlan = false;

  static const List<String> _nutrients = [
    'pH', 'nitrogen', 'phosphorus', 'potassium',
    'magnesium', 'calcium', 'zinc', 'boron'
  ];

  static const List<String> _stages = [
    'Establishment/Seedling',
    'Vegetative Growth',
    'Flowering and Fruiting',
    'Maturation and Harvesting'
  ];

  static const Map<String, String> _soilTypes = {
    'Volcanic':
        'Dark, crumbly soil, light and mineral-rich, often black or brown.',
    'Red': 'Reddish, sticky clay soil, smooth and heavy when wet.',
    'Alluvial':
        'Soft, silty soil near rivers, light brown, easy to dig.',
    'Forest':
        'Dark, spongy soil with leaves, soft and moist under trees.',
    'Laterite':
        'Hard, reddish-brown soil, firm and gravelly in tropical areas.',
  };

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    for (final nutrient in _nutrients) {
      _controllers[nutrient] = TextEditingController();
      _controllers[nutrient]!.addListener(_updateAnalysis);
    }
  }

  // ── Nutrient values getter ────────────────────────────────────────────────

  Map<String, double> get _currentNutrientValues {
    final map = <String, double>{};
    for (final nutrient in _nutrients) {
      final v = double.tryParse(_controllers[nutrient]?.text ?? '');
      if (v != null) map[nutrient] = v;
    }
    return map;
  }

  // ── Static analysis (fires on every keystroke) ────────────────────────────

  void _updateAnalysis() {
    try {
      setState(() {
        _nutrientStatus.clear();
        _allRecommendations.clear();

        for (final nutrient in _nutrients) {
          final text = _controllers[nutrient]!.text;
          if (text.isNotEmpty) {
            final value = double.tryParse(text);
            if (value != null) {
              final status = NutrientAnalysisHelper.getNutrientStatus(
                  nutrient, value, _selectedStage);
              _nutrientStatus[nutrient] = status;
              if (status != 'Optimal') {
                _allRecommendations[nutrient] =
                    NutrientAnalysisHelper.getRecommendations(
                  nutrient,
                  status,
                  _selectedStage,
                  _selectedSoilType,
                  _isPerPlant,
                  _plantDensity,
                );
              }
            }
          }
        }
      });

      // ⑥ Notify parent of changed context.
      widget.onNutrientsChanged?.call(
        _currentNutrientValues,
        _selectedStage,
        _selectedSoilType,
      );

      // Clear stale AI result when inputs change.
      if (_aiAnalysisResult != null) {
        setState(() => _aiAnalysisResult = null);
      }
    } catch (e, st) {
      developer.log('Error updating analysis: $e',
          name: 'CoffeeSoilForm', error: e, stackTrace: st);
    }
  }

  // ── ① Soil Vision Scanner ─────────────────────────────────────────────────

  Future<void> _scanSoilImage() async {
    widget.onInputInteraction?.call();

    // Let user pick source.
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Soil Image Source',
            style: TextStyle(color: Color(0xFF4A2C2A))),
        content: const Text(
          'Take a photo of your bare soil or choose one from your gallery.',
          style: TextStyle(color: Color(0xFF3A5F0B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text('Gallery',
                style: TextStyle(color: Color(0xFF4A2C2A))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A2C2A)),
            child: const Text('Camera',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    setState(() => _isScanningImage = true);

    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? 'image/jpeg';

    final result = await GeminiSoilAiService.identifySoilType(
      imageBytes: bytes,
      mimeType: mimeType,
    );

    if (!mounted) return;
    setState(() => _isScanningImage = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not analyse the image. Please try again.'),
          backgroundColor: Color(0xFF4A2C2A),
        ),
      );
      return;
    }

    if (result.confident && result.identifiedSoilType != null) {
      // Normalise the returned soil type against the known dropdown keys.
      // Gemini may return e.g. "alluvial", "ALLUVIAL", or "Alluvial soil" —
      // all should resolve to the canonical "Alluvial" key.
      final rawType = result.identifiedSoilType!.trim();
      final normalised = _soilTypes.keys.firstWhere(
        (k) => k.toLowerCase() == rawType.toLowerCase() ||
            rawType.toLowerCase().startsWith(k.toLowerCase()),
        orElse: () => rawType,
      );
      final isValidType = _soilTypes.containsKey(normalised);

      if (isValidType) {
        // Auto-fill dropdown.
        setState(() => _selectedSoilType = normalised);
        _updateAnalysis();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF3A5F0B),
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Soil identified as $normalised '
                      '(${result.confidencePercent?.toStringAsFixed(0)}% confidence)',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        // Gemini returned a type not in our list — fall through to candidates dialog.
        developer.log(
          'Gemini returned unrecognised soil type "$rawType" — '
          'falling through to candidate selection dialog.',
          name: 'CoffeeSoilForm',
        );
        if (!mounted) return;
        String? chosen = await _showSoilCandidatesDialog(result);
        if (chosen != null && mounted) {
          setState(() => _selectedSoilType = chosen);
          _updateAnalysis();
        }
      }
    } else {
      // Inconclusive — show candidates.
      if (!mounted) return;
      String? chosen = await _showSoilCandidatesDialog(result);
      if (chosen != null && mounted) {
        setState(() => _selectedSoilType = chosen);
        _updateAnalysis();
      }
    }
  }

  Future<String?> _showSoilCandidatesDialog(SoilTypeResult result) async {
    String? selected =
        result.candidates.isNotEmpty ? result.candidates.first : null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Soil Type — Please Confirm',
            style: TextStyle(
                color: Color(0xFF4A2C2A), fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.reasoning != null) ...[
                Text(
                  result.reasoning!,
                  style: const TextStyle(
                      color: Color(0xFF3A5F0B), fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Most likely candidates:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A2C2A)),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) =>
                    setDialogState(() => selected = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: result.candidates.map(
                    (c) => RadioListTile<String>(
                      dense: true,
                      title: Text(c,
                          style: const TextStyle(
                              color: Color(0xFF4A2C2A))),
                      value: c,
                      activeColor: const Color(0xFF3A5F0B),
                    ),
                  ).toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip',
                  style: TextStyle(color: Color(0xFF4A2C2A))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A2C2A)),
              child: const Text('Confirm',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── ② AI Holistic Analysis ────────────────────────────────────────────────

  Future<void> _runAiAnalysis() async {
    final nutrients = _currentNutrientValues;
    if (nutrients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least one nutrient value first.'),
          backgroundColor: Color(0xFF4A2C2A),
        ),
      );
      return;
    }

    setState(() => _isRunningAiAnalysis = true);

    final result = await GeminiSoilAiService.generateSoilAnalysis(
      nutrientValues: nutrients,
      stage: _selectedStage,
      soilType: _selectedSoilType,
      plantDensity: _plantDensity,
      isPerPlant: _isPerPlant,
    );

    if (!mounted) return;
    setState(() {
      _isRunningAiAnalysis = false;
      _aiAnalysisResult = result;
      if (result != null) {
        // Overlay AI status on the existing map.
        for (final entry in result.nutrientStatus.entries) {
          _nutrientStatus[entry.key] = entry.value;
        }
        // Overlay AI recommendations.
        final aiRecs = result.toAllRecommendations();
        _allRecommendations.addAll(aiRecs);
      }
    });

    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'AI analysis unavailable. Using standard recommendations.'),
          backgroundColor: Color(0xFF4A2C2A),
        ),
      );
    }
  }

  // ── ③④ Save with fertilization plan + prediction ─────────────────────────

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final newPlotId = await _promptPlotId(context);
    if (newPlotId == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();
      final existingPlots = (querySnapshot.data()?['plots']?['plotIds']
              as List<dynamic>?)
          ?.cast<String>() ??
          [];

      if (existingPlots.contains(newPlotId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Plot ID already exists. Please choose a unique ID.'),
              backgroundColor: Color(0xFF4A2C2A),
            ),
          );
        }
        return;
      }

      final soilData = CoffeeSoilData(
        userId: widget.userId,
        plotId: newPlotId,
        stage: _selectedStage,
        soilType: _selectedSoilType,
        ph: _val('pH'),
        nitrogen: _val('nitrogen'),
        phosphorus: _val('phosphorus'),
        potassium: _val('potassium'),
        magnesium: _val('magnesium'),
        calcium: _val('calcium'),
        zinc: _val('zinc'),
        boron: _val('boron'),
        plantDensity: _plantDensity,
        interventionMethod: _interventionMethod,
        interventionQuantity: _interventionQuantity,
        interventionUnit: _interventionUnit,
        interventionFollowUpDate: _interventionFollowUpDate != null
            ? Timestamp.fromDate(_interventionFollowUpDate!)
            : null,
        recommendations:
            _saveWithRecommendations ? _allRecommendations : null,
        saveWithRecommendations: _saveWithRecommendations,
        timestamp: Timestamp.now(),
        isDeleted: false,
      );

      final docId =
          '${widget.userId}_${soilData.timestamp.millisecondsSinceEpoch}';
      await FirebaseFirestore.instance
          .collection('SoilData')
          .doc(docId)
          .set(soilData.toMap());

      developer.log('Saved soil data: $docId', name: 'CoffeeSoilForm');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_saveWithRecommendations
                ? 'Soil data saved with recommendations'
                : 'Soil data saved'),
            backgroundColor: const Color(0xFF4A2C2A),
          ),
        );
      }

      widget.onSave(widget.plotId, newPlotId);

      // ③ Generate fertilization plan in background.
      if (_nutrientStatus.isNotEmpty && mounted) {
        setState(() => _isGeneratingPlan = true);

        final statusForPlan = <String, String>{};
        for (final e in _nutrientStatus.entries) {
          statusForPlan[e.key] = e.value;
        }

        final plan = await GeminiSoilAiService.generateFertilizationPlan(
          nutrientValues: _currentNutrientValues,
          nutrientStatus: statusForPlan,
          stage: _selectedStage,
          soilType: _selectedSoilType,
          plantDensity: _plantDensity,
          isPerPlant: _isPerPlant,
        );

        if (!mounted) return;
        setState(() => _isGeneratingPlan = false);

        if (plan != null) {
          // Auto-populate intervention from week-1 if none set yet.
          if (plan.weeks.isNotEmpty && _interventionMethod == null) {
            final w1 = plan.weeks.first;
            setState(() {
              _interventionMethod = '${w1.action} — ${w1.product}';
              _interventionQuantity =
                  w1.quantityKgPerAcre.toStringAsFixed(1);
              _interventionUnit = 'kg/acre';
              _interventionFollowUpDate = DateTime.now()
                  .add(Duration(days: plan.followUpDays));
            });

            // Persist the AI-populated intervention + plan to Firestore.
            await FirebaseFirestore.instance
                .collection('SoilData')
                .doc(docId)
                .update({
              'interventionMethod': _interventionMethod,
              'interventionQuantity': _interventionQuantity,
              'interventionUnit': _interventionUnit,
              'interventionFollowUpDate': Timestamp.fromDate(
                  _interventionFollowUpDate!),
              'fertilizationPlan': plan.weeks
                  .map((w) => {
                        'week': w.week,
                        'action': w.action,
                        'product': w.product,
                        'quantityKgPerAcre': w.quantityKgPerAcre,
                        'timing': w.timing,
                        'notes': w.notes,
                      })
                  .toList(),
              'fertilizationPlanSummary': plan.summary,
            });

            // Schedule reminder for the AI-suggested follow-up date.
            await _scheduleReminder(
              _interventionFollowUpDate!,
              'Check soil after: $_interventionMethod',
            );
          }

          // Show plan dialog.
          if (mounted) await _showFertilizationPlanDialog(plan);
        }
      }

      // ④ Predict intervention outcome.
      if (_interventionMethod != null && mounted) {
        final qty = double.tryParse(_interventionQuantity ?? '0') ?? 0;
        final prediction =
            await GeminiSoilAiService.predictInterventionOutcome(
          currentValues: _currentNutrientValues,
          interventionProduct: _interventionMethod!,
          interventionQuantityKgPerAcre: qty,
          stage: _selectedStage,
          soilType: _selectedSoilType,
        );

        if (prediction != null) {
          final predsMap = prediction.predictions.map((k, v) =>
              MapEntry(k, {
                'current': v.current,
                'expectedLow': v.expectedLow,
                'expectedHigh': v.expectedHigh,
                'confidence': v.confidence,
              }));
          await FirebaseFirestore.instance
              .collection('SoilData')
              .doc(docId)
              .update({
            'aiPrediction': {
              'summary': prediction.summary,
              'caveats': prediction.caveats,
              'predictions': predsMap,
            },
          });
          developer.log(
              'Saved AI prediction for $docId', name: 'CoffeeSoilForm');
        }
      }

      _resetForm();
    } catch (e, st) {
      developer.log('Error saving soil data: $e',
          name: 'CoffeeSoilForm', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Unable to save soil data. Please check your connection.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
    }
  }

  // ── Fertilization plan dialog ─────────────────────────────────────────────

  Future<void> _showFertilizationPlanDialog(FertilizationPlan plan) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF5E8C7),
        title: Row(
          children: [
            const Icon(Icons.calendar_month, color: Color(0xFF3A5F0B)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'AI Fertilization Schedule',
                style: TextStyle(
                    color: Color(0xFF4A2C2A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A5F0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan.summary,
                    style: const TextStyle(
                        color: Color(0xFF4A2C2A),
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 16),
                // Week-by-week
                ...plan.weeks.map((w) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF3A5F0B)
                                .withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A5F0B),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Week ${w.week}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  w.action,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A2C2A),
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _planRow('Product', w.product),
                          _planRow('Quantity',
                              '${w.quantityKgPerAcre.toStringAsFixed(1)} kg/acre'),
                          _planRow('Timing', w.timing),
                          if (w.notes.isNotEmpty)
                            _planRow('Note', w.notes),
                        ],
                      ),
                    )),
                const SizedBox(height: 4),
                Text(
                  'Retest in ${plan.followUpDays} days',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it',
                style: TextStyle(color: Color(0xFF4A2C2A))),
          ),
        ],
      ),
    );
  }

  Widget _planRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                '$label:',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4A2C2A)),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF3A5F0B)),
              ),
            ),
          ],
        ),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  double? _val(String nutrient) {
    final t = _controllers[nutrient]!.text;
    return t.isNotEmpty ? double.tryParse(t) : null;
  }

  void _showSoilTypeHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soil Type Descriptions',
            style: TextStyle(
                color: Color(0xFF4A2C2A), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _soilTypes.entries
                .map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A2C2A))),
                          const SizedBox(height: 4),
                          Text(entry.value,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF3A5F0B))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFF4A2C2A))),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientField(String nutrient) {
    final controller = _controllers[nutrient]!;
    final unit =
        NutrientAnalysisHelper.getNutrientUnit(nutrient, _isPerPlant);
    final status = _nutrientStatus[nutrient];
    final recommendations = _allRecommendations[nutrient];
    final isExpanded =
        _expandedRecommendations[nutrient] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText:
                    '${nutrient.toUpperCase()} ${unit.isNotEmpty ? "($unit)" : ""}',
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Color(0xFF3A5F0B))),
                labelStyle:
                    const TextStyle(color: Color(0xFF3A5F0B)),
                suffixIcon: nutrient != 'pH'
                    ? IconButton(
                        icon: Icon(
                          _isPerPlant
                              ? Icons.person
                              : Icons.landscape,
                          color: const Color(0xFF3A5F0B),
                        ),
                        onPressed: () {
                          widget.onInputInteraction?.call();
                          _toggleUnit(nutrient);
                        },
                        tooltip: _isPerPlant
                            ? 'Switch to per acre'
                            : 'Switch to per plant',
                      )
                    : null,
              ),
              keyboardType: TextInputType.number,
              onTap: widget.onInputInteraction,
              validator: _validateNumber,
              onChanged: (_) => _updateAnalysis(),
            ),
            if (controller.text.isNotEmpty && status != null) ...[
              const SizedBox(height: 12),
              _buildGaugeVisualization(
                  nutrient, double.parse(controller.text)),
            ],
            if (status != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _getStatusColor(status)),
                    ),
                    child: Text(
                      'Status: $status',
                      style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (recommendations != null &&
                      recommendations.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => setState(() =>
                          _expandedRecommendations[nutrient] =
                              !isExpanded),
                      icon: Icon(
                        isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: const Color(0xFF3A5F0B),
                      ),
                      label: Text(
                        isExpanded ? 'Hide' : 'View Recommendations',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF3A5F0B)),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3A5F0B),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (recommendations != null &&
                recommendations.isNotEmpty &&
                isExpanded) ...[
              const SizedBox(height: 12),
              _buildRecommendationTabs(nutrient, recommendations),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeVisualization(String nutrient, double value) {
    final ranges =
        NutrientAnalysisHelper.optimalValues[_selectedStage]?[nutrient];
    if (ranges == null) return const SizedBox.shrink();

    final optimal = ranges['optimal'] ?? 0;
    final high = ranges['high'] ?? 0;
    final maxValue = high * 1.5;
    final position = (value / maxValue).clamp(0.0, 1.0);

    return Column(
      children: [
        Container(
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [
                Colors.red,
                Colors.orange,
                Colors.green,
                Colors.orange,
                Colors.red
              ],
              stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: position *
                    (MediaQuery.of(context).size.width - 64),
                child: Container(
                    width: 4, height: 20, color: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Optimal: ${optimal.toStringAsFixed(1)}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationTabs(
      String nutrient, Map<String, String> recommendations) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recommendations:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A2C2A))),
          const SizedBox(height: 8),
          ...recommendations.entries.map((entry) =>
              _buildRecommendationTab(
                  nutrient, entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildRecommendationTab(
      String nutrient, String type, String recommendation) {
    final key = '${nutrient}_$type';
    final isExpanded = _expandedRecommendations[key] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ExpansionTile(
        title: Text(
          _getRecommendationTypeTitle(type),
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _getRecommendationTypeColor(type)),
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) =>
            setState(() => _expandedRecommendations[key] = expanded),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recommendation,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF3A5F0B))),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      widget.onInputInteraction?.call();
                      _pasteRecommendationToIntervention(
                          recommendation);
                    },
                    icon: const Icon(Icons.copy,
                        size: 16, color: Color(0xFF4A2C2A)),
                    label: const Text('Use as Intervention',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF4A2C2A))),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4A2C2A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ② AI Analysis Panel ───────────────────────────────────────────────────

  Widget _buildAiAnalysisPanel() {
    if (_aiAnalysisResult == null) return const SizedBox.shrink();
    final r = _aiAnalysisResult!;

    // Health score colour.
    final scoreColor = r.healthScore >= 70
        ? Colors.green
        : r.healthScore >= 40
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4A2C2A).withValues(alpha: 0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Color(0xFF3A5F0B), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI Soil Analysis',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A2C2A)),
                    ),
                  ),
                  // Health score badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scoreColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.health_and_safety,
                            size: 14, color: scoreColor),
                        const SizedBox(width: 4),
                        Text(
                          '${r.healthScore}/100',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Summary
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.summary,
                  style: const TextStyle(
                      color: Color(0xFF3A5F0B),
                      fontSize: 13,
                      height: 1.4),
                ),
              ),
              // Interactions
              if (r.interactions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Nutrient Interactions Detected',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A2C2A),
                      fontSize: 13),
                ),
                const SizedBox(height: 6),
                ...r.interactions.map((interaction) {
                  final isHigh =
                      interaction.severity == 'high';
                  final color = isHigh
                      ? Colors.red
                      : interaction.severity == 'medium'
                          ? Colors.orange
                          : Colors.amber;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          interaction.type == 'antagonism'
                              ? Icons.warning_amber
                              : Icons.link,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${interaction.nutrient1} ↔ ${interaction.nutrient2}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: color),
                              ),
                              Text(
                                interaction.description,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4A2C2A)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              // Moisture
              if (r.moisture.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.water_drop,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.moisture,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4A2C2A)),
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

  void _pasteRecommendationToIntervention(String recommendation) {
    setState(() => _interventionMethod = recommendation);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recommendation pasted to intervention method'),
          backgroundColor: Color(0xFF4A2C2A),
        ),
      );
    }
  }

  String _getRecommendationTypeTitle(String type) {
    switch (type) {
      case 'natural':
        return '🌱 Natural Solutions';
      case 'biological':
        return '🦠 Biological Solutions';
      case 'artificial':
        return '⚗️ Artificial Solutions';
      case 'application':
        return '📋 Application Method';
      case 'maintain':
        return '✅ Maintenance';
      case 'avoid':
        return '⚠️ Avoid';
      default:
        return type.toUpperCase();
    }
  }

  Color _getRecommendationTypeColor(String type) {
    switch (type) {
      case 'natural':
        return Colors.green;
      case 'biological':
        return Colors.blue;
      case 'artificial':
        return Colors.orange;
      case 'application':
        return Colors.purple;
      case 'maintain':
        return Colors.teal;
      case 'avoid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Low':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Optimal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _toggleUnit(String nutrient) {
    try {
      final controller = _controllers[nutrient]!;
      if (controller.text.isNotEmpty) {
        final v = double.tryParse(controller.text);
        if (v != null) {
          final converted = _isPerPlant
              ? NutrientAnalysisHelper.convertToPerAcre(
                  nutrient, v, _plantDensity)
              : NutrientAnalysisHelper.convertToPerPlant(
                  nutrient, v, _plantDensity);
          controller.text = converted.toStringAsFixed(2);
        }
      }
      setState(() => _isPerPlant = !_isPerPlant);
      _updateAnalysis();
    } catch (e, st) {
      developer.log('Error toggling unit for $nutrient: $e',
          name: 'CoffeeSoilForm', error: e, stackTrace: st);
    }
  }

  Future<void> _addIntervention() async {
    try {
      widget.onInputInteraction?.call();
      String? method = _interventionMethod;
      DateTime followUpDate =
          DateTime.now().add(const Duration(days: 30));
      final methodController =
          TextEditingController(text: method ?? '');
      final quantityController = TextEditingController();
      final unitController = TextEditingController();
      final currentContext = context;

      final intervention = await showDialog<Map<String, dynamic>>(
        context: currentContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add Intervention',
              style: TextStyle(color: Color(0xFF4A2C2A))),
          content: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: null,
                    decoration: const InputDecoration(
                      labelText: 'Nutrient',
                      border: OutlineInputBorder(),
                      labelStyle:
                          TextStyle(color: Color(0xFF3A5F0B)),
                    ),
                    items: _nutrientStatus.entries
                        .where((e) => e.value != 'Optimal')
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.key.toUpperCase(),
                                  style: const TextStyle(
                                      color:
                                          Color(0xFF3A5F0B))),
                            ))
                        .toList(),
                    onChanged: (value) {
                      widget.onInputInteraction?.call();
                      if (value != null &&
                          _allRecommendations[value] != null) {
                        methodController.text =
                            _allRecommendations[value]![
                                    'artificial'] ??
                                '';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: methodController,
                    decoration: const InputDecoration(
                      labelText: 'Method (Required)',
                      border: OutlineInputBorder(),
                      helperText:
                          'Tap "Use as Intervention" from recommendations',
                      labelStyle:
                          TextStyle(color: Color(0xFF3A5F0B)),
                    ),
                    maxLines: 3,
                    onTap: widget.onInputInteraction,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity (Optional)',
                      border: OutlineInputBorder(),
                      labelStyle:
                          TextStyle(color: Color(0xFF3A5F0B)),
                    ),
                    keyboardType: TextInputType.number,
                    onTap: widget.onInputInteraction,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit (Optional)',
                      border: OutlineInputBorder(),
                      labelStyle:
                          TextStyle(color: Color(0xFF3A5F0B)),
                    ),
                    onTap: widget.onInputInteraction,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      'Follow-up: ${followUpDate.toString().substring(0, 10)}',
                      style: const TextStyle(
                          color: Color(0xFF3A5F0B)),
                    ),
                    trailing: const Icon(Icons.calendar_today,
                        color: Color(0xFF3A5F0B)),
                    onTap: () async {
                      widget.onInputInteraction?.call();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: followUpDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => followUpDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF4A2C2A))),
            ),
            TextButton(
              onPressed: () {
                if (methodController.text.isNotEmpty) {
                  Navigator.pop(dialogContext, {
                    'method': methodController.text,
                    'quantity': quantityController.text,
                    'unit': unitController.text,
                    'followUpDate': followUpDate,
                  });
                }
              },
              child: const Text('Save',
                  style: TextStyle(color: Color(0xFF4A2C2A))),
            ),
          ],
        ),
      );

      if (intervention != null) {
        setState(() {
          _interventionMethod = intervention['method'];
          _interventionQuantity = intervention['quantity'];
          _interventionUnit = intervention['unit'];
          _interventionFollowUpDate = intervention['followUpDate'];
        });
        await _scheduleReminder(
          intervention['followUpDate'],
          'Check soil after applying ${intervention['method']}',
        );
      }
    } catch (e, st) {
      developer.log('Error adding intervention: $e',
          name: 'CoffeeSoilForm', error: e, stackTrace: st);
    }
  }

  Future<void> _scheduleReminder(
      DateTime date, String message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'soil_reminder',
        'Soil Reminders',
        channelDescription: 'Reminders for soil follow-ups',
        importance: Importance.max,
        priority: Priority.high,
      );
      const notificationDetails =
          NotificationDetails(android: androidDetails);
      await widget.notificationsPlugin.zonedSchedule(
        (widget.userId + widget.plotId + date.toString()).hashCode,
        'Soil Follow-Up for ${widget.plotId}',
        message,
        tz.TZDateTime.from(date, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e, st) {
      developer.log('Error scheduling reminder: $e',
          name: 'CoffeeSoilForm', error: e, stackTrace: st);
    }
  }

  Future<String?> _promptPlotId(BuildContext dialogContext) async {
    String plotId = '';
    return showDialog<String>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Enter Plot ID',
            style: TextStyle(color: Color(0xFF4A2C2A))),
        content: TextFormField(
          decoration: const InputDecoration(
            labelText: 'Plot ID *',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(color: Color(0xFF3A5F0B)),
            helperText:
                'Enter a unique identifier (e.g. "Plot-A", "Field-01")',
          ),
          onChanged: (value) => plotId = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF4A2C2A))),
          ),
          TextButton(
            onPressed: () {
              if (plotId.trim().isNotEmpty) {
                Navigator.pop(context, plotId.trim());
              }
            },
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF4A2C2A))),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      for (final c in _controllers.values) {
        c.clear();
      }
      _nutrientStatus.clear();
      _allRecommendations.clear();
      _expandedRecommendations.clear();
      _selectedSoilType = null;
      _interventionMethod = null;
      _interventionQuantity = null;
      _interventionUnit = null;
      _interventionFollowUpDate = null;
      _saveWithRecommendations = false;
      _aiAnalysisResult = null;
    });
  }

  String? _validateNumber(String? value) =>
      value != null && value.isNotEmpty && double.tryParse(value) == null
          ? 'Enter a valid number'
          : null;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Soil & Growth Details ────────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Soil and Growth Details',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A2C2A)),
                    ),
                    const SizedBox(height: 16),

                    // ① Soil Type dropdown + camera scanner button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedSoilType,
                            decoration: InputDecoration(
                              labelText: 'Soil Type (Optional)',
                              border: const OutlineInputBorder(),
                              labelStyle: const TextStyle(
                                  color: Color(0xFF3A5F0B)),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.help_outline,
                                    color: Color(0xFF3A5F0B)),
                                onPressed: _showSoilTypeHelpDialog,
                                tooltip: 'View soil type descriptions',
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Select Soil Type',
                                    style: TextStyle(
                                        color: Color(0xFF3A5F0B))),
                              ),
                              ..._soilTypes.keys.map(
                                (soilType) => DropdownMenuItem(
                                  value: soilType,
                                  child: Text(soilType,
                                      style: const TextStyle(
                                          color: Color(0xFF3A5F0B))),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              widget.onInputInteraction?.call();
                              setState(
                                  () => _selectedSoilType = value);
                              _updateAnalysis();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ① Camera scan button
                        Tooltip(
                          message: 'Scan soil with camera',
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            child: _isScanningImage
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF3A5F0B),
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    onPressed: _scanSoilImage,
                                    icon: const Icon(
                                        Icons.camera_alt,
                                        color:
                                            Color(0xFF3A5F0B)),
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF3A5F0B)
                                              .withValues(alpha: 0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        side: const BorderSide(
                                            color: Color(0xFF3A5F0B)),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStage,
                      decoration: const InputDecoration(
                        labelText: 'Growth Stage',
                        border: OutlineInputBorder(),
                        labelStyle:
                            TextStyle(color: Color(0xFF3A5F0B)),
                      ),
                      items: _stages
                          .map((stage) => DropdownMenuItem(
                                value: stage,
                                child: Text(stage,
                                    style: const TextStyle(
                                        color: Color(0xFF3A5F0B))),
                              ))
                          .toList(),
                      onChanged: (value) {
                        widget.onInputInteraction?.call();
                        setState(() => _selectedStage =
                            value ?? 'Establishment/Seedling');
                        _updateAnalysis();
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _plantDensity.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Plant Density (plants/acre)',
                        border: OutlineInputBorder(),
                        labelStyle:
                            TextStyle(color: Color(0xFF3A5F0B)),
                      ),
                      keyboardType: TextInputType.number,
                      onTap: widget.onInputInteraction,
                      onChanged: (value) {
                        widget.onInputInteraction?.call();
                        final d = int.tryParse(value);
                        if (d != null) setState(() => _plantDensity = d);
                      },
                      validator: (value) =>
                          value == null || int.tryParse(value) == null
                              ? 'Enter a valid number'
                              : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Display Units ────────────────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Display Units',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A2C2A))),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                              value: false,
                              label: Text('Per Acre',
                                  style: TextStyle(fontSize: 14))),
                          ButtonSegment(
                              value: true,
                              label: Text('Per Plant',
                                  style: TextStyle(fontSize: 14))),
                        ],
                        selected: {_isPerPlant},
                        onSelectionChanged: (selection) {
                          widget.onInputInteraction?.call();
                          setState(
                              () => _isPerPlant = selection.first);
                          _updateAnalysis();
                        },
                        style: SegmentedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text('Macronutrients',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A2C2A))),
            const SizedBox(height: 8),
            ..._nutrients.take(6).map(_buildNutrientField),

            const SizedBox(height: 16),
            const Text('Micronutrients',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A2C2A))),
            const SizedBox(height: 8),
            ..._nutrients.skip(6).map(_buildNutrientField),

            const SizedBox(height: 16),

            // ── ② Analyse with AI button ─────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isRunningAiAnalysis ? null : _runAiAnalysis,
                icon: _isRunningAiAnalysis
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3A5F0B)),
                      )
                    : const Icon(Icons.auto_awesome,
                        color: Color(0xFF3A5F0B)),
                label: Text(
                  _isRunningAiAnalysis
                      ? 'Analysing…'
                      : 'Analyse with AI',
                  style: const TextStyle(color: Color(0xFF3A5F0B)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3A5F0B)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            // ② AI analysis panel (shown after AI analysis)
            _buildAiAnalysisPanel(),

            const SizedBox(height: 24),

            // ── Intervention ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _nutrientStatus.values
                        .any((status) => status != 'Optimal')
                    ? _addIntervention
                    : null,
                icon: const Icon(Icons.add_circle, color: Colors.white),
                label: const Text('Add Intervention'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A2C2A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            if (_interventionMethod != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: ListTile(
                  title: Text('Intervention: $_interventionMethod',
                      style: const TextStyle(
                          color: Color(0xFF4A2C2A))),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_interventionQuantity != null &&
                          _interventionUnit != null)
                        Text(
                            'Quantity: $_interventionQuantity $_interventionUnit',
                            style: const TextStyle(
                                color: Color(0xFF3A5F0B))),
                      if (_interventionFollowUpDate != null)
                        Text(
                            'Follow-up: ${_interventionFollowUpDate!.toString().substring(0, 10)}',
                            style: const TextStyle(
                                color: Color(0xFF3A5F0B))),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Save Options ──────────────────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Save Options',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A2C2A))),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Save with recommendations',
                          style:
                              TextStyle(color: Color(0xFF4A2C2A))),
                      subtitle: const Text(
                          'Include all recommendations in saved data',
                          style:
                              TextStyle(color: Color(0xFF3A5F0B))),
                      value: _saveWithRecommendations,
                      onChanged: (value) {
                        widget.onInputInteraction?.call();
                        setState(() =>
                            _saveWithRecommendations =
                                value ?? false);
                      },
                      activeColor: const Color(0xFF4A2C2A),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isGeneratingPlan ? null : _saveForm,
                        icon: _isGeneratingPlan
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(Icons.save,
                                color: Colors.white),
                        label: Text(
                          _isGeneratingPlan
                              ? 'Generating plan…'
                              : _saveWithRecommendations
                                  ? 'Save with Recommendations'
                                  : 'Save Soil Data',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A2C2A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (widget.userId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CoffeeSoilSummaryPage(
                                    userId: widget.userId),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.history,
                            color: Colors.white),
                        label: const Text('View Soil History',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A2C2A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}