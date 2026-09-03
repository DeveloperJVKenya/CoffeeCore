import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/farmer_produce.dart';
import 'package:coffeecore/models/produce_confirmation_status.dart';
import 'package:coffeecore/models/produce_data.dart';
import 'package:coffeecore/models/produce_trace_stage.dart';
import 'package:coffeecore/services/produce_traceability_service.dart';
import 'package:coffeecore/utils/cooperative_name.dart';
import 'package:coffeecore/widgets/produce_stage_chain.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

class ProduceScreen extends StatefulWidget {
  final String cooperativeName;

  const ProduceScreen({super.key, required this.cooperativeName});

  @override
  State<ProduceScreen> createState() => _ProduceScreenState();
}

class _ProduceScreenState extends State<ProduceScreen> {
  static final Color coffeeBrown = Colors.brown[700]!;
  final Logger logger = Logger(printer: PrettyPrinter());
  final TextEditingController _farmSizeController = TextEditingController();
  String? _userId;
  String? _farmerName;
  String? _phoneNumber;
  String? _feedbackMessage;
  String? _userRole; // Farmer, CoopAdmin, MarketManager, MainAdmin
  List<Map<String, String>> _coopUsers = []; // All users in cooperative
  List<String> _coopNames = []; // For MainAdmins
  final ProduceTraceabilityService _traceService = ProduceTraceabilityService();

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _fetchUserDetailsAndRole();
  }

  Future<void> _fetchUserDetailsAndRole() async {
    if (_userId == null) {
      setState(() {
        _feedbackMessage = 'No user logged in';
      });
      return;
    }

    try {
      String formattedCoopName = sanitizeCoopId(widget.cooperativeName);
      // Check user role
      final adminDoc = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(_userId)
          .get();
      if (!mounted) return;
      if (adminDoc.exists) {
        setState(() {
          _userRole = 'MainAdmin';
        });
        final coopSnapshot =
            await FirebaseFirestore.instance.collection('cooperatives').get();
        if (!mounted) return;
        _coopNames = coopSnapshot.docs.map((doc) => doc.id).toList();
        logger.i('MainAdmin detected, Coop names: $_coopNames');
      } else {
        final coopAdminDoc = await FirebaseFirestore.instance
            .collection('CoopAdmins')
            .doc(_userId)
            .get();
        final marketManagerDoc = await FirebaseFirestore.instance
            .collection('${formattedCoopName}_marketmanagers')
            .doc(_userId)
            .get();
        final userDoc = await FirebaseFirestore.instance
            .collection('${formattedCoopName}_users')
            .doc(_userId)
            .get();
        if (!mounted) return;

        if (coopAdminDoc.exists &&
            coopAdminDoc.data()?['cooperative'] == formattedCoopName) {
          _userRole = 'CoopAdmin';
        } else if (marketManagerDoc.exists) {
          _userRole = 'MarketManager';
        } else if (userDoc.exists) {
          _userRole = 'Farmer';
        } else {
          setState(() {
            _feedbackMessage = 'User not found in cooperative';
          });
          return;
        }

        if (_userRole == 'Farmer' ||
            _userRole == 'CoopAdmin' ||
            _userRole == 'MarketManager') {
          setState(() {
            _farmerName = userDoc.data()?['fullName']?.toString() ?? '-';
            _phoneNumber = userDoc.data()?['phoneNumber']?.toString() ?? '-';
          });
        }
      }

      if (_userRole == 'CoopAdmin' || _userRole == 'MarketManager') {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('${formattedCoopName}_users')
            .get();
        if (!mounted) return;
        _coopUsers = userSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'fullName': data['fullName']?.toString() ?? '-',
            'phoneNumber': data['phoneNumber']?.toString() ?? '-',
          };
        }).toList();
        logger.i('Fetched users: ${_coopUsers.length} found');
      }

      setState(() {});
    } catch (e, stackTrace) {
      logger.e(
          'Error fetching user details or role: $e\nStack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Error loading user details: $e';
      });
    }
  }

  // Combines a user doc, their ProduceData doc, and their latest submission
  // into one reactive ProduceData stream — replaces the previous approach of
  // doing one-shot .get() calls for the produce doc / latest submission
  // inside an asyncMap keyed only to the user doc's stream, which meant a
  // brand-new submission (or a produce-doc edit) never surfaced until the
  // user doc itself happened to change.
  Stream<ProduceData> _produceDataStreamForUser(
      String formattedCoopName, String userId, String coopLabel) {
    final userStream = FirebaseFirestore.instance
        .collection('${formattedCoopName}_users')
        .doc(userId)
        .snapshots();
    final produceStream = FirebaseFirestore.instance
        .collection('${formattedCoopName}_ProduceData')
        .doc(userId)
        .snapshots();
    final latestSubmissionStream = FirebaseFirestore.instance
        .collection('${formattedCoopName}_FarmerProduce')
        .doc(userId)
        .collection('submissions')
        .orderBy('submissionDate', descending: true)
        .limit(1)
        .snapshots();

    return CombineLatestStream.combine3(
      userStream,
      produceStream,
      latestSubmissionStream,
      (DocumentSnapshot userDoc, DocumentSnapshot produceDoc,
          QuerySnapshot submissionSnap) {
        final userData = {
          'id': userDoc.id,
          'fullName': (userDoc.data() as Map<String, dynamic>?)?['fullName']
                  ?.toString() ??
              '-',
          'phoneNumber':
              (userDoc.data() as Map<String, dynamic>?)?['phoneNumber']
                      ?.toString() ??
                  '-',
        };
        final double latestTotalAmount = submissionSnap.docs.isNotEmpty
            ? ((submissionSnap.docs.first.data()
                        as Map<String, dynamic>)['totalAmount'] as num?)
                    ?.toDouble() ??
                0.0
            : 0.0;
        return ProduceData.fromDocument(
          produceDoc.exists ? produceDoc : null,
          userData,
          latestTotalAmount,
          coopLabel,
        );
      },
    );
  }

  // Re-subscribes to a fresh CombineLatestStream whenever the cooperative's
  // user list changes (a farmer joining/leaving), instead of the previous
  // one-time _coopUsers fetch that never picked up membership changes
  // without a full screen remount.
  Stream<List<ProduceData>> _produceDataStreamForCoop(
      String formattedCoopName, String coopLabel) {
    return FirebaseFirestore.instance
        .collection('${formattedCoopName}_users')
        .snapshots()
        .switchMap((userSnapshot) {
      final ids = userSnapshot.docs.map((d) => d.id).toList();
      if (ids.isEmpty) return Stream<List<ProduceData>>.value(const []);
      return CombineLatestStream.list(
        ids.map((id) =>
            _produceDataStreamForUser(formattedCoopName, id, coopLabel)),
      );
    });
  }

  Future<void> _addOrEditFarmSize(bool isEdit,
      [String currentFarmSize = '']) async {
    if (_userId == null || _farmerName == null || _phoneNumber == null) {
      setState(() {
        _feedbackMessage = 'User details not loaded';
      });
      return;
    }

    if (isEdit) {
      _farmSizeController.text = currentFarmSize;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Edit Farm Size' : 'Add Farm Size'),
        content: TextField(
          controller: _farmSizeController,
          decoration: InputDecoration(
            labelText: 'Farm Size (e.g., 2.5 acres)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: coffeeBrown),
            onPressed: () {
              if (_farmSizeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a farm size')),
                );
                return;
              }
              Navigator.pop(dialogContext, _farmSizeController.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        String formattedCoopName = sanitizeCoopId(widget.cooperativeName);
        final produceData = ProduceData(
          id: _userId!,
          farmerName: _farmerName!,
          contact: _phoneNumber!,
          farmArea: result,
          latestTotalAmount: 0.0,
          timestamp: Timestamp.now(),
        );

        await FirebaseFirestore.instance
            .collection('${formattedCoopName}_ProduceData')
            .doc(_userId)
            .set(produceData.toMap(), SetOptions(merge: true));

        await _logActivity(
            '${isEdit ? 'Updated' : 'Added'} farm size $result for user $_userId in cooperative ${widget.cooperativeName}');
        setState(() {
          _feedbackMessage =
              'Farm size ${isEdit ? 'updated' : 'added'} successfully';
        });
      } catch (e, stackTrace) {
        logger.e(
            'Error ${isEdit ? 'updating' : 'adding'} farm size: $e\nStack trace: $stackTrace');
        setState(() {
          _feedbackMessage =
              'Error ${isEdit ? 'updating' : 'adding'} farm size: $e';
        });
      }
    }
    _farmSizeController.clear();
  }

  Future<void> _viewSubmissions(
      String userId, String farmerName, String coopName) async {
    final formattedCoopName = sanitizeCoopId(coopName);
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Submissions for $farmerName'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('${formattedCoopName}_FarmerProduce')
                .doc(userId)
                .collection('submissions')
                .where('submissionDate', isGreaterThan: '')
                .orderBy('submissionDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                logger.e(
                    'Error loading submissions: ${snapshot.error}\nPath: ${formattedCoopName}_FarmerProduce/$userId/submissions');
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No submissions found.');
              }

              final submissions = snapshot.data!.docs
                  .map((doc) => FarmerProduce.fromDocument(doc))
                  .toList();
              logger.i(
                  'Fetched ${submissions.length} submissions for user $userId');
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(
                          label: Text('Date',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Amount (kg)',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Stage',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Track',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: submissions.map((submission) {
                      final parsedDate =
                          DateTime.tryParse(submission.submissionDate);
                      final formattedDate = parsedDate != null
                          ? DateFormat('yyyy-MM-dd').format(parsedDate)
                          : '-';
                      return DataRow(
                        cells: [
                          DataCell(Text(formattedDate)),
                          DataCell(
                              Text(submission.totalAmount.toStringAsFixed(2))),
                          DataCell(_StageCell(
                            service: _traceService,
                            coopId: formattedCoopName,
                            userId: userId,
                            submissionId: submission.submissionId,
                          )),
                          // An explicit button — DataTable's onSelectChanged
                          // row-tap alone gives no visible hint that a row
                          // is tappable, so the horizontal stage tracker
                          // dialog was going undiscovered.
                          DataCell(
                            IconButton(
                              icon:
                                  const Icon(Icons.route, color: Colors.brown),
                              tooltip: 'View stage tracker',
                              onPressed: () => _showSubmissionTimeline(
                                  formattedCoopName, userId, submission),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Full stage-by-stage scan history for one submission — read-only here
  /// (the User role has no scan/edit action anywhere in traceability), the
  /// same timeline MarketManager/CoopAdmin see via
  /// ProduceTraceabilityScreen's _showTimeline, just reached from the
  /// farmer's own submissions dialog instead.
  Future<void> _showSubmissionTimeline(
      String coopId, String userId, FarmerProduce submission) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${submission.submissionDate} — Stage Timeline'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<ProduceTraceEntry>>(
            stream: _traceService.stageHistory(
                coopId, userId, submission.submissionId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SingleChildScrollView(
                child: ProduceStageChain(
                  history: snapshot.data!,
                  submissionDate: submission.submissionDate,
                  accentColor: coffeeBrown,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Live banner of this farmer's own submissions still awaiting their
  /// accept/decline — the QR scan pipeline in produce_qr_scan_screen.dart
  /// refuses to advance a bag past "Received" until the value here is
  /// accepted, so this is the farmer's only way to unblock it. Renders
  /// nothing once there's nothing pending.
  Widget _buildPendingConfirmationsBanner() {
    final formattedCoopName = sanitizeCoopId(widget.cooperativeName);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('${formattedCoopName}_FarmerProduce')
          .doc(_userId)
          .collection('submissions')
          .where('confirmationStatus',
              isEqualTo: ProduceConfirmationStatus.pending.storageValue)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final pending = docs.map((d) => FarmerProduce.fromDocument(d)).toList();
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.orange[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pending.length == 1
                          ? 'A delivery needs your confirmation'
                          : '${pending.length} deliveries need your confirmation',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...pending.map((s) => _PendingConfirmationTile(
                    submission: s,
                    onAccept: () => _acceptSubmission(s),
                    onDecline: () => _declineSubmission(s),
                  )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptSubmission(FarmerProduce submission) async {
    try {
      await FirebaseFirestore.instance
          .collection('${sanitizeCoopId(widget.cooperativeName)}_FarmerProduce')
          .doc(_userId)
          .collection('submissions')
          .doc(submission.submissionId)
          .update({
        'confirmationStatus': ProduceConfirmationStatus.accepted.storageValue,
        'confirmedAt': Timestamp.now(),
      });
      if (!mounted) return;
      setState(() => _feedbackMessage = 'Delivery confirmed');
    } catch (e, stackTrace) {
      logger.e('Error accepting submission: $e\nStack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _feedbackMessage = 'Failed to confirm: $e');
    }
  }

  Future<void> _declineSubmission(FarmerProduce submission) async {
    final reason = await _promptDeclineReason();
    if (reason == null || !mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('${sanitizeCoopId(widget.cooperativeName)}_FarmerProduce')
          .doc(_userId)
          .collection('submissions')
          .doc(submission.submissionId)
          .update({
        'confirmationStatus': ProduceConfirmationStatus.declined.storageValue,
        'confirmedAt': Timestamp.now(),
        'declineReason': reason,
      });
      if (!mounted) return;
      setState(() =>
          _feedbackMessage = 'Declined — the market manager has been flagged');
    } catch (e, stackTrace) {
      logger.e('Error declining submission: $e\nStack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _feedbackMessage = 'Failed to decline: $e');
    }
  }

  Future<String?> _promptDeclineReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline this value?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Let the market manager know what looks wrong (optional) — '
                'they can correct it and it will come back to you.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. weight looks too low',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _logActivity(String action) async {
    try {
      String formattedCoopName = sanitizeCoopId(widget.cooperativeName);
      await FirebaseFirestore.instance
          .collection('cooperatives')
          .doc(formattedCoopName)
          .collection('logs')
          .add({
        'action': action,
        'timestamp': Timestamp.now(),
        'adminUid': _userId,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  @override
  void dispose() {
    _farmSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_feedbackMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_feedbackMessage!)));
        setState(() => _feedbackMessage = null);
      });
    }

    String formattedCoopName = sanitizeCoopId(widget.cooperativeName);
    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: Text(
          'Produce - ${widget.cooperativeName}',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: coffeeBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: (_userRole == null || _userRole == 'MainAdmin')
          ? null
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('${formattedCoopName}_ProduceData')
                  .doc(_userId)
                  .snapshots(),
              builder: (context, snapshot) {
                bool hasData = snapshot.hasData && snapshot.data!.exists;
                return FloatingActionButton.extended(
                  onPressed: () => _addOrEditFarmSize(
                    hasData,
                    hasData
                        ? ProduceData.fromDocument(
                            snapshot.data!,
                            _coopUsers.firstWhere(
                              (u) => u['id'] == _userId,
                              orElse: () => {
                                'id': _userId!,
                                'fullName': _farmerName ?? '-',
                                'phoneNumber': _phoneNumber ?? '-',
                              },
                            ),
                            0.0,
                          ).farmArea
                        : '',
                  ),
                  label: Text(hasData ? 'Edit Farm Size' : 'Add Farm Size'),
                  icon: Icon(hasData ? Icons.edit : Icons.add),
                  backgroundColor: coffeeBrown,
                  foregroundColor: Colors.white,
                );
              },
            ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _userRole == null
            ? const Center(child: CircularProgressIndicator())
            : _userRole == 'MainAdmin'
                ? StreamBuilder<List<ProduceData>>(
                    stream: CombineLatestStream.list(
                      _coopNames.map((coopName) =>
                          _produceDataStreamForCoop(coopName, coopName)),
                    ).map((lists) => lists.expand((list) => list).toList()),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        logger
                            .e('Error loading produce data: ${snapshot.error}');
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('No produce data available.',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                        );
                      }

                      final produceData = snapshot.data!;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(
                                  label: Text('Cooperative',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Farmer Name',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Contact',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Farm Area',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Produce (kg)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Actions',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                            ],
                            rows: produceData
                                .map((data) => DataRow(cells: [
                                      DataCell(Text(data.cooperative)),
                                      DataCell(Text(data.farmerName)),
                                      DataCell(Text(data.contact)),
                                      DataCell(Text(data.farmArea)),
                                      DataCell(Text(
                                          data.latestTotalAmount == 0.0
                                              ? '-'
                                              : data.latestTotalAmount
                                                  .toStringAsFixed(2))),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.visibility,
                                              color: Colors.blue),
                                          onPressed: () => _viewSubmissions(
                                              data.id,
                                              data.farmerName,
                                              data.cooperative),
                                        ),
                                      ),
                                    ]))
                                .toList(),
                          ),
                        ),
                      );
                    },
                  )
                : Column(
                    children: [
                      if (_userRole == 'Farmer')
                        _buildPendingConfirmationsBanner(),
                      Expanded(
                          child: _buildFarmerOrCoopProduceTable(
                              formattedCoopName)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFarmerOrCoopProduceTable(String formattedCoopName) {
    return StreamBuilder<List<ProduceData>>(
      stream: _userRole == 'Farmer'
          ? _produceDataStreamForUser(formattedCoopName, _userId!, '')
              .map((p) => [p])
          : _produceDataStreamForCoop(formattedCoopName, ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          logger.e('Error loading produce data: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No produce data added yet.',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          );
        }

        final produceData = snapshot.data!;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(
                    label: Text('Farmer Name',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Contact',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Farm Area',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Produce (kg)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Actions',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: produceData
                  .map((data) => DataRow(cells: [
                        DataCell(Text(data.farmerName)),
                        DataCell(Text(data.contact)),
                        DataCell(Text(data.farmArea)),
                        DataCell(Text(data.latestTotalAmount == 0.0
                            ? '-'
                            : data.latestTotalAmount.toStringAsFixed(2))),
                        DataCell(Row(
                          children: [
                            if (data.id == _userId)
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _addOrEditFarmSize(true, data.farmArea),
                              ),
                            IconButton(
                              icon: const Icon(Icons.visibility,
                                  color: Colors.blue),
                              onPressed: () => _viewSubmissions(data.id,
                                  data.farmerName, widget.cooperativeName),
                            ),
                          ],
                        )),
                      ]))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

/// One pending-confirmation card in [_ProduceScreenState._buildPendingConfirmationsBanner]
/// — the value breakdown plus Accept/Decline actions for a single delivery.
class _PendingConfirmationTile extends StatelessWidget {
  final FarmerProduce submission;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PendingConfirmationTile({
    required this.submission,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${submission.submissionDate} · '
            '${submission.variety.isEmpty ? "-" : submission.variety}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${submission.totalAmount.toStringAsFixed(1)} kg × '
            'Ksh ${submission.pricePerKg.toStringAsFixed(2)}/kg '
            '= Ksh ${submission.grossValue.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDecline,
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: const Text('Decline',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 16, color: Colors.white),
                  label: const Text('Accept',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Current traceability stage for one submission, in the submissions
/// dialog's DataTable — the QR-scan pipeline built alongside this reads/
/// writes {coop}_FarmerProduce/.../traceStages, computed live rather than
/// stored, same reasoning as everywhere else this session.
class _StageCell extends StatelessWidget {
  final ProduceTraceabilityService service;
  final String coopId;
  final String userId;
  final String submissionId;

  const _StageCell({
    required this.service,
    required this.coopId,
    required this.userId,
    required this.submissionId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProduceTraceEntry>>(
      stream: service.stageHistory(coopId, userId, submissionId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final stage = service.currentStage(snapshot.data!);
        return Text(stage.label);
      },
    );
  }
}
