import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:coffeecore/screens/diseases/coffee_disease_management_page.dart';
import 'package:coffeecore/screens/diseases/disease_results_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scan state enum
// ─────────────────────────────────────────────────────────────────────────────

enum _ScanState {
  idle,
  imagePicked,
  analysing,
  inconclusive,
  identified,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// AI disease scan result model
// ─────────────────────────────────────────────────────────────────────────────

class _AiDiseaseScanResult {
  final bool confident;
  final String? identifiedDisease;
  final String? growthStage;
  final double? confidencePercent;
  final String? reasoning;
  final List<String> candidates;
  final Map<String, dynamic>? management;

  const _AiDiseaseScanResult({
    required this.confident,
    this.identifiedDisease,
    this.growthStage,
    this.confidencePercent,
    this.reasoning,
    this.candidates = const [],
    this.management,
  });

  factory _AiDiseaseScanResult.fromJson(Map<String, dynamic> json) {
    return _AiDiseaseScanResult(
      confident: json['confident'] == true,
      identifiedDisease: json['identified_disease'] as String?,
      growthStage: json['growth_stage'] as String?,
      confidencePercent: (json['confidence_percent'] as num?)?.toDouble(),
      reasoning: json['reasoning'] as String?,
      candidates: List<String>.from(json['candidates'] ?? []),
      management: json['management'] as Map<String, dynamic>?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISEASE SCAN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseScanPage extends StatefulWidget {
  final FlutterLocalNotificationsPlugin notificationsPlugin;
  const DiseaseScanPage({required this.notificationsPlugin, super.key});

  @override
  State<DiseaseScanPage> createState() => _DiseaseScanPageState();
}

class _DiseaseScanPageState extends State<DiseaseScanPage>
    with TickerProviderStateMixin {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _darkBrown = Color(0xFF3E2723);
  static const Color _midBrown = Color(0xFF6D4C41);
  static const Color _lightBrown = Color(0xFFA1887F);
  static const Color _cream = Color(0xFFFFF8F2);
  static const Color _amber = Color(0xFFFFCC80);
  static const Color _successGreen = Color(0xFF388E3C);
  static const Color _warningOrange = Color(0xFFE65100);

  // ── State ──────────────────────────────────────────────────────────────────
  _ScanState _scanState = _ScanState.idle;
  XFile? _pickedXFile;
  Uint8List? _pickedImageBytes;
  File? _pickedImageFile;

  _AiDiseaseScanResult? _scanResult;
  String? _errorMessage;
  String? _selectedClarification;
  String? _selectedStageForScan;

  final ImagePicker _picker = ImagePicker();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _resultController;
  late Animation<double> _resultFade;
  late Animation<Offset> _resultSlide;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _resultController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _resultFade =
        CurvedAnimation(parent: _resultController, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _resultController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IMAGE PICKING
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
          source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 88);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedXFile = picked;
        _pickedImageBytes = bytes;
        _pickedImageFile = kIsWeb ? null : File(picked.path);
        _scanState = _ScanState.imagePicked;
        _scanResult = null;
        _errorMessage = null;
        _selectedClarification = null;
      });
      _resultController.reset();
    } catch (e) {
      _setError('Could not access the image. Please check camera permissions.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AI DISEASE VISION ANALYSIS — firebase_ai, FirebaseAI.googleAI()
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _analyseImage() async {
    if (_pickedImageBytes == null) return;
    setState(() => _scanState = _ScanState.analysing);

    try {
      final imageBytes = _pickedImageBytes!;
      final mimeType = (_pickedXFile?.mimeType) ??
          ((_pickedXFile?.path.toLowerCase().endsWith('.png') ?? false)
              ? 'image/png'
              : 'image/jpeg');

      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        generationConfig: GenerationConfig(
          temperature: 0.3,
          maxOutputTokens: 1500,
        ),
      );

      final stageHint = _selectedStageForScan != null
          ? 'The farmer believes the crop is at the "$_selectedStageForScan" stage of growth.'
          : 'The farmer is unsure of the exact growth stage.';

      const prompt = r'''
You are an expert agricultural AI assistant specialising in coffee disease identification in East African coffee farming contexts (Kenya, Uganda, Ethiopia, Tanzania).

Analyse the provided image of a coffee plant, leaf, berry, or affected crop part and identify any disease present.

Return ONLY a valid JSON object with NO markdown, no explanation outside the JSON, using exactly this structure:

If confident (>=65%):
{
  "confident": true,
  "identified_disease": "<disease name>",
  "growth_stage": "<Seedling & Nursery | Vegetative Growth | Flowering & Fruit Development | Post-harvest / Storage | Unknown>",
  "confidence_percent": <0-100>,
  "reasoning": "<2-3 sentence explanation of disease identification signs visible in the image>",
  "candidates": [],
  "management": {
    "description": "<description of the disease>",
    "symptoms": "<visible symptoms>",
    "chemical_controls": ["<fungicide/bactericide + application note>"],
    "biological_controls": ["<biological agent>"],
    "cultural_controls": ["<cultural practice>"],
    "possible_causes": ["<cause>"],
    "preventive_measures": ["<preventive action>"]
  }
}

If NOT confident (<65%):
{
  "confident": false,
  "identified_disease": null,
  "growth_stage": "<best guess or Unknown>",
  "confidence_percent": <number>,
  "reasoning": "<why uncertain — what is ambiguous or unclear>",
  "candidates": ["<possible disease 1>", "<possible disease 2>", "<possible disease 3>"],
  "management": null
}

If image is unclear or does not show disease symptoms:
{
  "confident": false,
  "identified_disease": null,
  "growth_stage": "Unknown",
  "confidence_percent": 0,
  "reasoning": "The image does not clearly show disease symptoms. Please retake the photo focusing on the affected leaf, berry, or stem showing clear symptoms.",
  "candidates": [],
  "management": null
}
''';

      final response = await model.generateContent([
        Content.multi([
          TextPart('$stageHint\n\n$prompt'),
          InlineDataPart(mimeType, imageBytes),
        ]),
      ]);

      _parseAndHandleResponse(response.text ?? '');
    } on FirebaseException catch (e) {
      _setError(
          'CoffeeCore AI error: ${e.message ?? e.code}. Check your connection and try again.');
    } catch (e) {
      _setError(
          'Analysis failed: ${e.toString()}. Please retake the photo and try again.');
    }
  }

  void _parseAndHandleResponse(String rawText) {
    try {
      String cleaned = rawText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: false), '')
            .replaceAll(RegExp(r'\s*```$', multiLine: false), '')
            .trim();
      }
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final result = _AiDiseaseScanResult.fromJson(json);

