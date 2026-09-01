import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/farmer_produce.dart';
import 'package:coffeecore/models/produce_trace_stage.dart';
import 'package:coffeecore/services/produce_qr_service.dart';
import 'package:coffeecore/services/produce_traceability_service.dart';
import 'package:coffeecore/utils/cooperative_name.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Market-Manager-only camera scanner for produce bag QR tags. Reached only
/// from MarketManagerScreen, which is already role-gated, so this screen
/// trusts its caller rather than re-deriving role — the same reasoning
/// PriceListScreen/SubmissionListScreen already rely on.
class ProduceQrScanScreen extends StatefulWidget {
  final String cooperativeName;

  const ProduceQrScanScreen({super.key, required this.cooperativeName});

  @override
  State<ProduceQrScanScreen> createState() => _ProduceQrScanScreenState();
}

class _ProduceQrScanScreenState extends State<ProduceQrScanScreen> {
  static final Color coffeeBrown = Colors.brown[700]!;
  final Logger logger = Logger(printer: PrettyPrinter());
  final MobileScannerController _controller = MobileScannerController();
  final ProduceTraceabilityService _service = ProduceTraceabilityService();

  bool _isProcessing = false;
  String? _feedbackMessage;

  // Manual fallback state — populated each time the "Enter Manually" dialog
  // is opened, since some web browsers/devices used for pre-Android testing
  // (a laptop with no webcam, a browser that blocks camera access, Firefox
  // without the BarcodeDetector API, etc.) can't reliably scan at all. Not
  // cached across opens: a farmer registered mid-session must show up the
  // next time this dialog is opened, not just after the screen is torn
  // down and rebuilt.
  List<Map<String, String>> _coopUsers = [];

  late final String _coopId = sanitizeCoopId(widget.cooperativeName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final raw =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null) return;

    final payload = ProduceQrService.decode(raw);
    if (payload == null) {
      _showSnack('Not a recognized produce tag.');
      return;
    }
    if (payload.coopId != _coopId) {
      _showSnack('This tag belongs to a different cooperative.');
      return;
    }

