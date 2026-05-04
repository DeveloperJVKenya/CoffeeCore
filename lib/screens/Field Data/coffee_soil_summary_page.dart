import 'dart:developer' as developer;
import 'package:coffeecore/models/coffee_soil_data.dart';
import 'package:coffeecore/screens/Field%20Data/gemini_soil_ai_service.dart';
import 'package:coffeecore/screens/Field%20Data/helpers/nutrient_analysis_helper.dart';
import 'package:coffeecore/screens/Field%20Data/soil_advisor_chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';

class CoffeeSoilSummaryPage extends StatefulWidget {
  final String userId;

  const CoffeeSoilSummaryPage({required this.userId, super.key});

  @override
  State<CoffeeSoilSummaryPage> createState() => _CoffeeSoilSummaryPageState();
}

class _CoffeeSoilSummaryPageState extends State<CoffeeSoilSummaryPage> {
  String _selectedFilter = 'All';
  bool _isPerPlant = false;
  final List<String> _filterOptions = ['All', 'With Recommendations', 'Without Recommendations'];
  static const List<String> _soilTypes = [
    'Volcanic', 'Red', 'Alluvial', 'Forest', 'Laterite'
  ];

  // ── ⑤ Trend Analyst state ────────────────────────────────────────────────
  SoilTrendResult? _trendResult;
  bool _isTrendLoading = false;
  bool _trendExpanded = true;

  // ── ⑥ Latest soil context for chat FAB ───────────────────────────────────
  Map<String, double>? _latestNutrients;
  String _latestStage = 'Establishment/Seedling';
  String? _latestSoilType;

  @override
  void initState() {
    super.initState();
    developer.log('Initializing CoffeeSoilSummaryPage for user: ${widget.userId}',
        name: 'CoffeeSoilSummaryPage');
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    _loadCachedData();
    _syncUnsyncedChanges();
    _loadTrendAnalysis(); // ⑤
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_soil_data_${widget.userId}');
      if (cachedData != null) {
        developer.log('Loaded cached soil data for user: ${widget.userId}',
            name: 'CoffeeSoilSummaryPage');
      } else {
        developer.log('No cached soil data found for user: ${widget.userId}',
            name: 'CoffeeSoilSummaryPage');
      }
    } catch (e, stackTrace) {
      developer.log('Error loading cached data: $e',
          name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
    }
  }

  // ── ⑤ Trend analysis ─────────────────────────────────────────────────────

