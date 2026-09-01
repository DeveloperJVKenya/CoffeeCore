import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/farmer_produce.dart';
import 'package:coffeecore/screens/Farm%20Management/services/pdf_download_helper.dart';
import 'package:coffeecore/services/produce_qr_service.dart';
import 'package:coffeecore/services/qr_tag_pdf_service.dart';
import 'package:coffeecore/utils/cooperative_name.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Single continuous "receive a farmer's coffee" flow: pick the farmer,
/// weigh it in and pick the variety, review, then confirm — which writes
/// the submission AND generates its QR bag tag in the same step. This
/// replaces the old two-step UX (a small "Add Produce Submission" dialog,
/// with tag printing buried as a separate icon in a table elsewhere) —
/// there is no longer a way to record produce that doesn't end at a tag.
class ReceiveProduceScreen extends StatefulWidget {
  final String cooperativeName;

  const ReceiveProduceScreen({super.key, required this.cooperativeName});

  @override
  State<ReceiveProduceScreen> createState() => _ReceiveProduceScreenState();
}

class _ReceiveProduceScreenState extends State<ReceiveProduceScreen> {
  static final Color coffeeBrown = Colors.brown[700]!;
  static const List<String> _stepTitles = [
    'Farmer',
    'Variety & Weight',
    'Review',
    'Tag Ready',
  ];

  final Logger logger = Logger(printer: PrettyPrinter());
  final PageController _pageController = PageController();
  final TextEditingController _weightCtrl = TextEditingController();
  late final String _coopId = sanitizeCoopId(widget.cooperativeName);

  int _step = 0;
  bool _loadingOptions = true;
  bool _isSubmitting = false;
  String? _errorText;

  List<Map<String, String>> _userDetails = [];
  List<Map<String, dynamic>> _varietyPrices = [];
  String? _selectedUserId;
  String? _selectedVariety;