    setState(() => _isProcessing = true);
    await _controller.stop();
    await _handleScannedBag(payload);
    if (mounted) {
      setState(() => _isProcessing = false);
      await _controller.start();
    }
  }

  Future<void> _handleScannedBag(ProduceQrPayload payload) =>
      _openBag(payload.coopId, payload.userId, payload.submissionId);

  /// Shared by both the camera scan path and the manual-entry fallback —
  /// both ultimately just need the three IDs to look up a bag.
  Future<void> _openBag(
      String coopId, String userId, String submissionId) async {
    try {
      final submissionDoc = await FirebaseFirestore.instance
          .collection('${coopId}_FarmerProduce')
          .doc(userId)
          .collection('submissions')
          .doc(submissionId)
          .get();
      if (!submissionDoc.exists) {
        _showSnack('Submission not found — the tag may be stale.');
        return;
      }
      final submission = FarmerProduce.fromDocument(submissionDoc);

      final history =
          await _service.stageHistory(coopId, userId, submissionId).first;
      final currentStage = _service.currentStage(history);

      if (!mounted) return;
      await _showStageSheet(
        ProduceQrPayload(
            coopId: coopId, userId: userId, submissionId: submissionId),
        submission,
        currentStage,
      );
    } catch (e, stackTrace) {
      logger.e('Error handling scanned bag: $e\nStack trace: $stackTrace');
      _showSnack('Error reading tag: $e');
    }
  }

  Future<void> _showStageSheet(
    ProduceQrPayload payload,
    FarmerProduce submission,
    ProduceStage currentStage,
  ) async {
    final nextStage = currentStage.next;
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(submission.farmerName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                  '${submission.totalAmount.toStringAsFixed(1)} kg'
                  '${submission.variety.isNotEmpty ? " · ${submission.variety}" : ""}',
                  style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 12),
              Text('Current stage: ${currentStage.label}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: coffeeBrown)),
              const SizedBox(height: 16),
              if (nextStage == null)
                const Text(
                    'This bag has reached the final stage (Dispatched to '
                    'Market) — no further progression available.',
                    style: TextStyle(color: Colors.grey))
              else ...[
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: coffeeBrown,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final scannedBy =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (scannedBy == null) {
                              setSheetState(() => errorText =
                                  'You are signed out — please sign in again.');
                              return;
                            }
                            setSheetState(() {
                              isSubmitting = true;
                              errorText = null;
                            });
                            try {
                              await _service.recordStage(
                                coopId: payload.coopId,
                                userId: payload.userId,
                                submissionId: payload.submissionId,
                                expectedCurrentStage: currentStage,
                                stage: nextStage,
                                scannedBy: scannedBy,
                                scannedByName: FirebaseAuth
                                        .instance.currentUser?.displayName ??
                                    '',
                                note: noteCtrl.text.trim(),
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              _showSnack('Advanced to ${nextStage.label} for '
                                  '${submission.farmerName}.');
                            } catch (e) {
                              setSheetState(() {
                                isSubmitting = false;
                                errorText = e is StateError
                                    ? e.message
                                    : 'Failed to save: $e';
                              });
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Advance to ${nextStage.label}',
                            style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    setState(() => _feedbackMessage = message);
  }

  Future<void> _openManualEntry() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('${_coopId}_users').get();
      _coopUsers = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fullName': data['fullName']?.toString() ?? '-',
        };
      }).toList();
    } catch (e, stackTrace) {
      logger.e('Error fetching users for manual entry: $e\n$stackTrace');
      _showSnack('Could not load farmer list: $e');
      return;
    }
    if (!mounted) return;

    String? selectedUserId;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enter Manually'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    "Can't use the camera? Pick the farmer, then choose "
                    'the bag from their recent submissions.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedUserId,
                  hint: const Text('Select farmer'),
                  isExpanded: true,
                  items: _coopUsers
                      .map((u) => DropdownMenuItem<String>(
                          value: u['id'], child: Text(u['fullName']!)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedUserId = v),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedUserId != null)
                  SizedBox(
                    height: 220,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('${_coopId}_FarmerProduce')
                          .doc(selectedUserId)
                          .collection('submissions')
                          .orderBy('timestamp', descending: true)
                          .limit(15)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(
                              child: Text('No submissions for this farmer.',
                                  style: TextStyle(color: Colors.grey)));
                        }
                        return ListView(
                          shrinkWrap: true,
                          children: docs.map((doc) {
                            final sub = FarmerProduce.fromDocument(doc);
                            return ListTile(
                              title: Text('${sub.totalAmount} kg'
                                  '${sub.variety.isNotEmpty ? " · ${sub.variety}" : ""}'),
                              subtitle: Text(sub.submissionDate),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                _openBag(_coopId, sub.id, sub.submissionId);
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // Web is the platform most likely to hit this: a laptop with no webcam,
  // a browser that blocks camera access, or Firefox falling back to the
  // zxing-wasm backend while it's still loading. Camera permission denial
  // is also common on a first-time test link before a user trusts the site.
  // In all of these cases the "Enter Manually" fallback above still works.
  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    final String message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera permission was denied. Allow camera access for this site '
            'in your browser settings, then try again — or use "Enter '
            'Manually" above.',
      MobileScannerErrorCode.unsupported =>
        'No camera was found on this device/browser. Use "Enter Manually" '
            'above instead.',
      _ => 'Could not start the camera (${error.errorCode.name}). Use '
          '"Enter Manually" above, or try again.',
    };
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: coffeeBrown),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label:
                const Text('Try Again', style: TextStyle(color: Colors.white)),
            onPressed: () => _controller.start(),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.keyboard, color: Colors.white70),
            label: const Text('Enter Manually',
                style: TextStyle(color: Colors.white70)),
            onPressed: _openManualEntry,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_feedbackMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_feedbackMessage!)));
        setState(() => _feedbackMessage = null);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Produce Tag',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: coffeeBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard, color: Colors.white),
            tooltip: 'Enter Manually',
            onPressed: _openManualEntry,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _buildCameraError(context, error),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Text(
              'Point the camera at a produce bag QR tag',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black87)]),
            ),
          ),
        ],
      ),
    );
  }
}