  Future<void> _loadTrendAnalysis() async {
    try {
      // Check shared-prefs cache first (keyed by user + today's date so it
      // re-runs at most once per day, not on every screen open).
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'trend_${widget.userId}_${DateTime.now().toIso8601String().substring(0, 10)}';
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        setState(() => _trendResult = SoilTrendResult.fromJson(decoded));
        developer.log('[CoffeeSoilSummaryPage] ✅ Trend loaded from cache', name: 'CoffeeSoilSummaryPage');
        return;
      }

      setState(() => _isTrendLoading = true);

      // Fetch the last 5 readings for this user.
      final snapshot = await FirebaseFirestore.instance
          .collection('SoilData')
          .where('userId', isEqualTo: widget.userId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (snapshot.docs.length < 2) {
        developer.log('[CoffeeSoilSummaryPage] ⚠️ Not enough readings for trend (${snapshot.docs.length})',
            name: 'CoffeeSoilSummaryPage');
        setState(() => _isTrendLoading = false);
        return;
      }

      // Build reading list (oldest first for the trend prompt).
      final readings = snapshot.docs.reversed.map((doc) {
        final d = doc.data();
        final nutrients = <String, dynamic>{};
        for (final key in ['pH', 'nitrogen', 'phosphorus', 'potassium',
                           'magnesium', 'calcium', 'zinc', 'boron']) {
          final v = d[key == 'pH' ? 'ph' : key];
          if (v != null) nutrients[key] = v;
        }
        return {
          'timestamp': (d['timestamp'] as Timestamp).toDate().toIso8601String(),
          'nutrients': nutrients,
        };
      }).toList();

      // Capture latest context for ⑥ chat FAB while we have the data.
      final latestDoc = snapshot.docs.first.data();
      _latestStage  = latestDoc['stage'] as String? ?? 'Establishment/Seedling';
      _latestSoilType = latestDoc['soilType'] as String?;
      _latestNutrients = {};
      for (final key in ['pH', 'nitrogen', 'phosphorus', 'potassium',
                         'magnesium', 'calcium', 'zinc', 'boron']) {
        final v = latestDoc[key == 'pH' ? 'ph' : key];
        if (v != null) _latestNutrients![key] = (v as num).toDouble();
      }

      final result = await GeminiSoilAiService.analyzeSoilTrend(
        readings: readings,
        soilType: _latestSoilType,
        stage: _latestStage,
      );

      if (!mounted) return;
      setState(() {
        _trendResult = result;
        _isTrendLoading = false;
      });

      // Cache for today.
      if (result != null) {
        await prefs.setString(cacheKey, jsonEncode({
          'overall_direction':     result.overallDirection,
          'trend_summary':         result.trendSummary,
          'critical_alerts':       result.criticalAlerts,
          'positive_trends':       result.positiveTrends,
          'recommended_next_action': result.recommendedAction,
        }));
      }
    } catch (e, stackTrace) {
      developer.log('Error in _loadTrendAnalysis: $e',
          name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      if (mounted) setState(() => _isTrendLoading = false);
    }
  }

  // ── Connectivity ──────────────────────────────────────────────────────────

  Future<bool> _isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = !connectivityResult.contains(ConnectivityResult.none);
      developer.log('Connectivity check: isOnline=$isOnline, result=$connectivityResult',
          name: 'CoffeeSoilSummaryPage');
      return isOnline;
    } catch (e, stackTrace) {
      developer.log('Error checking connectivity: $e',
          name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _syncUnsyncedChanges() async {
    try {
      final isOnline = await _isConnected();
      if (!isOnline && mounted) {
        developer.log('Device offline, skipping sync', name: 'CoffeeSoilSummaryPage');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device offline. Changes will sync when online.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
        return;
      }

      developer.log('Starting sync of unsynced changes for user: ${widget.userId}',
          name: 'CoffeeSoilSummaryPage');
      final prefs = await SharedPreferences.getInstance();
      final unsyncedEdits = prefs.getStringList('unsynced_edits_${widget.userId}') ?? [];
      final unsyncedDeletions = prefs.getStringList('unsynced_deletions_${widget.userId}') ?? [];

      developer.log('Found ${unsyncedEdits.length} unsynced edits and '
          '${unsyncedDeletions.length} unsynced deletions', name: 'CoffeeSoilSummaryPage');

      for (final edit in unsyncedEdits) {
        final decoded = jsonDecode(edit) as Map<String, dynamic>;
        final docId = decoded['docId'] as String;
        final soilDataMap = decoded['data'] as Map<String, dynamic>;
        await FirebaseFirestore.instance
            .collection('SoilData')
            .doc(docId)
            .set(soilDataMap, SetOptions(merge: true));
        developer.log('Synced edit for doc: $docId', name: 'CoffeeSoilSummaryPage');
      }

      for (final deletion in unsyncedDeletions) {
        await FirebaseFirestore.instance
            .collection('SoilData')
            .doc(deletion)
            .update({'isDeleted': true});
        developer.log('Synced deletion for doc: $deletion', name: 'CoffeeSoilSummaryPage');
      }

      await prefs.setStringList('unsynced_edits_${widget.userId}', []);
      await prefs.setStringList('unsynced_deletions_${widget.userId}', []);

      if (mounted && (unsyncedEdits.isNotEmpty || unsyncedDeletions.isNotEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline changes synced successfully'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
      developer.log('Sync completed successfully', name: 'CoffeeSoilSummaryPage');
    } catch (e, stackTrace) {
      developer.log('Error syncing unsynced changes: $e',
          name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sync offline changes. Please try again later.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
    }
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    try {
      developer.log('Creating filtered stream for user: ${widget.userId}, '
          'filter: $_selectedFilter', name: 'CoffeeSoilSummaryPage');

      Query query = FirebaseFirestore.instance
          .collection('SoilData')
          .where('userId', isEqualTo: widget.userId)
          .where('isDeleted', isEqualTo: false);

      if (_selectedFilter == 'With Recommendations') {
        query = query.where('saveWithRecommendations', isEqualTo: true);
      } else if (_selectedFilter == 'Without Recommendations') {
        query = query.where('saveWithRecommendations', isEqualTo: false);
      }

      query = query.orderBy('timestamp', descending: true);
      return query.snapshots();
    } catch (e, stackTrace) {
      developer.log('Error creating filtered stream: $e',
          name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ⑤ TREND INSIGHT CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTrendInsightCard() {
    // Show loading shimmer
    if (_isTrendLoading) {
      return Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF5E8C7),
          ),
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3A5F0B)),
              ),
              SizedBox(width: 12),
              Text(
                'Analysing soil trends…',
                style: TextStyle(color: Color(0xFF4A2C2A), fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }

    if (_trendResult == null) return const SizedBox.shrink();

    final r = _trendResult!;
    final directionColor = r.overallDirection == 'improving'
        ? Colors.green
        : r.overallDirection == 'declining'
            ? Colors.red
            : Colors.orange;
    final directionIcon = r.overallDirection == 'improving'
        ? Icons.trending_up
        : r.overallDirection == 'declining'
            ? Icons.trending_down
            : Icons.trending_flat;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF3C2F2F).withValues(alpha: 0.06),
              const Color(0xFFF5E8C7),
            ],
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _trendExpanded,
            onExpansionChanged: (v) => setState(() => _trendExpanded = v),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF3A5F0B), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Soil Trend Insight',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A2C2A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: directionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: directionColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(directionIcon, size: 14, color: directionColor),
                      const SizedBox(width: 4),
                      Text(
                        r.overallDirection.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: directionColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.trendSummary,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF3A5F0B), height: 1.4),
                ),
              ),

