import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/pests/coffee_pest_management_page.dart';
import 'package:coffeecore/screens/pests/pest_results_page.dart';
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
// CoffeeCore AI scan result model
// ─────────────────────────────────────────────────────────────────────────────

class _AiScanResult {
  final bool confident;
  final String? identifiedPest;
  final String? growthStage;
  final double? confidencePercent;
  final String? reasoning;
  final List<String> candidates;
  final Map<String, dynamic>? management;

  const _AiScanResult({
    required this.confident,
    this.identifiedPest,
    this.growthStage,
    this.confidencePercent,
    this.reasoning,
    this.candidates = const [],
    this.management,
  });

  factory _AiScanResult.fromJson(Map<String, dynamic> json) {
    return _AiScanResult(
      confident:         json['confident'] == true,
      identifiedPest:    json['identified_pest'] as String?,
      growthStage:       json['growth_stage'] as String?,
      confidencePercent: (json['confidence_percent'] as num?)?.toDouble(),
      reasoning:         json['reasoning'] as String?,
      candidates:        List<String>.from(json['candidates'] ?? []),
      management:        json['management'] as Map<String, dynamic>?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PEST SCAN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class PestScanPage extends StatefulWidget {
  final FlutterLocalNotificationsPlugin notificationsPlugin;
  const PestScanPage({required this.notificationsPlugin, super.key});

  @override
  State<PestScanPage> createState() => _PestScanPageState();
}

class _PestScanPageState extends State<PestScanPage>
    with TickerProviderStateMixin {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _darkBrown     = Color(0xFF3E2723);
  static const Color _midBrown      = Color(0xFF6D4C41);
  static const Color _lightBrown    = Color(0xFFA1887F);
  static const Color _cream         = Color(0xFFFFF8F2);
  static const Color _amber         = Color(0xFFFFCC80);
  static const Color _successGreen  = Color(0xFF388E3C);
  static const Color _warningOrange = Color(0xFFE65100);

  // ── State ──────────────────────────────────────────────────────────────────
  _ScanState _scanState             = _ScanState.idle;
  /// Raw XFile from the picker — valid on all platforms.
  XFile?     _pickedXFile;
  /// Decoded bytes — used for Gemini analysis and Image.memory on web.
  Uint8List? _pickedImageBytes;
  /// Native File reference — only populated on non-web platforms.
  File?      _pickedImageFile;

  _AiScanResult? _scanResult;
  String?    _errorMessage;
  String?    _selectedClarification;
  String?    _selectedStageForScan;

  final ImagePicker _picker = ImagePicker();

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;
  late AnimationController _resultController;
  late Animation<double>   _resultFade;
  late Animation<Offset>   _resultSlide;

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
    _resultFade  = CurvedAnimation(parent: _resultController, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IMAGE PICKING
  // Web: XFile.path is a blob URL — File() construction is skipped.
  // Mobile: File() is constructed normally from the local filesystem path.
  // Bytes are always read via XFile.readAsBytes() which works on all platforms.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 88);
      if (picked == null) return;

      // Read bytes universally — works on web (blob) and mobile (file) alike.
      final bytes = await picked.readAsBytes();

      setState(() {
        _pickedXFile           = picked;
        _pickedImageBytes      = bytes;
        _pickedImageFile       = kIsWeb ? null : File(picked.path);
        _scanState             = _ScanState.imagePicked;
        _scanResult            = null;
        _errorMessage          = null;
        _selectedClarification = null;
      });
      _resultController.reset();
    } catch (e) {
      _setError('Could not access the image. Please check camera permissions.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COFFEECORE AI VISION ANALYSIS  — firebase_ai package, FirebaseAI.googleAI()
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _analyseImage() async {
    if (_pickedImageBytes == null) return;
    setState(() => _scanState = _ScanState.analysing);

    try {
      // Bytes already loaded during pick — works on both web and mobile.
      final imageBytes = _pickedImageBytes!;
      final mimeType   = (_pickedXFile?.mimeType) ??
          ((_pickedXFile?.path.toLowerCase().endsWith('.png') ?? false)
              ? 'image/png'
              : 'image/jpeg');

      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        generationConfig: GenerationConfig(
          temperature:     0.3,
          maxOutputTokens: 1500,
        ),
      );

      final stageHint = _selectedStageForScan != null
          ? 'The farmer believes this is at the "$_selectedStageForScan" stage of growth.'
          : 'The farmer is unsure of the exact growth stage.';

      const prompt = '''
You are an expert agricultural AI assistant specialising in coffee crop pest identification in East African coffee farming contexts (Kenya, Uganda, Ethiopia, Tanzania).

Analyse the provided image of a coffee plant or affected crop part and identify any pest infestation present.

Return ONLY a valid JSON object with NO markdown, no explanation outside the JSON, using exactly this structure:

If confident (>=65%):
{
  "confident": true,
  "identified_pest": "<pest name>",
  "growth_stage": "<Vegetative Stage | Flowering & Fruit Development | Post-harvest / Storage | Unknown>",
  "confidence_percent": <0-100>,
  "reasoning": "<2-3 sentence explanation>",
  "candidates": [],
  "management": {
    "description": "<description>",
    "symptoms": "<symptoms>",
    "chemical_controls": ["<item>"],
    "biological_controls": ["<item>"],
    "possible_causes": ["<item>"],
    "preventive_measures": ["<item>"]
  }
}

If NOT confident (<65%):
{
  "confident": false,
  "identified_pest": null,
  "growth_stage": "<best guess or Unknown>",
  "confidence_percent": <number>,
  "reasoning": "<why uncertain>",
  "candidates": ["<pest 1>", "<pest 2>", "<pest 3>"],
  "management": null
}

If image is unclear:
{
  "confident": false,
  "identified_pest": null,
  "growth_stage": "Unknown",
  "confidence_percent": 0,
  "reasoning": "The image does not clearly show pest damage. Please retake the photo focusing on the damaged crop part.",
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
      _setError('CoffeeCore AI error: ${e.message ?? e.code}. Check your connection and try again.');
    } catch (e) {
      _setError('Analysis failed: ${e.toString()}. Please retake the photo and try again.');
    }
  }

  void _parseAndHandleResponse(String rawText) {
    try {
      String cleaned = rawText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: false), '')
            .replaceAll(RegExp(r'\s*```$',           multiLine: false), '')
            .trim();
      }
      final json   = jsonDecode(cleaned) as Map<String, dynamic>;
      final result = _AiScanResult.fromJson(json);

      setState(() {
        _scanResult = result;
        _scanState  = result.confident ? _ScanState.identified : _ScanState.inconclusive;
      });
      _resultController.forward(from: 0);

      if (result.confident && result.identifiedPest != null) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) _navigateToResults(result);
        });
      }
    } catch (_) {
      _setError('Could not interpret the AI response. Please try again with a clearer photo.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLARIFICATION RE-ANALYSIS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _reAnalyseWithClarification(String chosenPest) async {
    setState(() {
      _selectedClarification = chosenPest;
      _scanState             = _ScanState.analysing;
    });

    try {
      final imageBytes = _pickedImageBytes!;
      final mimeType   = (_pickedXFile?.mimeType) ??
          ((_pickedXFile?.path.toLowerCase().endsWith('.png') ?? false)
              ? 'image/png' : 'image/jpeg');

      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        generationConfig: GenerationConfig(temperature: 0.3, maxOutputTokens: 1200),
      );

      final stageHint = _selectedStageForScan != null
          ? 'Growth stage context: $_selectedStageForScan.' : '';

      final prompt = '''
You are an expert agricultural AI for coffee pest management.

The farmer confirmed the pest is most likely "$chosenPest". $stageHint

Return ONLY valid JSON (no markdown):
{
  "confident": true,
  "identified_pest": "$chosenPest",
  "growth_stage": "<stage>",
  "confidence_percent": <number>,
  "reasoning": "<2-sentence confirmation>",
  "candidates": [],
  "management": {
    "description": "<description>",
    "symptoms": "<symptoms>",
    "chemical_controls": ["<item>", "<item>"],
    "biological_controls": ["<item>"],
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

  void _navigateToResults(_AiScanResult result) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: PestResultsPage(
            selectedStage:       result.growthStage ?? 'Unknown',
            selectedPest:        result.identifiedPest,
            detectionMode:       PestDetectionMode.aiScan,
            // On web: pass bytes only (Image.file is not supported on web).
            // On mobile: pass File (bytes also passed for consistency).
            scannedImageFile:    kIsWeb ? null : _pickedImageFile,
            scannedImageBytes:   _pickedImageBytes,
            aiManagementData:    result.management,
            aiReasoning:         result.reasoning,
            aiConfidence:        result.confidencePercent,
            notificationsPlugin: widget.notificationsPlugin,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _setError(String msg) {
    if (!mounted) return;
    debugPrint('[PestScan] Error: $msg');
    setState(() { _scanState = _ScanState.error; _errorMessage = msg; });
  }

  void _resetScan() {
    setState(() {
      _scanState             = _ScanState.idle;
      _pickedXFile           = null;
      _pickedImageBytes      = null;
      _pickedImageFile       = null;
      _scanResult            = null;
      _errorMessage          = null;
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
      title: Text('CoffeeCore AI Scanner',
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
            const Icon(Icons.auto_awesome_rounded, color: _amber, size: 18),
            const SizedBox(width: 8),
            Text('How AI Scanning Works',
                style: GoogleFonts.poppins(
                    color: _amber, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ...[
            '📸  Take or upload a clear photo of the affected crop part',
            '🤖  CoffeeCore AI analyses the image for pest signs',
            '✅  Confirmed pest → full management plan is shown',
            '❓  Uncertain → select from suggested options to refine',
          ].map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(step,
                    style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: .88),
                        fontSize: 12.5,
                        height: 1.4)),
              )),
        ],
      ),
    );
  }

  Widget _buildImageArea() {
    final bool hasImage    = _pickedXFile != null;
    final bool isAnalysing = _scanState == _ScanState.analysing;

    return GestureDetector(
      onTap: hasImage ? null : _showSourceSheet,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: hasImage ? _darkBrown : const Color(0xFFD7C5BC),
              width: hasImage ? 2 : 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Image display — web uses Image.memory, mobile uses Image.file ─
            if (hasImage)
              kIsWeb
                  ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                  : Image.file(_pickedImageFile!, fit: BoxFit.cover)
            else
              _buildImagePlaceholder(),

            if (isAnalysing)
              Container(
                color: _darkBrown.withValues(alpha: .72),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 68, height: 68,
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: .15),
                          shape: BoxShape.circle,
                          border: Border.all(color: _amber, width: 2),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: _amber, size: 30),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Analysing with CoffeeCore AI…',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('This may take a few seconds',
                        style: GoogleFonts.poppins(
                            color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 18),
                    const SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(
                          color: _amber,
                          backgroundColor: Colors.white24,
                          minHeight: 3),
                    ),
                  ],
                ),
              ),

            if (_scanState == _ScanState.identified && _scanResult != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  color: _successGreen.withValues(alpha: .85),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Identified: ${_scanResult!.identifiedPest ?? "—"}  '
                        '(${_scanResult!.confidencePercent?.toStringAsFixed(0) ?? "—"}% confidence)',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_rounded,
            size: 52, color: _lightBrown.withValues(alpha: .6)),
        const SizedBox(height: 12),
        Text('Tap to take or upload a photo',
            style: GoogleFonts.poppins(
                fontSize: 14, color: _midBrown, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('Focus on the damaged leaves, stem, berries or roots',
            style: GoogleFonts.poppins(fontSize: 12, color: _lightBrown),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildStageHintDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7C5BC)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedStageForScan,
        decoration: InputDecoration(
          labelText: 'Growth Stage Hint (optional)',
          labelStyle: GoogleFonts.poppins(fontSize: 13, color: _midBrown),
          helperText: 'Providing the stage helps the AI give a more accurate result',
          helperStyle: GoogleFonts.poppins(fontSize: 11, color: _lightBrown),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.eco_rounded, color: _darkBrown, size: 20),
          contentPadding: EdgeInsets.zero,
        ),
        hint: Text('Not sure — skip this',
            style: GoogleFonts.poppins(fontSize: 13, color: _lightBrown)),
        isExpanded: true,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.expand_more_rounded, color: _midBrown),
        style: GoogleFonts.poppins(fontSize: 13.5, color: _darkBrown),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('Not sure — skip this',
                style: GoogleFonts.poppins(fontSize: 13, color: _lightBrown)),
          ),
          ...kCoffeeStages.map((s) => DropdownMenuItem<String>(
                value: s, child: Text(s))),
        ],
        onChanged: (val) => setState(() => _selectedStageForScan = val),
      ),
    );
  }

  Widget _buildSourceButtons() {
    final bool busy = _scanState == _ScanState.analysing;
    return Row(children: [
      Expanded(child: _buildSourceButton(
          icon: Icons.camera_alt_rounded, label: 'Camera',
          onTap: busy ? null : () => _pickImage(ImageSource.camera))),
      const SizedBox(width: 12),
      Expanded(child: _buildSourceButton(
          icon: Icons.photo_library_rounded, label: 'Gallery',
          onTap: busy ? null : () => _pickImage(ImageSource.gallery))),
    ]);
  }

  Widget _buildSourceButton(
      {required IconData icon, required String label, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD7C5BC)),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: Column(children: [
            Icon(icon, color: _darkBrown, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _darkBrown)),
          ]),
        ),
      ),
    );
  }

  Widget _buildActionArea() {
    switch (_scanState) {
      case _ScanState.idle:
        return _buildSelectImageCta();
      case _ScanState.imagePicked:
        return _buildAnalyseButton();
      case _ScanState.analysing:
        return const SizedBox.shrink();
      case _ScanState.inconclusive:
        return FadeTransition(
            opacity: _resultFade,
            child: SlideTransition(
                position: _resultSlide, child: _buildInconclusivePanel()));
      case _ScanState.identified:
        return FadeTransition(
            opacity: _resultFade,
            child: SlideTransition(
                position: _resultSlide, child: _buildIdentifiedPanel()));
      case _ScanState.error:
        return _buildErrorPanel();
    }
  }

  Widget _buildSelectImageCta() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7C5BC)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _darkBrown.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.touch_app_rounded, color: _darkBrown, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Select an image above using Camera or Gallery to begin AI analysis.',
            style: GoogleFonts.poppins(fontSize: 13, color: _midBrown, height: 1.4),
          ),
        ),
      ]),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 5,
          shadowColor: _darkBrown.withValues(alpha: .4),
        ),
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: Text('Analyse with CoffeeCore AI',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2)),
      ),
    );
  }

  Widget _buildInconclusivePanel() {
    final result = _scanResult;
    if (result == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _warningOrange.withValues(alpha: .5)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _warningOrange.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.help_outline_rounded,
                  color: _warningOrange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('More Information Needed',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700, color: _darkBrown)),
                  Text(
                    'Confidence: ${result.confidencePercent?.toStringAsFixed(0) ?? "—"}%',
                    style: GoogleFonts.poppins(fontSize: 12, color: _warningOrange),
                  ),
                ],
              ),
            ),
          ]),
          if (result.reasoning != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD7C5BC))),
              child: Text(result.reasoning!,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, color: _midBrown, height: 1.5)),
            ),
          ],
          if (result.candidates.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Which of these best matches what you see?',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _darkBrown)),
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
                  backgroundColor: _darkBrown, foregroundColor: Colors.white,
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
        ],
      ),
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
              ? [BoxShadow(
                  color: _darkBrown.withValues(alpha: .25),
                  blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(children: [
          Icon(Icons.bug_report_rounded,
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
        Text(result.identifiedPest ?? 'Pest Identified',
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
          Text('Loading management details…',
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
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
        const SizedBox(height: 10),
        Text(_errorMessage ?? 'An unexpected error occurred.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: _midBrown, height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _pickedImageBytes != null ? _analyseImage : _resetScan,
          style: ElevatedButton.styleFrom(
            backgroundColor: _darkBrown, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(_pickedImageBytes != null ? 'Try Again' : 'Start Over',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.brown.shade200,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Select Image Source',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _darkBrown)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _buildSheetOption(
                  icon: Icons.camera_alt_rounded, label: 'Camera',
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); })),
              const SizedBox(width: 16),
              Expanded(child: _buildSheetOption(
                  icon: Icons.photo_library_rounded, label: 'Gallery',
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); })),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetOption(
      {required IconData icon, required String label, required VoidCallback onTap}) {
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
                  fontSize: 14, fontWeight: FontWeight.w600, color: _darkBrown)),
        ]),
      ),
    );
  }
}