  FarmerProduce? _savedSubmission;
  Uint8List? _tagBytes;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('${_coopId}_users').get(),
        FirebaseFirestore.instance.collection('${_coopId}_coffeeprices').get(),
      ]);
      _userDetails = results[0].docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fullName': data['fullName']?.toString() ?? 'Unknown',
          'phoneNumber': data['phoneNumber']?.toString() ?? 'N/A',
        };
      }).toList();
      _varietyPrices = results[1]
          .docs
          .map((doc) => {
                'variety': doc.id,
                'price': (doc.data()['price'] as num?)?.toDouble() ?? 0.0,
              })
          .toList();
    } catch (e, stackTrace) {
      logger.e('Error loading receive-produce options: $e\n$stackTrace');
    }
    if (mounted) setState(() => _loadingOptions = false);
  }

  double get _weight => double.tryParse(_weightCtrl.text) ?? 0;

  double get _pricePerKg {
    final match =
        _varietyPrices.where((v) => v['variety'] == _selectedVariety).toList();
    return match.isEmpty ? 0 : match.first['price'] as double;
  }

  double get _grossValue => _weight * _pricePerKg;

  String get _farmerName =>
      _userDetails.firstWhere((u) => u['id'] == _selectedUserId,
          orElse: () => const {'fullName': 'Unknown'})['fullName']!;

  String get _farmerContact =>
      _userDetails.firstWhere((u) => u['id'] == _selectedUserId,
          orElse: () => const {'phoneNumber': 'N/A'})['phoneNumber']!;

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic);
  }

  /// Selecting a farmer is a single, unambiguous action — there's nothing
  /// else to fill in on this step — so it auto-advances rather than making
  /// the manager scroll down and tap a separate "Next". The brief delay
  /// lets the tile's selected/checkmark state register before the page
  /// transitions, so the tap itself still reads as visual confirmation of
  /// who got picked (reinforced afterwards by the persistent farmer tag on
  /// every later step). Re-checking [_selectedUserId] after the delay
  /// guards against a fast second tap on a different tile winning the
  /// race and then getting overridden by the first tap's stale advance.
  Future<void> _selectFarmer(String userId) async {
    setState(() => _selectedUserId = userId);
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted || _selectedUserId != userId) return;
    _goToStep(1);
  }

  Future<void> _confirmAndGenerate() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final submissionsRef = FirebaseFirestore.instance
          .collection('${_coopId}_FarmerProduce')
          .doc(_selectedUserId)
          .collection('submissions');
      final produceData = FarmerProduce(
        id: _selectedUserId!,
        farmerName: _farmerName,
        contact: _farmerContact,
        totalAmount: _weight,
        timestamp: Timestamp.now(),
        submissionDate: dateString,
        submissionId: submissionsRef.doc().id,
        variety: _selectedVariety!,
        pricePerKg: _pricePerKg,
        grossValue: _grossValue,
      );

      await submissionsRef
          .doc(produceData.submissionId)
          .set(produceData.toMap());
      logger.i('Recorded submission ${produceData.submissionId} for '
          '$_selectedUserId in $_coopId');

      await _logActivity(
          'Received produce ${_weight}kg ($_selectedVariety) for user '
          '$_selectedUserId in cooperative ${widget.cooperativeName}');

      final tagBytes = await QrTagPdfService.buildTag(
        cooperativeName: widget.cooperativeName,
        farmerName: _farmerName,
        submissionDate: dateString,
        kg: _weight,
        variety: _selectedVariety!,
        coopId: _coopId,
        userId: _selectedUserId!,
        submissionId: produceData.submissionId,
      );

      if (!mounted) return;
      setState(() {
        _savedSubmission = produceData;
        _tagBytes = tagBytes;
        _isSubmitting = false;
      });
      _goToStep(3);
    } catch (e, stackTrace) {
      logger.e('Error recording produce/generating tag: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = 'Failed to save: $e';
      });
    }
  }

  Future<void> _logActivity(String action) async {
    try {
      await FirebaseFirestore.instance
          .collection('cooperatives')
          .doc(_coopId)
          .collection('logs')
          .add({
        'action': action,
        'timestamp': Timestamp.now(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'role': 'market_manager',
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  Future<void> _downloadTag() async {
    if (_tagBytes == null || _savedSubmission == null) return;
    try {
      final fileName = QrTagPdfService.fileName(
        cooperativeName: widget.cooperativeName,
        farmerName: _savedSubmission!.farmerName,
        submissionDate: _savedSubmission!.submissionDate,
        submissionId: _savedSubmission!.submissionId,
      );
      final file = await PdfDownloadHelper.saveBytes(_tagBytes!, fileName);
      if (!mounted) return;
      if (file != null) {
        await PdfDownloadHelper.share(file,
            text: 'Produce tag for ${_savedSubmission!.farmerName}');
      }
    } catch (e, stackTrace) {
      logger.e('Error sharing tag: $e\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to share tag: $e')));
    }
  }

  void _receiveAnother() {
    setState(() {
      _selectedUserId = null;
      _selectedVariety = null;
      _weightCtrl.clear();
      _savedSubmission = null;
      _tagBytes = null;
      _errorText = null;
    });
    _goToStep(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: const Text('Receive Produce',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: coffeeBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        // Steps back up through the wizard instead of leaving the screen,
        // so a manager can always correct an earlier step (wrong variety,
        // wrong farmer) with the familiar back-arrow gesture rather than
        // hunting for a step-specific "Back" button lower on the page.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: _step == 0 || _step == 3 ? 'Close' : 'Back',
          onPressed: _isSubmitting
              ? null
              // Step 3 (Tag Ready) already wrote the submission — stepping
              // "back" to Review there would let Confirm be tapped again
              // and create a duplicate. Close instead, same as step 0.
              : () => _step == 0 || _step == 3
                  ? Navigator.of(context).pop()
                  : _goToStep(_step - 1),
        ),
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _step = i),
                    children: [
                      _buildFarmerStep(),
                      _buildVarietyWeightStep(),
                      _buildReviewStep(),
                      _buildTagReadyStep(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _loadingOptions ? null : _buildStepFab(),
    );
  }

  // Below this viewport height, the Review step's content (card + tag +
  // error text) plus an inline button risks needing a scroll to reach the
  // action — so on short screens that action floats instead, exactly like
  // the variety/weight step's "Next" always does. Above it, the screen has
  // enough room that a fixed floating button would just be visual clutter
  // hovering over otherwise-empty space, so it sits inline, sized to its
  // own label instead of stretching edge to edge.
  static const double _compactHeightBreakpoint = 700;

  bool get _isCompactHeight =>
      MediaQuery.of(context).size.height < _compactHeightBreakpoint;

  /// Farmer selection now auto-advances (see [_selectFarmer]), so the
  /// variety/weight step's "Next" is the one step-progression FAB that's
  /// always floating — that step's value preview card can push content low
  /// enough to need a scroll either way. The review step's "Confirm &
  /// Generate Tag" only floats when the screen is short enough to need it
  /// (see [_isCompactHeight]); otherwise it renders inline via
  /// [_buildReviewStep] so it isn't hovering unnecessarily over a screen
  /// that already has room for it. An extended FAB sizes itself to its
  /// icon+label rather than stretching edge to edge.
  Widget? _buildStepFab() {
    if (_step == 1) {
      final enabled = _selectedVariety != null && _weight > 0;
      return FloatingActionButton.extended(
        key: const ValueKey('receive-produce-next-fab'),
        onPressed: enabled ? () => _goToStep(2) : null,
        backgroundColor: enabled ? coffeeBrown : Colors.brown[200],
        icon: const Icon(Icons.arrow_forward, color: Colors.white),
        label: const Text('Next',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      );
    }
    if (_step == 2 && _isCompactHeight) {
      return FloatingActionButton.extended(
        key: const ValueKey('receive-produce-confirm-fab'),
        onPressed: _isSubmitting ? null : _confirmAndGenerate,
        backgroundColor: coffeeBrown,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline, color: Colors.white),
        label: const Text('Confirm & Generate Tag',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      );
    }
    return null;
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: List.generate(_stepTitles.length * 2 - 1, (i) {
          if (i.isOdd) {
            final leftDone = _step > (i - 1) ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: leftDone ? coffeeBrown : Colors.brown[100],
              ),
            );
          }
          final index = i ~/ 2;
          final isActive = index == _step;
          final isDone = index < _step;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isActive ? 30 : 24,
                height: isActive ? 30 : 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone || isActive ? coffeeBrown : Colors.brown[100],
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                              color: coffeeBrown.withValues(alpha: .4),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text('${index + 1}',
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.brown[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _stepScaffold({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? footer,
    Widget? headerTag,
    double extraBottomPadding = 0,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + extraBottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[600])),
          if (headerTag != null) ...[
            const SizedBox(height: 14),
            headerTag,
          ],
          const SizedBox(height: 24),
          child,
          if (footer != null) ...[const SizedBox(height: 28), footer],
        ],
      ),
    );
  }

  /// Persistent "who this delivery is for" indicator shown on every step
  /// after farmer selection, so a manager mid-way through weighing or
  /// reviewing a delivery always has the selected farmer's name in view —
  /// not just at the moment they tapped the tile. Tapping it jumps straight
  /// back to farmer selection to fix a wrong pick, without losing the
  /// variety/weight already entered (those fields are untouched by
  /// re-selecting a different farmer).
  Widget _buildSelectedFarmerTag() {
    return Tooltip(
      message: 'Change farmer',
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _goToStep(0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            color: coffeeBrown.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: coffeeBrown.withValues(alpha: .3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: coffeeBrown,
                foregroundColor: Colors.white,
                child: Text(
                  _farmerName.isNotEmpty ? _farmerName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(_farmerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              Icon(Icons.swap_horiz, size: 18, color: coffeeBrown),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmerStep() {
    return _stepScaffold(
      title: 'Who delivered coffee today?',
      subtitle: 'Tap a farmer to continue — selecting moves you on '
          'automatically.',
      child: _userDetails.isEmpty
          ? Text('No registered farmers found for ${widget.cooperativeName}.',
              style: TextStyle(color: Colors.grey[600]))
          : Column(
              children: _userDetails.map((u) {
                final selected = u['id'] == _selectedUserId;
                return _SelectableTile(
                  title: u['fullName']!,
                  subtitle: u['phoneNumber']!,
                  selected: selected,
                  onTap: () => _selectFarmer(u['id']!),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildVarietyWeightStep() {
    return _stepScaffold(
      title: 'Variety & weight',
      subtitle: 'Pick the coffee variety and weigh in the delivery.',
      headerTag: _buildSelectedFarmerTag(),
      extraBottomPadding: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_varietyPrices.isEmpty)
            Text(
              'No coffee variety prices set yet — add one from the '
              'dashboard before receiving produce.',
              style: TextStyle(color: Colors.red[700]),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _varietyPrices.map((v) {
                final selected = v['variety'] == _selectedVariety;
                return ChoiceChip(
                  label: Text('${v['variety']} · Ksh ${v['price']}/kg'),
                  selected: selected,
                  selectedColor: coffeeBrown,
                  labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.brown[800],
                      fontWeight: FontWeight.w600),
                  onSelected: (_) =>
                      setState(() => _selectedVariety = v['variety'] as String),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Weight (kg)',
              suffixText: 'kg',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_selectedVariety != null && _weight > 0) ...[
            const SizedBox(height: 16),
            _ValuePreviewCard(
                weight: _weight, pricePerKg: _pricePerKg, gross: _grossValue),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final compact = _isCompactHeight;
    return _stepScaffold(
      title: 'Review before generating the tag',
      subtitle: 'Confirm the details — this becomes the printed bag tag.',
      headerTag: _buildSelectedFarmerTag(),
      // Reserve clearance for the floating Confirm button on short screens
      // — same reasoning as the variety/weight step's extra padding.
      extraBottomPadding: compact ? 90 : 0,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reviewRow('Farmer', _farmerName),
              _reviewRow('Contact', _farmerContact),
              _reviewRow('Variety', _selectedVariety ?? '-'),
              _reviewRow('Weight', '${_weight.toStringAsFixed(1)} kg'),
              _reviewRow('Price/kg', 'Ksh ${_pricePerKg.toStringAsFixed(2)}'),
              const Divider(height: 28),
              _reviewRow('Gross Value', 'Ksh ${_grossValue.toStringAsFixed(2)}',
                  emphasize: true),
            ],
          ),
        ),
      ),
      footer: Column(
        children: [
          if (_errorText != null) ...[
            Text(_errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          // On a short screen the floating variant in _buildStepFab takes
          // over instead — showing both here would be redundant.
          if (!compact)
            Center(
              child: _PrimaryButton(
                label: 'Confirm & Generate Tag',
                icon: Icons.check_circle_outline,
                loading: _isSubmitting,
                onPressed: _isSubmitting ? null : _confirmAndGenerate,
                fullWidth: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: emphasize ? 18 : 14,
                  color: emphasize ? coffeeBrown : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTagReadyStep() {
    if (_savedSubmission == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final qrData = ProduceQrService.encode(
      coopId: _coopId,
      userId: _savedSubmission!.id,
      submissionId: _savedSubmission!.submissionId,
    );
    return _stepScaffold(
      title: 'Tag ready',
      subtitle:
          'Print and attach this tag to ${_savedSubmission!.farmerName}\'s bag.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.brown[100]!),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: QrImageView(data: qrData, size: 190),
            ),
          ),
          const SizedBox(height: 16),
          Text(_savedSubmission!.submissionId,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.grey[600])),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('${_savedSubmission!.farmerName} · ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${_savedSubmission!.totalAmount.toStringAsFixed(1)} kg · '
                  '${_savedSubmission!.variety}'),
            ],
          ),
        ],
      ),
      footer: Column(
        children: [
          _PrimaryButton(
            label: 'Download / Share Tag',
            icon: Icons.share,
            onPressed: _downloadTag,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                    label: 'Receive Another', onPressed: _receiveAnother),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SecondaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coffeeBrown = Colors.brown[700]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? coffeeBrown.withValues(alpha: .08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? coffeeBrown : Colors.brown[100]!,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: selected ? coffeeBrown : Colors.brown[50],
                foregroundColor: selected ? Colors.white : Colors.brown[300],
                child: Text(title.isNotEmpty ? title[0].toUpperCase() : '?'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: coffeeBrown),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValuePreviewCard extends StatelessWidget {
  final double weight;
  final double pricePerKg;
  final double gross;

  const _ValuePreviewCard(
      {required this.weight, required this.pricePerKg, required this.gross});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.brown[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${weight.toStringAsFixed(1)} kg × Ksh ${pricePerKg.toStringAsFixed(2)}/kg '
        '= Ksh ${gross.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  // Most call sites (Farmer/Tag Ready steps) want the classic full-width
  // bottom button; the Review step's Confirm action wants a compact,
  // content-bound button instead, so this defaults to the existing
  // behavior rather than changing every call site.
  final bool fullWidth;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.brown[700],
        padding:
            EdgeInsets.symmetric(horizontal: fullWidth ? 16 : 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(icon ?? Icons.arrow_forward, color: Colors.white, size: 18),
      label: Text(label, style: const TextStyle(color: Colors.white)),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.brown[300]!),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: Text(label, style: TextStyle(color: Colors.brown[700])),
      ),
    );
  }
}