              // Critical alerts
              if (r.criticalAlerts.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...r.criticalAlerts.map((alert) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF4A2C2A)),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],

              // Positive trends
              if (r.positiveTrends.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...r.positiveTrends.map((trend) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              trend,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF4A2C2A)),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],

              // Recommended next action
              if (r.recommendedAction.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A5F0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF3A5F0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: Color(0xFF3A5F0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.recommendedAction,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A2C2A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Refresh button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _trendResult = null;
                      _isTrendLoading = false;
                    });
                    _loadTrendAnalysis();
                  },
                  icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF3A5F0B)),
                  label: const Text('Refresh',
                      style: TextStyle(fontSize: 12, color: Color(0xFF3A5F0B))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ④ AI PREDICTION SECTION (shown inside each history card if saved)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAiPredictionSection(Map<String, dynamic> rawDocData) {
    final prediction = rawDocData['aiPrediction'] as Map<String, dynamic>?;
    if (prediction == null) return const SizedBox.shrink();

    final summary = prediction['summary'] as String? ?? '';
    final caveats = List<String>.from(prediction['caveats'] ?? []);
    final predictions = prediction['predictions'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF80CBC4).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00695C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_graph,
                    color: Color(0xFF00695C), size: 15),
              ),
              const SizedBox(width: 8),
              const Text(
                'Expected at Follow-up (AI)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1F1F)),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                summary,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF3A5F0B),
                    fontStyle: FontStyle.italic,
                    height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Nutrient predictions
          ...predictions.entries.map((e) {
            final nutrient = e.key;
            final data = e.value as Map<String, dynamic>? ?? {};
            final current     = (data['current']      as num?)?.toDouble();
            final expLow      = (data['expectedLow']   as num?)?.toDouble();
            final expHigh     = (data['expectedHigh']  as num?)?.toDouble();
            final confidence  = data['confidence'] as String? ?? 'medium';
            if (current == null || expLow == null || expHigh == null) {
              return const SizedBox.shrink();
            }
            final same = expLow == current && expHigh == current;
            if (same) return const SizedBox.shrink();

            final confidenceColor = confidence == 'high'
                ? Colors.green
                : confidence == 'medium'
                    ? Colors.orange
                    : Colors.grey;

            final trend = expLow > current
                ? Icons.trending_up
                : expHigh < current
                    ? Icons.trending_down
                    : Icons.trending_flat;
            final trendColor = expLow > current
                ? Colors.green
                : expHigh < current
                    ? Colors.red
                    : Colors.orange;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      nutrient.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A1F1F),
                          letterSpacing: 0.3),
                    ),
                  ),
                  Text(
                    current.toStringAsFixed(1),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 4),
                  Icon(trend, size: 14, color: trendColor),
                  const SizedBox(width: 4),
                  Text(
                    '${expLow.toStringAsFixed(1)}–${expHigh.toStringAsFixed(1)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00695C)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: confidenceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      confidence,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: confidenceColor),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Caveats
          if (caveats.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...caveats.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 11,
                          color: Color(0xFF8A7A70)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          c,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _editSoilData(
      BuildContext context, CoffeeSoilData entry, String docId) async {
    try {
      developer.log('Starting edit for document: $docId',
          name: 'CoffeeSoilSummaryPage');

      final controllers = {
        'pH': TextEditingController(text: entry.ph?.toString()),
        'nitrogen': TextEditingController(text: entry.nitrogen?.toString()),
        'phosphorus': TextEditingController(text: entry.phosphorus?.toString()),
        'potassium': TextEditingController(text: entry.potassium?.toString()),
        'magnesium': TextEditingController(text: entry.magnesium?.toString()),
        'calcium': TextEditingController(text: entry.calcium?.toString()),
        'zinc': TextEditingController(text: entry.zinc?.toString()),
        'boron': TextEditingController(text: entry.boron?.toString()),
        'plantDensity': TextEditingController(text: entry.plantDensity.toString()),
        'interventionMethod': TextEditingController(text: entry.interventionMethod),
        'interventionQuantity': TextEditingController(text: entry.interventionQuantity),
        'interventionUnit': TextEditingController(text: entry.interventionUnit),
      };
      String? selectedSoilType = entry.soilType;
      String selectedStage = entry.stage;
      DateTime? interventionFollowUpDate =
          entry.interventionFollowUpDate?.toDate();
      bool saveWithRecommendations = entry.saveWithRecommendations;

      final localContext = context;

      final result = await showDialog<bool>(
        context: localContext,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
              maxWidth: MediaQuery.of(dialogContext).size.width * 0.95,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0E4D7),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Edit Soil Data',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A2C2A)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        icon: const Icon(Icons.close, color: Color(0xFF4A2C2A)),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Soil Type
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedSoilType,
                            decoration: const InputDecoration(
                              labelText: 'Soil Type (Optional)',
                              border: OutlineInputBorder(),
                              labelStyle:
                                  TextStyle(color: Color(0xFF3A5F0B)),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Select Soil Type',
                                    style:
                                        TextStyle(color: Color(0xFF3A5F0B))),
                              ),
                              ..._soilTypes.map((soilType) =>
                                  DropdownMenuItem(
                                    value: soilType,
                                    child: Text(soilType,
                                        style: const TextStyle(
                                            color: Color(0xFF3A5F0B))),
                                  )),
                            ],
                            onChanged: (value) {
                              selectedSoilType = value;
                            },
                          ),
                        ),
                        // Growth Stage
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedStage,
                            decoration: const InputDecoration(
                              labelText: 'Growth Stage',
                              border: OutlineInputBorder(),
                              labelStyle:
                                  TextStyle(color: Color(0xFF3A5F0B)),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Establishment/Seedling',
                                  child: Text('Establishment/Seedling',
                                      style: TextStyle(
                                          color: Color(0xFF3A5F0B)))),
                              DropdownMenuItem(
                                  value: 'Vegetative Growth',
                                  child: Text('Vegetative Growth',
                                      style: TextStyle(
                                          color: Color(0xFF3A5F0B)))),
                              DropdownMenuItem(
                                  value: 'Flowering and Fruiting',
                                  child: Text('Flowering and Fruiting',
                                      style: TextStyle(
                                          color: Color(0xFF3A5F0B)))),
                              DropdownMenuItem(
                                  value: 'Maturation and Harvesting',
                                  child: Text('Maturation and Harvesting',
                                      style: TextStyle(
                                          color: Color(0xFF3A5F0B)))),
                            ],
                            onChanged: (value) {
                              if (value != null) selectedStage = value;
                            },
                          ),
                        ),
                        // Nutrient fields
                        ...[
                          'pH', 'nitrogen', 'phosphorus', 'potassium',
                          'magnesium', 'calcium', 'zinc', 'boron', 'plantDensity'
                        ].map((field) => Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: TextFormField(
                                controller: controllers[field],
                                decoration: InputDecoration(
                                  labelText: field == 'plantDensity'
                                      ? 'Plant Density (plants/acre)'
                                      : field.toUpperCase(),
                                  border: const OutlineInputBorder(),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF3A5F0B)),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            )),
                        // Intervention
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: controllers['interventionMethod'],
                            decoration: const InputDecoration(
                              labelText: 'Intervention Method (Optional)',
                              border: OutlineInputBorder(),
                              labelStyle:
                                  TextStyle(color: Color(0xFF3A5F0B)),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            maxLines: 2,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(
                                    bottom: 16, right: 8),
                                child: TextFormField(
                                  controller: controllers['interventionQuantity'],
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity',
                                    border: OutlineInputBorder(),
                                    labelStyle: TextStyle(
                                        color: Color(0xFF3A5F0B)),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: TextFormField(
                                  controller: controllers['interventionUnit'],
                                  decoration: const InputDecoration(
                                    labelText: 'Unit',
                                    border: OutlineInputBorder(),
                                    labelStyle: TextStyle(
                                        color: Color(0xFF3A5F0B)),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Follow-up date
                        StatefulBuilder(
                          builder: (ctx, setS) => ListTile(
                            title: Text(
                              interventionFollowUpDate != null
                                  ? 'Follow-up: ${DateFormat('MMM dd, yyyy').format(interventionFollowUpDate!)}'
                                  : 'Set Follow-up Date',
                              style: const TextStyle(
                                  color: Color(0xFF3A5F0B)),
                            ),
                            trailing: const Icon(Icons.calendar_today,
                                color: Color(0xFF3A5F0B)),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    interventionFollowUpDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setS(() =>
                                    interventionFollowUpDate = picked);
                              }
                            },
                          ),
                        ),
                        CheckboxListTile(
                          title: const Text('Save with recommendations',
                              style: TextStyle(
                                  color: Color(0xFF4A2C2A), fontSize: 14)),
                          value: saveWithRecommendations,
                          onChanged: (value) {
                            saveWithRecommendations = value ?? false;
                          },
                          activeColor: const Color(0xFF4A2C2A),
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0E4D7),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF4A2C2A))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A2C2A),
                            foregroundColor: Colors.white),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (result == true && localContext.mounted) {
        final isOnline = await _isConnected();

        final updatedData = entry.copyWith(
          soilType: selectedSoilType,
          stage: selectedStage,
          ph: double.tryParse(controllers['pH']!.text),
          nitrogen: double.tryParse(controllers['nitrogen']!.text),
          phosphorus: double.tryParse(controllers['phosphorus']!.text),
          potassium: double.tryParse(controllers['potassium']!.text),
          magnesium: double.tryParse(controllers['magnesium']!.text),
          calcium: double.tryParse(controllers['calcium']!.text),
          zinc: double.tryParse(controllers['zinc']!.text),
          boron: double.tryParse(controllers['boron']!.text),
          plantDensity: int.tryParse(controllers['plantDensity']!.text) ?? entry.plantDensity,
          interventionMethod: controllers['interventionMethod']!.text.isNotEmpty
              ? controllers['interventionMethod']!.text
              : null,
          interventionQuantity: controllers['interventionQuantity']!.text.isNotEmpty
              ? controllers['interventionQuantity']!.text
              : null,
          interventionUnit: controllers['interventionUnit']!.text.isNotEmpty
              ? controllers['interventionUnit']!.text
              : null,
          interventionFollowUpDate: interventionFollowUpDate != null
              ? Timestamp.fromDate(interventionFollowUpDate!)
              : null,
          saveWithRecommendations: saveWithRecommendations,
        );

        if (localContext.mounted) {
          if (isOnline) {
            await FirebaseFirestore.instance
                .collection('SoilData')
                .doc(docId)
                .set(updatedData.toMap(), SetOptions(merge: true));
            developer.log('Successfully updated soil data for doc: $docId',
                name: 'CoffeeSoilSummaryPage');

            if (localContext.mounted) {
              ScaffoldMessenger.of(localContext).showSnackBar(
                const SnackBar(
                  content: Text('Soil data updated successfully'),
                  backgroundColor: Color(0xFF4A2C2A),
                ),
              );
            }
          } else {
            final prefs = await SharedPreferences.getInstance();
            final unsyncedEdits =
                prefs.getStringList('unsynced_edits_${widget.userId}') ?? [];
            unsyncedEdits
                .add(jsonEncode({'docId': docId, 'data': updatedData.toMap()}));
            await prefs.setStringList(
                'unsynced_edits_${widget.userId}', unsyncedEdits);
            developer.log('Saved edit locally for doc: $docId',
                name: 'CoffeeSoilSummaryPage');

            if (localContext.mounted) {
              ScaffoldMessenger.of(localContext).showSnackBar(
                const SnackBar(
                  content:
                      Text('Changes saved locally, will sync when online'),
                  backgroundColor: Color(0xFF4A2C2A),
                ),
              );
            }
          }
        }

        for (final controller in controllers.values) {
          controller.dispose();
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error editing soil data: $e',
          name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save changes. Please try again.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
    }
  }

  Future<void> _deleteSoilData(BuildContext context, String docId) async {
    try {
      developer.log('Starting delete for document: $docId',
          name: 'CoffeeSoilSummaryPage');

      final localContext = context;

      final confirm = await showDialog<bool>(
        context: localContext,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Deletion',
              style: TextStyle(color: Color(0xFF4A2C2A))),
          content: const Text(
              'Are you sure you want to delete this soil analysis entry? '
              'This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(localContext, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF4A2C2A))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(localContext, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final isOnline = await _isConnected();

      if (isOnline) {
        await FirebaseFirestore.instance
            .collection('SoilData')
            .doc(docId)
            .update({'isDeleted': true});
        developer.log('Successfully deleted doc: $docId',
            name: 'CoffeeSoilSummaryPage');

        if (localContext.mounted) {
          ScaffoldMessenger.of(localContext).showSnackBar(
            const SnackBar(
              content: Text('Soil analysis entry deleted'),
              backgroundColor: Color(0xFF4A2C2A),
            ),
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final unsyncedDeletions =
            prefs.getStringList('unsynced_deletions_${widget.userId}') ?? [];
        unsyncedDeletions.add(docId);
        await prefs.setStringList(
            'unsynced_deletions_${widget.userId}', unsyncedDeletions);
        developer.log('Saved deletion locally for doc: $docId',
            name: 'CoffeeSoilSummaryPage');

        if (localContext.mounted) {
          ScaffoldMessenger.of(localContext).showSnackBar(
            const SnackBar(
              content:
                  Text('Deletion saved locally, will sync when online'),
              backgroundColor: Color(0xFF4A2C2A),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error deleting soil data: $e',
          name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete soil data. Please try again.'),
            backgroundColor: Color(0xFF4A2C2A),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EAE0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1F1F),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3A5F0B).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.yard, color: Color(0xFF8BBF4D), size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soil History',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2),
                ),
                Text(
                  'Plot Records',
                  style: TextStyle(
                      color: Color(0xFF8BBF4D),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () {
            developer.log('Navigating back from CoffeeSoilSummaryPage',
                name: 'CoffeeSoilSummaryPage');
            Navigator.pop(context);
          },
        ),
        actions: [
          GestureDetector(
            onTap: () {
              setState(() => _isPerPlant = !_isPerPlant);
              developer.log(
                  'Toggled unit display: ${_isPerPlant ? "per plant" : "per acre"}',
                  name: 'CoffeeSoilSummaryPage');
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPerPlant ? Icons.person_outline : Icons.landscape_outlined,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isPerPlant ? 'Plant' : 'Acre',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62.0),
          child: Container(
            color: const Color(0xFF2A1F1F),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                      developer.log('Filter changed to: $filter',
                          name: 'CoffeeSoilSummaryPage');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF3A5F0B)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF3A5F0B)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        filter == 'With Recommendations'
                            ? 'With Recs'
                            : filter == 'Without Recommendations'
                                ? 'No Recs'
                                : filter,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),

      // ⑥ Soil Advisor Chat FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => SoilAdvisorChatSheet.show(
          context,
          currentNutrients:
              _latestNutrients?.isNotEmpty == true ? _latestNutrients : null,
          stage: _latestStage,
          soilType: _latestSoilType,
        ),
        backgroundColor: const Color(0xFF3A5F0B),
        icon: const Icon(Icons.eco, color: Colors.white, size: 18),
        label: const Text(
          'Soil Advisor',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13),
        ),
        tooltip: 'Soil Advisor',
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _getFilteredStream(),
        builder: (context, snapshot) {
          developer.log(
              'StreamBuilder state: ${snapshot.connectionState}',
              name: 'CoffeeSoilSummaryPage');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            developer.log('Error loading data: ${snapshot.error}',
                name: 'CoffeeSoilSummaryPage', error: snapshot.error);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error loading data',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A2C2A),
                        foregroundColor: Colors.white),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final docs = snapshot.data!.docs;
          developer.log('Retrieved ${docs.length} documents',
              name: 'CoffeeSoilSummaryPage');

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.eco, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No soil data available',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Start by adding your first soil analysis',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
            );
          }

          try {
            final entries = docs.map((doc) {
              try {
                return CoffeeSoilData.fromMap(
                    doc.data() as Map<String, dynamic>);
              } catch (e, st) {
                developer.log('Error parsing document ${doc.id}: $e',
                    name: 'CoffeeSoilSummaryPage', error: e, stackTrace: st);
                rethrow;
              }
            }).toList();

            developer.log('Successfully parsed ${entries.length} entries',
                name: 'CoffeeSoilSummaryPage');

            // ⑤ Trend card occupies index 0; real entries start at index 1.
            final showTrend = _isTrendLoading || _trendResult != null;
            final itemCount = entries.length + (showTrend ? 1 : 0);
            final offset = showTrend ? 1 : 0;

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                // Trend insight card is the first item
                if (showTrend && index == 0) {
                  return _buildTrendInsightCard();
                }

                final entryIndex = index - offset;
                try {
                  final rawData = docs[entryIndex].data() as Map<String, dynamic>;
                  return _buildEnhancedSoilCard(
                      entries[entryIndex], docs[entryIndex].id, rawData);
                } catch (e, st) {
                  developer.log('Error building card for index $entryIndex: $e',
                      name: 'CoffeeSoilSummaryPage', error: e, stackTrace: st);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.error, color: Colors.red),
                      title: const Text('Error loading this entry'),
                      subtitle: Text('Error: $e'),
                    ),
                  );
                }
              },
            );
          } catch (e, st) {
            developer.log('Error parsing documents: $e',
                name: 'CoffeeSoilSummaryPage', error: e, stackTrace: st);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error parsing data',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Error: $e',
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOIL HISTORY CARD  (now also renders the ④ AI prediction section)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEnhancedSoilCard(
      CoffeeSoilData entry, String docId, Map<String, dynamic> rawData) {
    try {
      final hasRecommendations =
          entry.recommendations != null && entry.recommendations!.isNotEmpty;
      final hasPrediction = rawData.containsKey('aiPrediction') &&
          rawData['aiPrediction'] != null;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3C2F2F).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Plot ID Header Banner ────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF2A3D1A), Color(0xFF3A5F0B)],
                  ),
                ),
                child: Row(
                  children: [
                    // Plot ID pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.grid_view_rounded,
                              color: Colors.white70, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            entry.plotId,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Soil type chip
                    if (entry.soilType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A054).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.soilType!,
                          style: const TextStyle(
                              color: Color(0xFFFFD88A),
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    const Spacer(),
                    // Notification badge
                    if (entry.notificationTriggered)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active,
                            color: Color(0xFF8FE06A), size: 13),
                      ),
                    // Action menu
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editSoilData(context, entry, docId);
                        } else if (value == 'delete') {
                          _deleteSoilData(context, docId);
                        }
                      },
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white70, size: 20),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined, color: Color(0xFF3A5F0B), size: 18),
                            SizedBox(width: 10),
                            Text('Edit Entry',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF2A1F1F),
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            SizedBox(width: 10),
                            Text('Delete',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Stage + Date Row ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.stage,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2A1F1F),
                                letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.schedule_outlined,
                                  size: 12, color: Color(0xFF8A7A70)),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM dd, yyyy · HH:mm')
                                    .format(entry.timestamp.toDate()),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8A7A70),
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Feature badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasRecommendations)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF1565C0)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lightbulb_outline,
                                    size: 10, color: Color(0xFF1565C0)),
                                SizedBox(width: 4),
                                Text('RECS',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1565C0),
                                        letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        if (hasPrediction)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00695C).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF00695C)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_graph,
                                    size: 10, color: Color(0xFF00695C)),
                                SizedBox(width: 4),
                                Text('AI PRED',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF00695C),
                                        letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Quick stats strip ────────────────────────────────────────
              _buildQuickStatsStrip(entry),

              // ── Expandable Detail ────────────────────────────────────────
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  dense: true,
                  title: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A5F0B).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Full Analysis',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3A5F0B)),
                      ),
                    ],
                  ),
                  children: [
                    _buildNutrientDataSection(entry),
                    if (entry.interventionMethod != null) ...[
                      const SizedBox(height: 12),
                      _buildInterventionSection(entry),
                    ],
                    if (hasPrediction) ...[
                      const SizedBox(height: 12),
                      _buildAiPredictionSection(rawData),
                    ],
                    if (hasRecommendations) ...[
                      const SizedBox(height: 12),
                      _buildRecommendationsSection(entry.recommendations!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      developer.log('Error building enhanced soil card: $e',
          name: 'CoffeeSoilSummaryPage', error: e, stackTrace: stackTrace);
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Error displaying this entry',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Error: $e',
              style: const TextStyle(fontSize: 11)),
        ),
      );
    }
  }

  // ── Quick stats strip (pH + key nutrients at a glance) ──────────────────
  Widget _buildQuickStatsStrip(CoffeeSoilData entry) {
    final items = <Map<String, dynamic>>[];
    if (entry.ph != null) {
      items.add({
        'label': 'pH',
        'value': entry.ph!.toStringAsFixed(1),
        'status': NutrientAnalysisHelper.getNutrientStatus('ph', entry.ph!, entry.stage),
      });
    }
    if (entry.nitrogen != null) {
      items.add({
        'label': 'N',
        'value': entry.nitrogen!.toStringAsFixed(1),
        'status': NutrientAnalysisHelper.getNutrientStatus('nitrogen', entry.nitrogen!, entry.stage),
      });
    }
    if (entry.phosphorus != null) {
      items.add({
        'label': 'P',
        'value': entry.phosphorus!.toStringAsFixed(1),
        'status': NutrientAnalysisHelper.getNutrientStatus('phosphorus', entry.phosphorus!, entry.stage),
      });
    }
    if (entry.potassium != null) {
      items.add({
        'label': 'K',
        'value': entry.potassium!.toStringAsFixed(1),
        'status': NutrientAnalysisHelper.getNutrientStatus('potassium', entry.potassium!, entry.stage),
      });
    }
    if (items.isEmpty) return const SizedBox(height: 8);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EEE6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final statusColor = _getStatusColor(item['status'] as String);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item['value'] as String,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: statusColor == Colors.grey
                        ? const Color(0xFF4A2C2A)
                        : statusColor),
              ),
              const SizedBox(height: 2),
              Text(
                item['label'] as String,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A7A70),
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 3),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXISTING SECTION BUILDERS (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNutrientDataSection(CoffeeSoilData entry) {
    final nutrients = [
      {'name': 'pH', 'value': entry.ph, 'unit': ''},
      {'name': 'Nitrogen', 'value': entry.nitrogen, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Phosphorus', 'value': entry.phosphorus, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Potassium', 'value': entry.potassium, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Magnesium', 'value': entry.magnesium, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Calcium', 'value': entry.calcium, 'unit': _isPerPlant ? 'mg/plant' : 'kg/acre'},
      {'name': 'Zinc', 'value': entry.zinc, 'unit': _isPerPlant ? 'mg/plant' : 'g/acre'},
      {'name': 'Boron', 'value': entry.boron, 'unit': _isPerPlant ? 'mg/plant' : 'g/acre'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A5F0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.science_outlined,
                    color: Color(0xFF3A5F0B), size: 15),
              ),
              const SizedBox(width: 8),
              const Text(
                'Nutrient Analysis',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1F1F),
                    letterSpacing: 0.1),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A5F0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${entry.plantDensity} plants/acre',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3A5F0B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nutrient grid — IntrinsicHeight pairs so both tiles match height
          for (int i = 0; i < nutrients.length; i += 2) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildNutrientTile(nutrients[i], entry)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: i + 1 < nutrients.length
                        ? _buildNutrientTile(nutrients[i + 1], entry)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildNutrientTile(Map<String, dynamic> nutrient, CoffeeSoilData entry) {
    final value = nutrient['value'] as double?;
    if (value == null) return const SizedBox.shrink();

    final displayValue = _isPerPlant && nutrient['name'] != 'pH'
        ? NutrientAnalysisHelper.convertToPerPlant(
            nutrient['name'].toString().toLowerCase(),
            value, entry.plantDensity)
        : value;
    final status = NutrientAnalysisHelper.getNutrientStatus(
        nutrient['name'].toString().toLowerCase(), value, entry.stage);
    final statusColor = _getStatusColor(status);
    final unit = nutrient['unit'] as String;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: statusColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nutrient name + status pill on same row
          Row(
            children: [
              Expanded(
                child: Text(
                  nutrient['name'].toString(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A7A70),
                      letterSpacing: 0.4),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Value — large and coloured by status
          Text(
            displayValue.toStringAsFixed(nutrient['name'] == 'pH' ? 1 : 2),
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: statusColor == Colors.grey
                    ? const Color(0xFF2A1F1F)
                    : statusColor,
                height: 1.0),
          ),
          // Unit on its own line, small but readable
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8A7A70),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInterventionSection(CoffeeSoilData entry) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD4A0).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.build_circle_outlined,
                    color: Colors.deepOrange, size: 15),
              ),
              const SizedBox(width: 8),
              const Text(
                'Intervention Applied',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1F1F)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFieldRow('Method', entry.interventionMethod ?? 'N/A'),
          if (entry.interventionQuantity != null && entry.interventionUnit != null)
            _buildFieldRow('Quantity',
                '${entry.interventionQuantity} ${entry.interventionUnit}'),
          if (entry.interventionFollowUpDate != null)
            _buildFieldRow(
              'Follow-up',
              DateFormat('MMM dd, yyyy')
                  .format(entry.interventionFollowUpDate!.toDate()),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(
      Map<String, dynamic> recommendations) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB0C4F8).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outlined,
                    color: Color(0xFF1565C0), size: 15),
              ),
              const SizedBox(width: 8),
              const Text(
                'Saved Recommendations',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1F1F)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...recommendations.entries.map((entry) =>
              _buildRecommendationCard(
                  entry.key, entry.value as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
      String nutrient, Map<String, dynamic> recommendations) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                nutrient.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1F1F),
                    letterSpacing: 0.5),
              ),
            ],
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: recommendations.entries
                  .map((rec) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getRecommendationTypeColor(rec.key)
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getRecommendationTypeColor(rec.key)
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getRecommendationTypeTitle(rec.key),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _getRecommendationTypeColor(rec.key)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              rec.value.toString(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF3A5F0B),
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A7A70),
                    fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFF2A1F1F),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _getRecommendationTypeTitle(String type) {
    switch (type) {
      case 'natural': return '🌱 Natural';
      case 'biological': return '🦠 Biological';
      case 'artificial': return '⚗️ Artificial';
      case 'application': return '📋 Application';
      case 'maintain': return '✅ Maintain';
      case 'avoid': return '⚠️ Avoid';
      default: return type.toUpperCase();
    }
  }

  Color _getRecommendationTypeColor(String type) {
    switch (type) {
      case 'natural': return Colors.green;
      case 'biological': return Colors.blue;
      case 'artificial': return Colors.orange;
      case 'application': return Colors.purple;
      case 'maintain': return Colors.teal;
      case 'avoid': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Low': return Colors.red;
      case 'High': return Colors.orange;
      case 'Optimal': return Colors.green;
      default: return Colors.grey;
    }
  }
}