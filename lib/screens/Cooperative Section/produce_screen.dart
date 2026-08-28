import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/farmer_produce.dart';
import 'package:coffeecore/models/produce_data.dart';
import 'package:coffeecore/models/produce_trace_stage.dart';
import 'package:coffeecore/services/produce_traceability_service.dart';
import 'package:coffeecore/utils/cooperative_name.dart';
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
                    ],
                    rows: submissions.map((submission) {
                      final parsedDate =
                          DateTime.tryParse(submission.submissionDate);
                      final formattedDate = parsedDate != null
                          ? DateFormat('yyyy-MM-dd').format(parsedDate)
                          : '-';
                      return DataRow(cells: [
                        DataCell(Text(formattedDate)),
                        DataCell(
                            Text(submission.totalAmount.toStringAsFixed(2))),
                        DataCell(_StageCell(
                          service: _traceService,
                          coopId: formattedCoopName,
                          userId: userId,
                          submissionId: submission.submissionId,
                        )),
                      ]);
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
                : StreamBuilder<List<ProduceData>>(
                    stream: _userRole == 'Farmer'
                        ? _produceDataStreamForUser(
                                formattedCoopName, _userId!, '')
                            .map((p) => [p])
                        : _produceDataStreamForCoop(formattedCoopName, ''),
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
                          child: Text('No produce data added yet.',
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
                                      DataCell(Text(data.farmerName)),
                                      DataCell(Text(data.contact)),
                                      DataCell(Text(data.farmArea)),
                                      DataCell(Text(
                                          data.latestTotalAmount == 0.0
                                              ? '-'
                                              : data.latestTotalAmount
                                                  .toStringAsFixed(2))),
                                      DataCell(Row(
                                        children: [
                                          if (data.id == _userId)
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  color: Colors.blue),
                                              onPressed: () =>
                                                  _addOrEditFarmSize(
                                                      true, data.farmArea),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.visibility,
                                                color: Colors.blue),
                                            onPressed: () => _viewSubmissions(
                                                data.id,
                                                data.farmerName,
                                                widget.cooperativeName),
                                          ),
                                        ],
                                      )),
                                    ]))
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
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