      setState(() {
        _scanResult = result;
        _scanState =
            result.confident ? _ScanState.identified : _ScanState.inconclusive;
      });
      _resultController.forward(from: 0);

      if (result.confident && result.identifiedDisease != null) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) _navigateToResults(result);
        });
      }
    } catch (_) {
      _setError(
          'Could not interpret the AI response. Please try again with a clearer photo.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLARIFICATION RE-ANALYSIS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _reAnalyseWithClarification(String chosenDisease) async {
    setState(() {
      _selectedClarification = chosenDisease;
      _scanState = _ScanState.analysing;
    });

    try {
      final imageBytes = _pickedImageBytes!;
      final mimeType = (_pickedXFile?.mimeType) ??
          ((_pickedXFile?.path.toLowerCase().endsWith('.png') ?? false)
              ? 'image/png'
              : 'image/jpeg');

      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        generationConfig:
            GenerationConfig(temperature: 0.3, maxOutputTokens: 1500),
      );

      final stageHint = _selectedStageForScan != null
          ? 'Growth stage context: $_selectedStageForScan.'
          : '';

      final prompt = '''
You are an expert agricultural AI for coffee disease management in East Africa.

The farmer confirmed the disease is most likely "$chosenDisease". $stageHint

Return ONLY valid JSON (no markdown):
{
  "confident": true,
  "identified_disease": "$chosenDisease",
  "growth_stage": "<stage>",
  "confidence_percent": <number>,
  "reasoning": "<2-sentence confirmation of why this matches>",
  "candidates": [],
  "management": {
    "description": "<disease description>",
    "symptoms": "<symptoms>",
    "chemical_controls": ["<item>", "<item>"],
    "biological_controls": ["<item>"],
    "cultural_controls": ["<item>"],
    "possible_causes": ["<item>", "<item>"],
    "preventive_measures": ["<item>", "<item>", "<item>"]
  }
}
''';

      final response = await model.generateContent([
        Content.multi([TextPart(prompt), InlineDataPart(mimeType, imageBytes)]),
      ]);
      _parseAndHandleResponse(response.text ?? '');
    } catch (e) {
      _setError('Re-analysis failed: ${e.toString()}. Please try again.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION + HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _navigateToResults(_AiDiseaseScanResult result) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: DiseaseResultsPage(
            selectedStage: result.growthStage ?? 'Unknown',
            selectedDisease: result.identifiedDisease,
            detectionMode: DiseaseDetectionMode.aiScan,
            scannedImageFile: kIsWeb ? null : _pickedImageFile,
            scannedImageBytes: _pickedImageBytes,
            aiManagementData: result.management,
            aiReasoning: result.reasoning,
            aiConfidence: result.confidencePercent,
            notificationsPlugin: widget.notificationsPlugin,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _setError(String msg) {
    if (!mounted) return;
    debugPrint('[DiseaseScan] Error: $msg');
    setState(() {
      _scanState = _ScanState.error;
      _errorMessage = msg;
    });
  }

  void _resetScan() {
    setState(() {
      _scanState = _ScanState.idle;
      _pickedXFile = null;
      _pickedImageBytes = null;
      _pickedImageFile = null;
      _scanResult = null;
      _errorMessage = null;
      _selectedClarification = null;
    });
    _resultController.reset();
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
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructions(),
            const SizedBox(height: 20),
            _buildImageArea(),
            const SizedBox(height: 16),
            _buildStageHintDropdown(),
            const SizedBox(height: 20),
            _buildSourceButtons(),
            const SizedBox(height: 24),
            _buildActionArea(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _darkBrown,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text('CoffeeCore Disease Scanner',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
      actions: [
        if (_pickedXFile != null)
          TextButton.icon(
            onPressed: _resetScan,
            icon: const Icon(Icons.refresh_rounded, color: _amber, size: 18),
            label: Text('Reset',
                style: GoogleFonts.poppins(color: _amber, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [_darkBrown, _midBrown],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.biotech_rounded, color: _amber, size: 20),
            const SizedBox(width: 8),
            Text('How to Get Best Results',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          ...[
            '📸 Focus closely on the affected leaf, berry, or stem',
            '☀️  Use good natural lighting — avoid shadows or blurring',
            '🌿 Capture the most prominent symptom clearly in frame',
            '🌱 Optionally set the growth stage below to improve accuracy',
          ].map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(tip,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12.5, height: 1.45)),
              )),
        ],
      ),
    );
  }

  Widget _buildImageArea() {
    return GestureDetector(
      onTap: _scanState == _ScanState.idle ? _showSourceSheet : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 220,
        decoration: BoxDecoration(
          color: _pickedImageBytes != null ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _pickedImageBytes != null
                ? _darkBrown.withValues(alpha: .3)
                : const Color(0xFFD7C5BC),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildImageAreaContent(),
      ),
    );
  }

  Widget _buildImageAreaContent() {
    if (_pickedImageBytes != null) {
      return Image.memory(_pickedImageBytes!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImageAreaPlaceholder());
    }
    return _buildImageAreaPlaceholder();
  }

  Widget _buildImageAreaPlaceholder() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_rounded, color: _lightBrown, size: 48),
          const SizedBox(height: 12),
          Text('Tap to add a photo',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _darkBrown)),
          const SizedBox(height: 4),
          Text('Camera or Gallery',
              style: GoogleFonts.poppins(fontSize: 12, color: _lightBrown)),
        ],
      ),
    );
  }

  Widget _buildStageHintDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7C5BC)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedStageForScan,
        decoration: InputDecoration(
          labelText: 'Growth Stage Hint (Optional)',
          labelStyle: GoogleFonts.poppins(fontSize: 13, color: _midBrown),
          border: InputBorder.none,
          prefixIcon:
              const Icon(Icons.layers_rounded, color: _darkBrown, size: 20),
          contentPadding: EdgeInsets.zero,
        ),
        hint: Text('Helps AI — select if known',
            style: GoogleFonts.poppins(fontSize: 13, color: _lightBrown)),
        isExpanded: true,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.expand_more_rounded, color: _midBrown),
        style: GoogleFonts.poppins(fontSize: 13.5, color: _darkBrown),
        items: [
          'Seedling & Nursery',
          'Vegetative Growth',
          'Flowering & Fruit Development',
          'Post-harvest / Storage',
        ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (val) => setState(() => _selectedStageForScan = val),
      ),
    );
  }

  Widget _buildSourceButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSourceButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            onTap: () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSourceButton(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD7C5BC)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _darkBrown, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _darkBrown)),
        ]),
      ),
    );
  }

  Widget _buildActionArea() {
    if (_pickedImageBytes == null) return const SizedBox.shrink();

    return Column(
      children: [
        if (_scanState == _ScanState.imagePicked) _buildAnalyseButton(),
        if (_scanState == _ScanState.analysing) _buildAnalysingIndicator(),
        if (_scanState == _ScanState.inconclusive && _scanResult != null)
          SlideTransition(
            position: _resultSlide,
            child: FadeTransition(
              opacity: _resultFade,
              child: _buildInconclusivePanel(),
            ),
          ),
        if (_scanState == _ScanState.identified && _scanResult != null)
          SlideTransition(
            position: _resultSlide,
            child: FadeTransition(
              opacity: _resultFade,
              child: _buildIdentifiedPanel(),
            ),
          ),
        if (_scanState == _ScanState.error) _buildErrorPanel(),
      ],
    );
  }

  Widget _buildAnalyseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _analyseImage,
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkBrown,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          shadowColor: _darkBrown.withValues(alpha: .4),
        ),
        icon: const Icon(Icons.biotech_rounded, size: 22),
        label: Text('Analyse for Disease',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  Widget _buildAnalysingIndicator() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: _darkBrown, strokeWidth: 2.5),
        const SizedBox(height: 16),
        Text('CoffeeCore AI is identifying the disease…',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: _darkBrown),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Analysing symptom patterns, pathogen markers, and growth stage…',
            style: GoogleFonts.poppins(
                fontSize: 12, color: _midBrown, height: 1.4),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildInconclusivePanel() {
    final result = _scanResult;
    if (result == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _warningOrange.withValues(alpha: .4)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _warningOrange.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.help_outline_rounded,
                color: _warningOrange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Disease Unclear',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _darkBrown)),
              Text(
                '${result.confidencePercent?.toStringAsFixed(0) ?? "—"}% confidence',
                style: GoogleFonts.poppins(fontSize: 12, color: _midBrown),
              ),
            ]),
          ),
        ]),
        if (result.reasoning != null) ...[
          const SizedBox(height: 12),
          Text(result.reasoning!,
              style: GoogleFonts.poppins(
                  fontSize: 12.5, color: _midBrown, height: 1.5)),
        ],
        if (result.candidates.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Select the most likely disease:',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _darkBrown)),
          const SizedBox(height: 10),
          ...result.candidates.map(_buildCandidateTile),
        ],
        if (result.candidates.isEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _resetScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: Text('Retake Photo',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildCandidateTile(String candidate) {
    final isSelected = _selectedClarification == candidate;
    return GestureDetector(
      onTap: () => _reAnalyseWithClarification(candidate),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? _darkBrown : _cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? _darkBrown : const Color(0xFFD7C5BC)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: _darkBrown.withValues(alpha: .25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : [],
        ),
        child: Row(children: [
          Icon(Icons.coronavirus_rounded,
              color: isSelected ? _amber : _midBrown, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(candidate,
                style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : _darkBrown)),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: isSelected ? Colors.white70 : _lightBrown, size: 14),
        ]),
      ),
    );
  }

  Widget _buildIdentifiedPanel() {
    final result = _scanResult;
    if (result == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _successGreen.withValues(alpha: .5)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Icon(Icons.check_circle_rounded, color: _successGreen, size: 44),
        const SizedBox(height: 12),
        Text(result.identifiedDisease ?? 'Disease Identified',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: _darkBrown),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          '${result.confidencePercent?.toStringAsFixed(0) ?? "—"}% confidence  ·  ${result.growthStage ?? ""}',
          style: GoogleFonts.poppins(fontSize: 12.5, color: _midBrown),
        ),
        if (result.reasoning != null) ...[
          const SizedBox(height: 12),
          Text(result.reasoning!,
              style: GoogleFonts.poppins(
                  fontSize: 12.5, color: _midBrown, height: 1.5),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        Row(children: [
          const SizedBox(width: 16),
          const CircularProgressIndicator(color: _darkBrown, strokeWidth: 2),
          const SizedBox(width: 12),
          Text('Loading disease treatment details…',
              style: GoogleFonts.poppins(fontSize: 12.5, color: _midBrown)),
        ]),
      ]),
    );
  }

  Widget _buildErrorPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        const Icon(Icons.error_outline_rounded,
            color: Colors.redAccent, size: 36),
        const SizedBox(height: 10),
        Text(_errorMessage ?? 'An unexpected error occurred.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: _midBrown, height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _pickedImageBytes != null ? _analyseImage : _resetScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: _darkBrown,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(_pickedImageBytes != null ? 'Try Again' : 'Start Over',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]),
    );
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.brown.shade200,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Select Image Source',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkBrown)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _buildSheetOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      })),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildSheetOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      })),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7C5BC)),
        ),
        child: Column(children: [
          Icon(icon, color: _darkBrown, size: 32),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _darkBrown)),
        ]),
      ),
    );
  }
}
