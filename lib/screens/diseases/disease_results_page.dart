import 'dart:io';
import 'dart:typed_data';
import 'package:coffeecore/screens/diseases/coffee_disease_management_page.dart';
import 'package:coffeecore/screens/diseases/coffee_disease_models.dart';
import 'package:coffeecore/screens/diseases/gemini_disease_ai_service.dart';
import 'package:coffeecore/screens/diseases/disease_firestore_service.dart';
import 'package:coffeecore/screens/diseases/disease_image_search_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
//import 'package:coffeecore/models/coffee_disease_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Detection mode
// ─────────────────────────────────────────────────────────────────────────────

enum DiseaseDetectionMode {
  knownBoth,
  knownStage,
  aiScan,
  customSearch,
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal page-state machine
// ─────────────────────────────────────────────────────────────────────────────

enum _PageState {
  loadingImages,
  awaitingConfirmation,
  diseaseSelection,
  loadingManagement,
  showingManagement,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// Disease card model for Path B grid
// ─────────────────────────────────────────────────────────────────────────────

class _DiseaseCard {
  final String name;
  final List<String> imageUrls;
  final bool imagesLoaded;

  const _DiseaseCard({
    required this.name,
    this.imageUrls = const [],
    this.imagesLoaded = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DISEASE RESULTS PAGE
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseResultsPage extends StatefulWidget {
  final String selectedStage;
  final String? selectedDisease;
  final DiseaseDetectionMode detectionMode;
  final CoffeeDiseaseData? localDiseaseData;

  final File? scannedImageFile;
  final Uint8List? scannedImageBytes;

  final Map<String, dynamic>? aiManagementData;
  final String? aiReasoning;
  final double? aiConfidence;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const DiseaseResultsPage({
    required this.selectedStage,
    required this.selectedDisease,
    required this.detectionMode,
    required this.notificationsPlugin,
    this.localDiseaseData,
    this.scannedImageFile,
    this.scannedImageBytes,
    this.aiManagementData,
    this.aiReasoning,
    this.aiConfidence,
    super.key,
  });

  @override
  State<DiseaseResultsPage> createState() => _DiseaseResultsPageState();
}

class _DiseaseResultsPageState extends State<DiseaseResultsPage>
    with TickerProviderStateMixin {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _darkBrown = Color(0xFF3E2723);
  static const Color _midBrown = Color(0xFF6D4C41);
  static const Color _lightBrown = Color(0xFFA1887F);
  static const Color _cream = Color(0xFFFFF8F2);
  static const Color _amber = Color(0xFFFFCC80);
  static const Color _successGreen = Color(0xFF388E3C);

  // ── Page state ─────────────────────────────────────────────────────────────
  _PageState _pageState = _PageState.loadingImages;
  String? _errorMessage;

  // ── Resolved data ──────────────────────────────────────────────────────────
  String? _resolvedDisease;
  String _resolvedStage = '';
  List<String> _onlineDiseaseImages = [];
  Map<String, dynamic>? _managementData;

  // ── Path B ─────────────────────────────────────────────────────────────────
  List<_DiseaseCard> _diseaseCards = [];

  // ── Save state ─────────────────────────────────────────────────────────────
  bool _isSaving = false;
  bool _savedToDb = false;

  // ── Carousel ───────────────────────────────────────────────────────────────
  final PageController _carouselController = PageController();
  int _currentCarouselPage = 0;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _cardStaggerController;

  final ScrollController _scrollController = ScrollController();

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _resolvedStage = widget.selectedStage;
    _resolvedDisease = widget.selectedDisease;

    debugPrint('[DiseaseResultsPage] 🌱 initState — '
        'mode=${widget.detectionMode.name} | '
        'disease="${widget.selectedDisease}" | '
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
    _fadeController.dispose();
    _cardStaggerController.dispose();
    _carouselController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initialiseForMode() {
    debugPrint(
        '[DiseaseResultsPage] 🔀 Routing to ${widget.detectionMode.name} path');
    switch (widget.detectionMode) {
      case DiseaseDetectionMode.knownBoth:
        _runPathA();
      case DiseaseDetectionMode.knownStage:
        _runPathB();
      case DiseaseDetectionMode.aiScan:
        _runPathC();
      case DiseaseDetectionMode.customSearch:
        _runPathCustom();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH A — Known disease + known stage
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _runPathA() async {
    debugPrint('[DiseaseResultsPage] 🅰️ Path A started — '
        'fetching images for "${_resolvedDisease!}"');
    setState(() => _pageState = _PageState.loadingImages);
    try {
      final urls = await DiseaseImageSearchService.searchDiseaseImages(
          diseaseName: _resolvedDisease!, stage: _resolvedStage);
      if (!mounted) return;
      setState(() {
        _onlineDiseaseImages = urls;
        _pageState = _PageState.awaitingConfirmation;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      debugPrint('[DiseaseResultsPage] ⚠️ Path A image fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _onlineDiseaseImages = [];
        _pageState = _PageState.awaitingConfirmation;
      });
      _fadeController.forward(from: 0);
    }
  }

  Future<void> _onConfirmDiseaseA() async {
    debugPrint(
        '[DiseaseResultsPage] ✅ Path A — farmer confirmed "${_resolvedDisease!}"');
    setState(() => _pageState = _PageState.loadingManagement);
    try {
      Map<String, dynamic>? data;

      // Priority: local data → AI
      if (widget.localDiseaseData != null) {
        data = _diseaseDataToMap(widget.localDiseaseData!);
        debugPrint(
            '[DiseaseResultsPage] ℹ️ Using local disease data for "${_resolvedDisease!}"');
      } else {
        data = await GeminiDiseaseAiService.generateManagementDetails(
          diseaseName: _resolvedDisease!,
          stage: _resolvedStage,
        );
      }

      if (!mounted) return;
      if (data == null) {
        setState(() {
          _errorMessage =
              'Could not load management details. Please check your connection.';
          _pageState = _PageState.error;
        });
        return;
      }
      setState(() {
        _managementData = data;
        _pageState = _PageState.showingManagement;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred loading management details: $e';
        _pageState = _PageState.error;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH B — Stage known, disease unknown (grid selection)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _runPathB() async {
    debugPrint(
        '[DiseaseResultsPage] 🅱️ Path B started — stage="$_resolvedStage"');
    setState(() => _pageState = _PageState.loadingImages);

    // Use local stage map first, then AI augment
    List<String> diseaseNames = List.from(kStageDiseases[_resolvedStage] ?? []);

    if (diseaseNames.isEmpty) {
      final aiNames = await GeminiDiseaseAiService.listDiseasesForStage(
          stage: _resolvedStage);
      diseaseNames = aiNames ?? [];
    }

    if (!mounted) return;

    if (diseaseNames.isEmpty) {
      setState(() {
        _errorMessage =
            'Could not load diseases for this stage. Please try again.';
        _pageState = _PageState.error;
      });
      return;
    }

    // Build card shells
    _diseaseCards = diseaseNames.map((n) => _DiseaseCard(name: n)).toList();
    setState(() => _pageState = _PageState.diseaseSelection);
    _fadeController.forward(from: 0);

    // Load images for each card concurrently (fire and forget, update as they arrive)
    for (var i = 0; i < _diseaseCards.length; i++) {
      final name = _diseaseCards[i].name;
      DiseaseImageSearchService.searchDiseaseImages(
              diseaseName: name, stage: _resolvedStage, maxResults: 3)
          .then((urls) {
        if (!mounted) return;
        setState(() {
          _diseaseCards[i] = _DiseaseCard(
            name: name,
            imageUrls: urls,
            imagesLoaded: true,
          );
        });
      });
    }
  }

  Future<void> _onSelectDiseaseB(String selectedDisease) async {
    debugPrint(
        '[DiseaseResultsPage] 🅱️ Farmer selected "$selectedDisease" from grid');

    // ── Step 1: Immediately seed images from the card's already-loaded thumbnails.
    // This gives the management carousel something to render with zero extra wait.
    final card = _diseaseCards.firstWhere(
      (c) => c.name == selectedDisease,
      orElse: () => const _DiseaseCard(name: ''),
    );
    setState(() {
      _resolvedDisease = selectedDisease;
      _onlineDiseaseImages = List<String>.from(card.imageUrls); // instant seed
      _pageState = _PageState.loadingManagement;
    });

    // ── Step 2: Fire a full-resolution background fetch (up to 8 images).
    // Once complete it reactively replaces the 3 thumbnail seeds in the carousel.
    DiseaseImageSearchService.searchDiseaseImages(
      diseaseName: selectedDisease,
      stage: _resolvedStage,
    ).then((urls) {
      if (mounted && urls.isNotEmpty) {
        setState(() => _onlineDiseaseImages = urls);
        debugPrint('[DiseaseResultsPage] 🖼️ Path B — background image fetch '
            'complete: ${urls.length} images for "$selectedDisease"');
      }
    });

    // ── Step 3: Load management data — local kDiseaseDetails first, then AI.
    // Mirrors the same priority used by Path A / _onConfirmDiseaseA.
    try {
      Map<String, dynamic>? data;

      if (kDiseaseDetails.containsKey(selectedDisease)) {
        // Fast path: use the pre-built local disease data (no network call needed)
        final d = kDiseaseDetails[selectedDisease]!;
        data = {
          'description': d['description'],
          'symptoms': d['symptoms'],
          'chemical_controls': List<String>.from(d['chemicalControls'] as List),
          'biological_controls':
              List<String>.from(d['biologicalControls'] as List),
          'cultural_controls': List<String>.from(d['culturalControls'] as List),
          'possible_causes': List<String>.from(d['possibleCauses'] as List),
          'preventive_measures':
              List<String>.from(d['preventiveMeasures'] as List),
        };
        debugPrint(
            '[DiseaseResultsPage] ℹ️ Path B — using local data for "$selectedDisease"');
      } else {
        // Slow path: ask Gemini AI (disease not in local map)
        data = await GeminiDiseaseAiService.generateManagementDetails(
          diseaseName: selectedDisease,
          stage: _resolvedStage,
        );
      }

      if (!mounted) return;
      if (data == null) {
        setState(() {
          _errorMessage =
              'Could not load management details. Please try again.';
          _pageState = _PageState.error;
        });
        return;
      }
      setState(() {
        _managementData = data;
        _pageState = _PageState.showingManagement;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _pageState = _PageState.error;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH C — AI Scan result
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _runPathC() async {
    debugPrint('[DiseaseResultsPage] 🤖 Path C (AI scan) — '
        'disease="$_resolvedDisease"');

    if (widget.aiManagementData != null) {
      // Management data came directly from the scan — load images in parallel
      setState(() {
        _managementData = widget.aiManagementData;
        _pageState = _PageState.showingManagement;
      });
      _fadeController.forward(from: 0);

      if (_resolvedDisease != null) {
        final urls = await DiseaseImageSearchService.searchDiseaseImages(
            diseaseName: _resolvedDisease!, stage: _resolvedStage);
        if (mounted) {
          setState(() => _onlineDiseaseImages = urls);
        }
      }
      return;
    }

    // Fallback: fetch management from AI
    if (_resolvedDisease != null) {
      setState(() => _pageState = _PageState.loadingManagement);
      final data = await GeminiDiseaseAiService.generateManagementDetails(
        diseaseName: _resolvedDisease!,
        stage: _resolvedStage,
      );
      if (!mounted) return;
      setState(() {
        _managementData = data;
        _pageState =
            data != null ? _PageState.showingManagement : _PageState.error;
        _errorMessage =
            data == null ? 'Could not load management details.' : null;
      });
      if (data != null) _fadeController.forward(from: 0);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATH CUSTOM — Free-text disease search
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _runPathCustom() async {
    debugPrint(
        '[DiseaseResultsPage] 🔍 Custom search — disease="$_resolvedDisease"');
    if (_resolvedDisease == null) {
      setState(() {
        _errorMessage = 'No disease name was provided for search.';
        _pageState = _PageState.error;
      });
      return;
    }

    setState(() => _pageState = _PageState.loadingImages);

    // Run image fetch and AI management in parallel
    final imagesFuture = DiseaseImageSearchService.searchDiseaseImages(
        diseaseName: _resolvedDisease!, stage: 'Custom Search');
    final managementFuture = widget.localDiseaseData != null
        ? Future<Map<String, dynamic>?>.value(null)
        : GeminiDiseaseAiService.generateManagementDetails(
            diseaseName: _resolvedDisease!,
            stage: 'General',
          );

    final results = await Future.wait([imagesFuture, managementFuture]);
    if (!mounted) return;

    final urls = results[0] as List<String>;
    final mgmt = results[1] as Map<String, dynamic>?;

    final finalMgmt = mgmt ??
        (widget.localDiseaseData != null
            ? _diseaseDataToMap(widget.localDiseaseData!)
            : null);

    if (finalMgmt == null) {
      setState(() {
        _errorMessage =
            'No management information found for "$_resolvedDisease". '
            'Please check the disease name and try again.';
        _pageState = _PageState.error;
      });
      return;
    }

    setState(() {
      _onlineDiseaseImages = urls;
      _managementData = finalMgmt;
      _pageState = _PageState.showingManagement;
    });
    _fadeController.forward(from: 0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVE TO HISTORY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _saveDiagnosis() async {
    if (_isSaving || _savedToDb || _managementData == null) return;
    setState(() => _isSaving = true);
    try {
      await DiseaseFirestoreService.saveDiagnosis(
        diseaseName: _resolvedDisease ?? 'Unknown',
        stage: _resolvedStage,
        detectionMode: widget.detectionMode.name,
        managementData: _managementData!,
        imageUrls: _onlineDiseaseImages,
        aiConfidence: widget.aiConfidence,
        aiReasoning: widget.aiReasoning,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _savedToDb = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Diagnosis saved to your history.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: _successGreen,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save diagnosis: $e',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
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
        child: _buildBodyForState(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _darkBrown,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        _resolvedDisease ?? 'Disease Analysis',
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
      ),
      actions: [
        if (_pageState == _PageState.showingManagement && !_savedToDb)
          TextButton.icon(
            onPressed: _isSaving ? null : _saveDiagnosis,
            icon:
                const Icon(Icons.bookmark_add_rounded, color: _amber, size: 18),
            label: Text('Save',
                style: GoogleFonts.poppins(color: _amber, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildBodyForState() {
    return switch (_pageState) {
      _PageState.loadingImages => _buildLoadingView(
          key: const ValueKey('loadImg'),
          message: 'Searching for disease images…'),
      _PageState.awaitingConfirmation =>
        _buildConfirmationView(key: const ValueKey('confirm')),
      _PageState.diseaseSelection =>
        _buildDiseaseSelectionView(key: const ValueKey('select')),
      _PageState.loadingManagement => _buildLoadingView(
          key: const ValueKey('loadMgmt'),
          message: 'AI is generating management details…'),
      _PageState.showingManagement =>
        _buildManagementView(key: const ValueKey('management')),
      _PageState.error => _buildErrorView(key: const ValueKey('error')),
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOADING VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLoadingView({Key? key, required String message}) {
    return Center(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _darkBrown, strokeWidth: 2.5),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.poppins(fontSize: 14, color: _midBrown),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONFIRMATION VIEW (Path A & Custom) — Show images, ask farmer to confirm
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildConfirmationView({Key? key}) {
    final localImages = widget.localDiseaseData?.lifecycleImages ?? [];

    return FadeTransition(
      key: key,
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContextRow(),
            const SizedBox(height: 20),

            // Images
            _buildSectionHeader(
              icon: Icons.image_search_rounded,
              title: 'Is this what you see?',
              subtitle: 'Images of $_resolvedDisease on coffee plants',
            ),
            const SizedBox(height: 12),
            _buildImageCarousel(
              onlineUrls: _onlineDiseaseImages,
              localPaths: List<String>.from(localImages),
            ),

            const SizedBox(height: 28),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onConfirmDiseaseA,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text('Yes, this is the disease I see',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _midBrown,
                  side: BorderSide(color: _midBrown.withValues(alpha: .5)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text('No, go back and select another',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISEASE SELECTION VIEW (Path B) — Grid of disease cards
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDiseaseSelectionView({Key? key}) {
    return FadeTransition(
      key: key,
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContextRow(),
            const SizedBox(height: 20),
            _buildSectionHeader(
              icon: Icons.grid_view_rounded,
              title: 'Which disease do you see?',
              subtitle:
                  'Diseases known to affect coffee at the $_resolvedStage stage',
            ),
            const SizedBox(height: 14),
            ..._diseaseCards.map(_buildDiseaseCard),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseCard(_DiseaseCard card) {
    return GestureDetector(
      onTap: () => _onSelectDiseaseB(card.name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7C5BC)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 90,
                height: 90,
                child: card.imagesLoaded && card.imageUrls.isNotEmpty
                    ? _netImage(url: card.imageUrls.first)
                    : card.imagesLoaded
                        ? _imageFallback()
                        : _imagePlaceholder(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _darkBrown,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to see full disease details',
                      style: GoogleFonts.poppins(
                          fontSize: 11.5, color: _lightBrown),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: _lightBrown, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MANAGEMENT VIEW — Full disease treatment plan
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildManagementView({Key? key}) {
    final data = _managementData;
    if (data == null) return _buildErrorView(key: key);

    return FadeTransition(
      key: key,
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Context chips
            _buildContextRow(),
            const SizedBox(height: 20),

            // Scanned image (AI scan mode only)
            if (widget.detectionMode == DiseaseDetectionMode.aiScan &&
                (widget.scannedImageBytes != null ||
                    widget.scannedImageFile != null))
              _buildScannedImageCard(),

            // Confidence badge (AI scan only)
            if (widget.detectionMode == DiseaseDetectionMode.aiScan &&
                widget.aiConfidence != null)
              _buildConfidenceBadge(),

            // Disease images
            if (_onlineDiseaseImages.isNotEmpty ||
                (widget.localDiseaseData?.lifecycleImages.isNotEmpty ??
                    false)) ...[
              _buildSectionHeader(
                icon: Icons.photo_library_rounded,
                title: 'Disease Images',
                subtitle: 'Visual references for $_resolvedDisease',
              ),
              const SizedBox(height: 10),
              _buildImageCarousel(
                onlineUrls: _onlineDiseaseImages,
                localPaths: widget.localDiseaseData?.lifecycleImages ?? [],
              ),
              const SizedBox(height: 22),
            ],

            // Description
            if (data['description'] != null)
              _buildInfoCard(
                icon: Icons.info_outline_rounded,
                title: 'What Is This Disease?',
                content: data['description'] as String,
                color: _darkBrown,
              ),

            // Symptoms
            if (data['symptoms'] != null)
              _buildInfoCard(
                icon: Icons.visibility_rounded,
                title: 'Visible Symptoms',
                content: data['symptoms'] as String,
                color: const Color(0xFFC62828),
              ),

            // Chemical controls
            if (data['chemical_controls'] is List &&
                (data['chemical_controls'] as List).isNotEmpty)
              _buildListCard(
                icon: Icons.science_rounded,
                title: 'Fungicide / Chemical Controls',
                items: List<String>.from(data['chemical_controls']),
                color: const Color(0xFF1565C0),
              ),

            // Biological controls
            if (data['biological_controls'] is List &&
                (data['biological_controls'] as List).isNotEmpty)
              _buildListCard(
                icon: Icons.eco_rounded,
                title: 'Biological Controls',
                items: List<String>.from(data['biological_controls']),
                color: _successGreen,
              ),

            // Cultural controls
            if (data['cultural_controls'] is List &&
                (data['cultural_controls'] as List).isNotEmpty)
              _buildListCard(
                icon: Icons.agriculture_rounded,
                title: 'Cultural Controls',
                items: List<String>.from(data['cultural_controls']),
                color: const Color(0xFF6A1B9A),
              ),

            // Possible causes
            if (data['possible_causes'] is List &&
                (data['possible_causes'] as List).isNotEmpty)
              _buildListCard(
                icon: Icons.troubleshoot_rounded,
                title: 'Possible Causes',
                items: List<String>.from(data['possible_causes']),
                color: const Color(0xFFE65100),
              ),

            // Preventive measures
            if (data['preventive_measures'] is List &&
                (data['preventive_measures'] as List).isNotEmpty)
              _buildListCard(
                icon: Icons.shield_rounded,
                title: 'Preventive Measures',
                items: List<String>.from(data['preventive_measures']),
                color: const Color(0xFF00695C),
              ),

            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedImageCard() {
    Widget imageWidget;
    if (widget.scannedImageBytes != null) {
      imageWidget = Image.memory(widget.scannedImageBytes!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageFallback());
    } else if (!kIsWeb && widget.scannedImageFile != null) {
      imageWidget = Image.file(widget.scannedImageFile!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageFallback());
    } else {
      imageWidget = _imageFallback();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.camera_alt_rounded,
          title: 'Scanned Image',
          subtitle: 'Photo submitted for AI analysis',
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child:
              SizedBox(height: 200, width: double.infinity, child: imageWidget),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildConfidenceBadge() {
    final pct = widget.aiConfidence?.toStringAsFixed(0) ?? '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _midBrown, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Confidence: $pct%',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _darkBrown)),
                if (widget.aiReasoning != null)
                  Text(widget.aiReasoning!,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: _midBrown, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel({
    required List<String> onlineUrls,
    required List<String> localPaths,
  }) {
    final combined = <Widget>[
      ...onlineUrls.map((url) => _netImage(url: url)),
      ...localPaths.map((path) => Image.asset(path,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageFallback())),
    ];

    if (combined.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.brown.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.image_not_supported_rounded,
                color: _lightBrown, size: 32),
            const SizedBox(height: 8),
            Text('No images found',
                style: GoogleFonts.poppins(fontSize: 13, color: _lightBrown)),
          ]),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _carouselController,
              itemCount: combined.length,
              onPageChanged: (i) => setState(() => _currentCarouselPage = i),
              itemBuilder: (_, i) => combined[i],
            ),
          ),
        ),
        if (combined.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                combined.length,
                (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentCarouselPage == i ? 12 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentCarouselPage == i
                            ? _darkBrown
                            : _lightBrown.withValues(alpha: .4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .2)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: .06),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _darkBrown)),
                const SizedBox(height: 6),
                Text(content,
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, color: _midBrown, height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard({
    required IconData icon,
    required String title,
    required List<String> items,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .2)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: .06),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _darkBrown)),
            ),
          ]),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, color: _midBrown, height: 1.5)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isSaving || _savedToDb) ? null : _saveDiagnosis,
            style: ElevatedButton.styleFrom(
              backgroundColor: _savedToDb ? _successGreen : _darkBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              disabledBackgroundColor:
                  _savedToDb ? _successGreen : _darkBrown.withValues(alpha: .5),
              disabledForegroundColor: Colors.white,
            ),
            icon: Icon(
              _savedToDb ? Icons.check_circle_rounded : Icons.save_alt_rounded,
              size: 20,
            ),
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
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _darkBrown,
              side: const BorderSide(color: _darkBrown, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text('Back to Disease Centre',
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
              _errorMessage ??
                  'Something went wrong. Please go back and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13.5, color: _midBrown, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkBrown,
                foregroundColor: Colors.white,
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
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip(Icons.layers_rounded, _resolvedStage),
        if (_resolvedDisease != null)
          _buildChip(Icons.coronavirus_rounded, _resolvedDisease!),
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
      DiseaseDetectionMode.knownBoth => ('Manual Selection', _midBrown),
      DiseaseDetectionMode.knownStage => ('Stage Guided', _lightBrown),
      DiseaseDetectionMode.aiScan => ('AI Scanned', _amber),
      DiseaseDetectionMode.customSearch => (
          'Custom Search',
          const Color(0xFF6A1B9A)
        ),
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
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _darkBrown, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _darkBrown)),
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
      errorBuilder: (_, __, ___) => _imageFallback(),
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

  // ── Convert CoffeeDiseaseData to map for display ──────────────────────────

  Map<String, dynamic> _diseaseDataToMap(CoffeeDiseaseData d) => {
        'description': d.description,
        'symptoms': d.symptoms,
        'chemical_controls': d.chemicalControls,
        'biological_controls': d.biologicalControls,
        'cultural_controls': d.culturalControls,
        'possible_causes': d.possibleCauses,
        'preventive_measures': d.preventiveMeasures,
      };
}
