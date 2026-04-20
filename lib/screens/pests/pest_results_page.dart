import 'dart:io';
import 'dart:typed_data';
import 'package:coffeecore/screens/pests/coffee_pest_management_page.dart';
import 'package:coffeecore/screens/pests/gemini_pest_ai_service.dart';
import 'package:coffeecore/screens/pests/pest_firestore_service.dart';
import 'package:coffeecore/screens/pests/pest_image_search_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coffeecore/models/coffee_pest_models.dart';
import 'package:coffeecore/screens/Pest%20Management/coffee_intervention_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Detection mode
// ─────────────────────────────────────────────────────────────────────────────

enum PestDetectionMode {
  knownBoth,
  knownStage,
  aiScan,
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal page-state machine
// ─────────────────────────────────────────────────────────────────────────────

enum _PageState {
  loadingImages,
  awaitingConfirmation,
  pestSelection,
  loadingManagement,
  showingManagement,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// Pest card model for Path B grid
// ─────────────────────────────────────────────────────────────────────────────

class _PestCard {
  final String name;
  final List<String> imageUrls;
  final bool imagesLoaded;

  const _PestCard({
    required this.name,
    this.imageUrls = const [],
    this.imagesLoaded = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PEST RESULTS PAGE
// ─────────────────────────────────────────────────────────────────────────────

class PestResultsPage extends StatefulWidget {
  final String selectedStage;
  final String? selectedPest;
  final PestDetectionMode detectionMode;
  final CoffeePestData? localPestData;

  /// Native File reference — populated on mobile only (null on web).
  /// Use [scannedImageBytes] for web-safe image display.
  final File? scannedImageFile;

  /// Raw bytes of the scanned image — populated on all platforms when an
  /// image was captured via the AI scanner.  Use this for [Image.memory]
  /// on Flutter Web where [Image.file] is not supported.
  final Uint8List? scannedImageBytes;

  final Map<String, dynamic>? aiManagementData;
  final String? aiReasoning;
  final double? aiConfidence;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const PestResultsPage({
    required this.selectedStage,
    required this.selectedPest,
    required this.detectionMode,
    required this.notificationsPlugin,
    this.localPestData,
    this.scannedImageFile,
    this.scannedImageBytes,
    this.aiManagementData,
    this.aiReasoning,
    this.aiConfidence,
    super.key,
  });

  @override
  State<PestResultsPage> createState() => _PestResultsPageState();
}

class _PestResultsPageState extends State<PestResultsPage>
    with TickerProviderStateMixin {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _darkBrown    = Color(0xFF3E2723);
  static const Color _midBrown     = Color(0xFF6D4C41);
  static const Color _lightBrown   = Color(0xFFA1887F);
  static const Color _cream        = Color(0xFFFFF8F2);
  static const Color _amber        = Color(0xFFFFCC80);
  static const Color _successGreen = Color(0xFF388E3C);

  // ── Page state ─────────────────────────────────────────────────────────────
  _PageState _pageState   = _PageState.loadingImages;
  String?    _errorMessage;

  // ── Resolved data ──────────────────────────────────────────────────────────
  String?            _resolvedPest;
  String             _resolvedStage = '';
  List<String>       _onlinePestImages = [];
  Map<String, dynamic>? _managementData;

  // ── Path B ─────────────────────────────────────────────────────────────────
  List<_PestCard> _pestCards = [];
  String?         _selectedPestInGrid;

  // ── Save state ─────────────────────────────────────────────────────────────
  bool _isSaving  = false;
  bool _savedToDb = false;

  // ── Carousel ───────────────────────────────────────────────────────────────
  final PageController _carouselController = PageController();
  int _currentCarouselPage = 0;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _fadeController;
  late Animation<double>   _fadeAnim;
  late AnimationController _cardStaggerController;

  final ScrollController _scrollController = ScrollController();

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _resolvedStage = widget.selectedStage;
    _resolvedPest  = widget.selectedPest;

    debugPrint('[PestResultsPage] 🌱 initState — '
        'mode=${widget.detectionMode.name} | '
        'pest="${widget.selectedPest}" | '
        'stage="${widget.selectedStage}"');

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _cardStaggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _initialiseForMode();
  }

  @override
  void dispose() {
    debugPrint('[PestResultsPage] 🔚 dispose — '
        'pest="$_resolvedPest" stage="$_resolvedStage"');
    _fadeController.dispose();
    _cardStaggerController.dispose();
    _carouselController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initialiseForMode() {
    debugPrint('[PestResultsPage] 🔀 Routing to '
        '${widget.detectionMode.name} path');
    switch (widget.detectionMode) {
      case PestDetectionMode.knownBoth:
        _runPathA();
      case PestDetectionMode.knownStage:
        _runPathB();
      case PestDetectionMode.aiScan:
        _runPathC();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH A — Known pest + known stage
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _runPathA() async {
    debugPrint('[PestResultsPage] 🅰️ Path A started — '
        'fetching images for "${_resolvedPest!}"');
    setState(() => _pageState = _PageState.loadingImages);
    try {
      final urls = await PestImageSearchService.searchPestImages(
          pestName: _resolvedPest!, stage: _resolvedStage);
      debugPrint('[PestResultsPage] 🅰️ Path A image fetch complete — '
          '${urls.length} images for "${_resolvedPest!}"');
      if (!mounted) return;
      setState(() {
        _onlinePestImages = urls;
        _pageState        = _PageState.awaitingConfirmation;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      debugPrint('[PestResultsPage] ⚠️ Path A image fetch failed for '
          '"${_resolvedPest!}": $e — proceeding with local assets.');
      if (!mounted) return;
      setState(() {
        _onlinePestImages = [];
        _pageState        = _PageState.awaitingConfirmation;
      });
      _fadeController.forward(from: 0);
    }
  }

  Future<void> _onConfirmPestA() async {
    debugPrint('[PestResultsPage] ✅ Path A — farmer confirmed '
        '"${_resolvedPest!}". Loading management details.');
    setState(() => _pageState = _PageState.loadingManagement);
    await _loadManagementDetails(_resolvedPest!, _resolvedStage);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH B — Known stage only (farmer picks pest from list)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _runPathB() async {
    debugPrint('[PestResultsPage] 🅱️ Path B started — '
        'stage="$_resolvedStage"');
    setState(() => _pageState = _PageState.loadingImages);
    final pestNames = kStagePests[_resolvedStage] ?? [];

    debugPrint('[PestResultsPage] 🅱️ Found ${pestNames.length} pests '
        'for stage "$_resolvedStage": ${pestNames.join(", ")}');

    _pestCards = pestNames.map((n) => _PestCard(name: n)).toList();

    if (mounted) {
      setState(() => _pageState = _PageState.pestSelection);
      _fadeController.forward(from: 0);
      _cardStaggerController.forward(from: 0);
    }

    debugPrint('[PestResultsPage] 🅱️ Loading thumbnail images for '
        '${_pestCards.length} pest cards…');

    for (int i = 0; i < _pestCards.length; i++) {
      final card = _pestCards[i];
      try {
        final urls = await PestImageSearchService.searchPestImages(
            pestName: card.name, stage: _resolvedStage, maxResults: 2);
        debugPrint('[PestResultsPage] 🅱️ Card ${i + 1}/${_pestCards.length} '
            '"${card.name}" → ${urls.length} thumbnail images.');
        if (mounted) {
          setState(() {
            _pestCards[i] = _PestCard(
                name: card.name, imageUrls: urls, imagesLoaded: true);
          });
        }
      } catch (e) {
        debugPrint('[PestResultsPage] ⚠️ Card ${i + 1}/${_pestCards.length} '
            '"${card.name}" thumbnail failed: $e');
        if (mounted) {
          setState(() {
            _pestCards[i] = _PestCard(
                name: card.name, imageUrls: [], imagesLoaded: true);
          });
        }
      }
    }
    debugPrint('[PestResultsPage] 🅱️ All ${_pestCards.length} pest card '
        'images resolved.');
  }

  Future<void> _onSelectPestB(String pestName) async {
    debugPrint('[PestResultsPage] 🅱️ Farmer selected pest "$pestName" '
        'from grid. Loading management details.');
    setState(() {
      _selectedPestInGrid = pestName;
      _resolvedPest       = pestName;
      _pageState          = _PageState.loadingManagement;
    });
    await _loadManagementDetails(pestName, _resolvedStage);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH C — AI image scan
  // ══════════════════════════════════════════════════════════════════════════

  void _runPathC() {
    debugPrint('[PestResultsPage] 🤖 Path C (AI scan) — '
        'pest="${widget.selectedPest}" | '
        'confidence=${widget.aiConfidence?.toStringAsFixed(1)}% | '
        'hasManagementData=${widget.aiManagementData != null}');
    if (widget.aiManagementData != null) {
      _managementData = _normaliseMgmtKeys(widget.aiManagementData!);
      debugPrint('[PestResultsPage] 🤖 Path C — management data normalised '
          '(${_managementData!.keys.length} keys).');
    } else {
      debugPrint('[PestResultsPage] ⚠️ Path C — no aiManagementData provided. '
          'Management section will be empty until AI enriches it.');
    }
    setState(() => _pageState = _PageState.showingManagement);
    _fadeController.forward(from: 0);
    _cardStaggerController.forward(from: 0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED — Load management details
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadManagementDetails(String pestName, String stage) async {
    debugPrint('[PestResultsPage] 📚 Loading management details for '
        '"$pestName" | stage="$stage"');

    // ── Try local data first ───────────────────────────────────────────────
    if (kPestDetails.containsKey(pestName)) {
      final local = kPestDetails[pestName]!;
      _managementData = {
        'description':         local['description'],
        'symptoms':            local['symptoms'],
        'chemical_controls':   local['chemicalControls'],
        'biological_controls': local['biologicalControls'],
        'possible_causes':     local['possibleCauses'],
        'preventive_measures': local['preventiveMeasures'],
      };
      debugPrint('[PestResultsPage] 📚 Local data found for "$pestName" — '
          'showing immediately while AI enriches.');
    } else {
      debugPrint('[PestResultsPage] ⚠️ No local data for "$pestName" — '
          'will rely entirely on CoffeeCore AI. UI will show skeletons until enriched.');
    }

    // ── Fetch additional online images ─────────────────────────────────────
    debugPrint('[PestResultsPage] 🖼 Fetching full-resolution images '
        'for "$pestName"…');
    try {
      final urls = await PestImageSearchService.searchPestImages(
          pestName: pestName, stage: stage, maxResults: 8);
      debugPrint('[PestResultsPage] 🖼 ${urls.length} full-res images loaded '
          'for "$pestName".');
      if (mounted) setState(() => _onlinePestImages = urls);
    } catch (e) {
      debugPrint('[PestResultsPage] ⚠️ Full-res image fetch failed for '
          '"$pestName": $e — will use local assets if available.');
    }

    // ── Kick off AI enrichment in background ──────────────────────────────
    debugPrint('[PestResultsPage] 🤖 Starting CoffeeCore AI enrichment for '
        '"$pestName" in background…');
    _enrichWithAi(pestName, stage);

    if (!mounted) return;
    setState(() => _pageState = _PageState.showingManagement);
    _fadeController.forward(from: 0);
    _cardStaggerController.forward(from: 0);
    debugPrint('[PestResultsPage] 📋 Management page now visible for '
        '"$pestName". AI enrichment running in background.');
  }

  Future<void> _enrichWithAi(String pestName, String stage) async {
    debugPrint('[PestResultsPage] 🤖 _enrichWithAi called for '
        '"$pestName" | stage="$stage"');
    try {
      final aiData = await GeminiPestAiService.generateManagementDetails(
          pestName: pestName, stage: stage);

      if (aiData == null) {
        debugPrint('[PestResultsPage] ⚠️ AI returned null for "$pestName" — '
            'keeping local/existing data as fallback.');
        return;
      }

      debugPrint('[PestResultsPage] ✅ AI enrichment received for '
          '"$pestName" (${aiData.keys.length} keys). Updating UI.');
      if (mounted) {
        setState(() => _managementData = aiData);
      }
    } catch (e) {
      debugPrint('[PestResultsPage] ❌ _enrichWithAi failed for '
          '"$pestName": $e — keeping existing management data.');
    }
  }

  Map<String, dynamic> _normaliseMgmtKeys(Map<String, dynamic> raw) {
    return {
      'description':         raw['description'] ?? '',
      'symptoms':            raw['symptoms'] ?? '',
      'chemical_controls':   _toList(raw['chemical_controls'] ?? raw['chemicalControls']),
      'biological_controls': _toList(raw['biological_controls'] ?? raw['biologicalControls']),
      'possible_causes':     _toList(raw['possible_causes'] ?? raw['possibleCauses']),
      'preventive_measures': _toList(raw['preventive_measures'] ?? raw['preventiveMeasures']),
    };
  }

  List<String> _toList(dynamic val) {
    if (val == null) return [];
    if (val is List) return val.map((e) => e.toString()).toList();
    if (val is String) return [val];
    return [];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FIRESTORE SAVE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _saveDiagnosis() async {
    if (_isSaving || _savedToDb) return;
    debugPrint('[PestResultsPage] 💾 Saving diagnosis — '
        'pest="${_resolvedPest ?? "Unknown"}" | '
        'stage="$_resolvedStage" | '
        'mode=${widget.detectionMode.name} | '
        'images=${_onlinePestImages.length}');
    setState(() => _isSaving = true);
    try {
      final docId = await PestFirestoreService.saveDiagnosis(
        pestName:       _resolvedPest ?? 'Unknown',
        stage:          _resolvedStage,
        detectionMode:  widget.detectionMode.name,
        managementData: _managementData ?? {},
        imageUrls:      _onlinePestImages,
        aiConfidence:   widget.aiConfidence,
        aiReasoning:    widget.aiReasoning,
      );
      debugPrint('[PestResultsPage] ✅ Diagnosis saved successfully. '
          'Firestore ID: $docId');
      if (!mounted) return;
      setState(() { _isSaving = false; _savedToDb = true; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Diagnosis saved to your history.',
            style: GoogleFonts.poppins()),
        backgroundColor: _successGreen,
        behavior:        SnackBarBehavior.floating,
      ));
    } catch (e) {
      debugPrint('[PestResultsPage] ❌ _saveDiagnosis failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save. Check your connection.',
            style: GoogleFonts.poppins()),
        backgroundColor: Colors.redAccent,
        behavior:        SnackBarBehavior.floating,
      ));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final title = switch (_pageState) {
      _PageState.loadingImages || _PageState.loadingManagement => 'Loading…',
      _PageState.awaitingConfirmation => 'Confirm the Pest',
      _PageState.pestSelection        => 'Select the Pest You See',
      _PageState.showingManagement    => _resolvedPest ?? 'Management Details',
      _PageState.error                => 'Something went wrong',
    };

    return AppBar(
      backgroundColor: _darkBrown,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(title,
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildBody() {
    return switch (_pageState) {
      _PageState.loadingImages || _PageState.loadingManagement =>
        _buildLoader(key: const ValueKey('loader')),
      _PageState.awaitingConfirmation =>
        _buildConfirmationView(key: const ValueKey('confirm')),
      _PageState.pestSelection =>
        _buildPestSelectionView(key: const ValueKey('pestsel')),
      _PageState.showingManagement =>
        _buildManagementView(key: const ValueKey('mgmt')),
      _PageState.error =>
        _buildErrorView(key: const ValueKey('error')),
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOADER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLoader({Key? key}) {
    final subtitle = _pageState == _PageState.loadingManagement
        ? 'Generating management recommendations…'
        : 'Searching for pest images online…';

    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: _darkBrown.withValues(alpha: .08), shape: BoxShape.circle),
              child: const CircularProgressIndicator(
                  color: _darkBrown, strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text(subtitle,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: _midBrown, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH A — CONFIRMATION VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildConfirmationView({Key? key}) {
    final localImages =
        kPestDetails[_resolvedPest!]?['lifecycleImages'] as List<dynamic>? ?? [];

    return FadeTransition(
      key: key,
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildContextRow(),
            const SizedBox(height: 20),
            _buildSectionHeader(
              icon: Icons.image_search_rounded,
              title: 'Online Pest Images',
              subtitle: 'Images of ${_resolvedPest!} at the $_resolvedStage stage',
            ),
            const SizedBox(height: 12),
            if (_onlinePestImages.isNotEmpty)
              _buildOnlineImageCarousel(_onlinePestImages)
            else if (localImages.isNotEmpty)
              _buildLocalImageCarousel(List<String>.from(localImages))
            else
              _buildNoImagesAvailable(),
            const SizedBox(height: 24),
            _buildConfirmationCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationCard() {
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
          Row(children: [
            const Icon(Icons.help_outline_rounded, color: _darkBrown, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Is this the pest you are seeing on your crop?',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _darkBrown)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Compare the images above with what you see in your field. '
            'Confirm only if you recognise the damage patterns.',
            style: GoogleFonts.poppins(fontSize: 12.5, color: _midBrown, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  debugPrint('[PestResultsPage] ❌ Farmer said NOT this pest '
                      '("${_resolvedPest!}"). Navigating back.');
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _midBrown,
                  side: const BorderSide(color: Color(0xFFD7C5BC)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: Text('Not This Pest',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _onConfirmPestA,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkBrown, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4, shadowColor: _darkBrown.withValues(alpha: .4),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text('Yes, Show Management',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH B — PEST SELECTION VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPestSelectionView({Key? key}) {
    return FadeTransition(
      key: key,
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildContextRow(),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_darkBrown, _midBrown],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.touch_app_rounded, color: _amber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap the pest card that best matches what you see on your crop to get management details.',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader(
              icon: Icons.bug_report_rounded,
              title: 'Possible Pests at This Stage',
              subtitle: '${_pestCards.length} pests known to attack coffee during $_resolvedStage',
            ),
            const SizedBox(height: 14),
            ...List.generate(_pestCards.length,
                (i) => _buildPestCard(_pestCards[i], i)),
          ],
        ),
      ),
    );
  }

  Widget _buildPestCard(_PestCard card, int index) {
    final delay      = (index * 60).clamp(0, 400);
    final isSelected = _selectedPestInGrid == card.name;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOut,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child),
      ),
      child: GestureDetector(
        onTap: () => _onSelectPestB(card.name),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? _darkBrown : const Color(0xFFD7C5BC),
                width: isSelected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? _darkBrown.withValues(alpha: .2)
                    : Colors.black.withValues(alpha: .06),
                blurRadius: isSelected ? 14 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15)),
                child: SizedBox(
                  width: 110, height: 90,
                  child: card.imagesLoaded
                      ? (card.imageUrls.isNotEmpty
                          ? _netImage(url: card.imageUrls.first)
                          : _imageFallback())
                      : _imagePlaceholder(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name,
                          style: GoogleFonts.poppins(
                              fontSize: 13.5, fontWeight: FontWeight.w700,
                              color: _darkBrown, height: 1.2)),
                      const SizedBox(height: 5),
                      Text(kPestDetails[card.name]?['symptoms'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 11.5, color: _midBrown, height: 1.4)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.arrow_forward_rounded,
                            size: 14,
                            color: isSelected ? _darkBrown : _lightBrown),
                        const SizedBox(width: 4),
                        Text(
                          isSelected ? 'Loading details…' : 'Tap for management',
                          style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: isSelected ? _darkBrown : _lightBrown,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MANAGEMENT VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildManagementView({Key? key}) {
    return FadeTransition(
      key: key,
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildContextRow(),
            if (widget.detectionMode == PestDetectionMode.aiScan &&
                widget.aiConfidence != null) ...[
              const SizedBox(height: 10),
              _buildAiConfidenceBanner(),
            ],
            const SizedBox(height: 20),
            _buildImageSection(),
            const SizedBox(height: 22),
            _buildSectionHeader(
              icon: Icons.medical_services_rounded,
              title: 'Pest Management Details',
              subtitle: 'AI-enhanced recommendations for ${_resolvedPest ?? "identified pest"}',
            ),
            const SizedBox(height: 14),
            if (_managementData != null) ...[
              _buildMgmtCard(
                  index: 0, icon: Icons.info_outline_rounded,
                  title: 'Description',
                  content: _managementData!['description']?.toString() ?? '',
                  accentColor: const Color(0xFF5D4037)),
              _buildMgmtCard(
                  index: 1, icon: Icons.warning_amber_rounded,
                  title: 'Symptoms',
                  content: _managementData!['symptoms']?.toString() ?? '',
                  accentColor: const Color(0xFFE65100)),
              _buildListMgmtCard(
                  index: 2, icon: Icons.science_rounded,
                  title: 'Chemical Controls',
                  items: _toList(_managementData!['chemical_controls']),
                  accentColor: const Color(0xFF1565C0)),
              _buildListMgmtCard(
                  index: 3, icon: Icons.eco_rounded,
                  title: 'Biological Controls',
                  items: _toList(_managementData!['biological_controls']),
                  accentColor: _successGreen),
              _buildListMgmtCard(
                  index: 4, icon: Icons.search_rounded,
                  title: 'Possible Causes',
                  items: _toList(_managementData!['possible_causes']),
                  accentColor: const Color(0xFF6A1B9A)),
              _buildListMgmtCard(
                  index: 5, icon: Icons.shield_rounded,
                  title: 'Preventive Measures',
                  items: _toList(_managementData!['preventive_measures']),
                  accentColor: const Color(0xFF00695C)),
            ] else
              _buildMgmtSkeletons(),
            const SizedBox(height: 24),
            _buildActionRow(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CoffeeCore AI confidence banner
  // Label updated: "Gemini AI Identification" → "CoffeeCore AI Identification"
  // The underlying model (Gemini via Firebase AI) is unchanged — only the
  // brand label shown to the user has been updated.
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAiConfidenceBanner() {
    final confidence = widget.aiConfidence!;
    final Color barColor = confidence >= 80
        ? _successGreen
        : confidence >= 60
            ? const Color(0xFFF57F17)
            : Colors.redAccent;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7C5BC)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: _amber, size: 16),
            const SizedBox(width: 6),
            Text('CoffeeCore AI Identification',
                style: GoogleFonts.poppins(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: _darkBrown)),
            const Spacer(),
            Text('${confidence.toStringAsFixed(0)}% confidence',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: barColor)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence / 100,
              minHeight: 5,
              color: barColor,
              backgroundColor: barColor.withValues(alpha: .15),
            ),
          ),
          if (widget.aiReasoning != null) ...[
            const SizedBox(height: 8),
            Text(widget.aiReasoning!,
                style: GoogleFonts.poppins(
                    fontSize: 11.5, color: _midBrown, height: 1.45)),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image section
  // Web-safe: uses Image.memory (from scannedImageBytes) on web,
  //           uses Image.file  (from scannedImageFile)  on mobile.
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildImageSection() {
    // Check whether a scanned image is available on the current platform.
    final bool hasScannedImage = widget.detectionMode == PestDetectionMode.aiScan &&
        (widget.scannedImageBytes != null || widget.scannedImageFile != null);

    if (hasScannedImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.camera_alt_rounded,
            title: 'Your Scanned Photo',
            subtitle: 'The image used for CoffeeCore AI analysis',
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                color: const Color(0xFFF5EDE8),
                // ── Platform-aware image display ────────────────────────────
                // Web:    Image.file is not supported → use Image.memory.
                // Mobile: Prefer Image.file for efficiency; fall back to
                //         Image.memory if only bytes are available.
                child: kIsWeb
                    ? Image.memory(
                        widget.scannedImageBytes!,
                        fit: BoxFit.contain,
                      )
                    : (widget.scannedImageFile != null
                        ? Image.file(
                            widget.scannedImageFile!,
                            fit: BoxFit.contain,
                          )
                        : Image.memory(
                            widget.scannedImageBytes!,
                            fit: BoxFit.contain,
                          )),
              ),
            ),
          ),
          if (_onlinePestImages.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionHeader(
              icon: Icons.image_search_rounded,
              title: 'Reference Pest Images',
              subtitle: 'Compare with your photo above',
            ),
            const SizedBox(height: 12),
            _buildOnlineImageCarousel(_onlinePestImages),
          ],
        ],
      );
    }

    // ── Non-AI paths (Path A manual, Path B stage-guided) ───────────────────
    final localImages =
        kPestDetails[_resolvedPest]?['lifecycleImages'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.image_search_rounded,
          title: 'Pest Reference Images',
          subtitle: _resolvedPest != null
              ? 'Verified images of ${_resolvedPest!}'
              : 'Reference images',
        ),
        const SizedBox(height: 12),
        if (_onlinePestImages.isNotEmpty)
          _buildOnlineImageCarousel(_onlinePestImages)
        else if (localImages.isNotEmpty)
          _buildLocalImageCarousel(List<String>.from(localImages))
        else
          _buildNoImagesAvailable(),
      ],
    );
  }

  Widget _buildNoImagesAvailable() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7C5BC)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_search_rounded,
            color: _lightBrown.withValues(alpha: .55),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'No Reference Images Available',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _midBrown,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Reference photos for this pest could not be loaded.\n'
            'Use the description and symptom details below to identify it.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _lightBrown,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineImageCarousel(List<String> urls) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                PageView.builder(
                  controller:    _carouselController,
                  itemCount:     urls.length,
                  onPageChanged: (i) =>
                      setState(() => _currentCarouselPage = i),
                  itemBuilder: (_, i) => Container(
                    color: const Color(0xFFF5EDE8),
                    child: Image.network(
                      urls[i],
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : _imagePlaceholder(),
                      errorBuilder: (_, error, __) {
                        debugPrint('[PestResultsPage] ⚠️ Image failed: '
                            '${urls[i].substring(0, urls[i].length.clamp(0, 80))} — $error');
                        return _imageFallback();
                      },
                    ),
                  ),
                ),
                if (urls.length > 1)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _darkBrown.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentCarouselPage + 1} / ${urls.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              urls.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width:  _currentCarouselPage == i ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentCarouselPage == i
                      ? _darkBrown
                      : _lightBrown.withValues(alpha: .4),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocalImageCarousel(List<String> assets) {
    if (assets.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount:       assets.length,
        itemBuilder:     (_, i) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                color: const Color(0xFFF5EDE8),
                child: Image.asset(
                  assets[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _imageFallback(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Management cards ───────────────────────────────────────────────────────

  Widget _buildMgmtCard({
    required int index, required IconData icon,
    required String title, required String content,
    required Color accentColor,
  }) {
    if (content.isEmpty) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 70),
      curve: Curves.easeOut,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(offset: Offset(0, 16 * (1 - val)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDE0D4)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: .09),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w700,
                        color: accentColor)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(content,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: _midBrown, height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListMgmtCard({
    required int index, required IconData icon,
    required String title, required List<String> items,
    required Color accentColor,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 70),
      curve: Curves.easeOut,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(offset: Offset(0, 16 * (1 - val)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDE0D4)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: .09),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w700,
                        color: accentColor)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                              color: accentColor, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item,
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: _midBrown, height: 1.5)),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMgmtSkeletons() {
    return Column(
      children: List.generate(4, (_) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 80,
        decoration: BoxDecoration(
            color: Colors.brown.shade50,
            borderRadius: BorderRadius.circular(16)),
      )),
    );
  }

  Widget _buildActionRow() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _savedToDb ? null : (_isSaving ? null : _saveDiagnosis),
            style: ElevatedButton.styleFrom(
              backgroundColor: _savedToDb ? _successGreen : _darkBrown,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _savedToDb ? _successGreen : Colors.grey.shade300,
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4, shadowColor: _darkBrown.withValues(alpha: .35),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(_savedToDb ? Icons.check_circle_rounded : Icons.save_rounded,
                    size: 18),
            label: Text(
              _savedToDb
                  ? 'Saved to History'
                  : (_isSaving ? 'Saving…' : 'Save Diagnosis to History'),
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              if (_resolvedPest == null) return;
              final localData = widget.localPestData ??
                  (kPestDetails.containsKey(_resolvedPest)
                      ? _buildCoffeePestData(_resolvedPest!)
                      : null);
              if (localData == null) {
                debugPrint('[PestResultsPage] ⚠️ Cannot open intervention — '
                    'no local data found for "$_resolvedPest".');
                return;
              }
              debugPrint('[PestResultsPage] 🌿 Opening intervention plan '
                  'for "$_resolvedPest".');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CoffeeInterventionPage(
                    pestData:            localData,
                    cropStage:           _resolvedStage,
                    notificationsPlugin: widget.notificationsPlugin,
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _darkBrown,
              side: const BorderSide(color: _darkBrown, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.agriculture_rounded, size: 18),
            label: Text('Start Intervention Plan',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ERROR VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildErrorView({Key? key}) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong. Please go back and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13.5, color: _midBrown, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkBrown, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Go Back',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildContextRow() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        _buildChip(Icons.layers_rounded, _resolvedStage),
        if (_resolvedPest != null) _buildChip(Icons.bug_report_rounded, _resolvedPest!),
        _buildModeChip(),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _darkBrown.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _darkBrown.withValues(alpha: .2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: _darkBrown),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: _darkBrown)),
      ]),
    );
  }

  Widget _buildModeChip() {
    final (label, color) = switch (widget.detectionMode) {
      PestDetectionMode.knownBoth  => ('Manual Selection', _midBrown),
      PestDetectionMode.knownStage => ('Stage Guided',     _lightBrown),
      PestDetectionMode.aiScan     => ('AI Scanned',       _amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.auto_awesome_rounded, size: 13, color: _midBrown),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: _darkBrown)),
      ]),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _darkBrown, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _darkBrown)),
            Text(subtitle,
                style: GoogleFonts.poppins(fontSize: 11.5, color: _lightBrown)),
          ]),
        ),
      ],
    );
  }

  Widget _netImage({required String url, BoxFit fit = BoxFit.cover}) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _imagePlaceholder(),
      errorBuilder: (_, error, __) {
        debugPrint('[PestResultsPage] ⚠️ Thumbnail failed: '
            '${url.substring(0, url.length.clamp(0, 80))}… — $error');
        return _imageFallback();
      },
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.brown.shade50,
      child: const Center(
        child: CircularProgressIndicator(color: _lightBrown, strokeWidth: 1.5),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: Colors.brown.shade50,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image_not_supported_rounded,
            color: _lightBrown.withValues(alpha: .5), size: 22),
        const SizedBox(height: 4),
        Text('No image',
            style: GoogleFonts.poppins(fontSize: 10, color: _lightBrown)),
      ]),
    );
  }

  CoffeePestData _buildCoffeePestData(String pestName) {
    final d = kPestDetails[pestName]!;
    return CoffeePestData(
      name:               pestName,
      description:        d['description'],
      symptoms:           d['symptoms'],
      chemicalControls:   List<String>.from(d['chemicalControls']),
      mechanicalControls: List<String>.from(d['mechanicalControls']),
      biologicalControls: List<String>.from(d['biologicalControls']),
      possibleCauses:     List<String>.from(d['possibleCauses']),
      preventiveMeasures: List<String>.from(d['preventiveMeasures']),
      lifecycleImages:    List<String>.from(d['lifecycleImages']),
    );
  }
}