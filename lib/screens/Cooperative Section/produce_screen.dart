import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

// Model class for ProduceData collection
class ProduceData {
  final String id; // Document ID (userId)
  final String farmerName;
  final String contact;
  final String farmArea;
  final double latestTotalAmount; // From latest submission
  final Timestamp timestamp;
  final String cooperative; // For MainAdmins

  ProduceData({
    required this.id,
    required this.farmerName,
    required this.contact,
    required this.farmArea,
    required this.latestTotalAmount,
    required this.timestamp,
    this.cooperative = '',
  });

  // Convert ProduceData to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'FarmerName': farmerName,
      'Contact': contact,
      'FarmArea': farmArea,
      'timestamp': timestamp,
    };
  }

  // Create ProduceData from Firestore document and user data
  factory ProduceData.fromDocument(DocumentSnapshot? doc, Map<String, String?> userData, double latestTotalAmount, [String cooperative = '']) {
    final data = doc?.data() as Map<String, dynamic>? ?? {};
    return ProduceData(
      id: doc?.id ?? userData['id']!,
      farmerName: data['FarmerName']?.toString() ?? userData['fullName'] ?? '-',
      contact: data['Contact']?.toString() ?? userData['phoneNumber'] ?? '-',
      farmArea: data['FarmArea']?.toString() ?? '-',
      latestTotalAmount: latestTotalAmount,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      cooperative: cooperative,
    );
  }
}

// Model class for submissions
class FarmerProduce {
  final String id; // userId
  final String farmerName;
  final String contact;
  final double totalAmount;
  final Timestamp timestamp;
  final String submissionDate;
  final String submissionId;

  FarmerProduce({
    required this.id,
    required this.farmerName,
    required this.contact,
    required this.totalAmount,
    required this.timestamp,
    required this.submissionDate,
    required this.submissionId,
  });

  factory FarmerProduce.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FarmerProduce(
      id: doc.reference.parent.parent?.id ?? '',
      farmerName: data['farmerName']?.toString() ?? '-',
      contact: data['contact']?.toString() ?? '-',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      submissionDate: data['submissionDate']?.toString() ?? '',
      submissionId: doc.id,
    );
  }
}

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
      String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
      // Check user role
      final adminDoc = await FirebaseFirestore.instance.collection('Admins').doc(_userId).get();
      if (adminDoc.exists) {
        setState(() {
          _userRole = 'MainAdmin';
        });
        final coopSnapshot = await FirebaseFirestore.instance.collection('cooperatives').get();
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

        if (coopAdminDoc.exists && coopAdminDoc.data()?['cooperative'] == formattedCoopName) {
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

        if (_userRole == 'Farmer' || _userRole == 'CoopAdmin' || _userRole == 'MarketManager') {
          setState(() {
            _farmerName = userDoc.data()?['fullName']?.toString() ?? '-';
            _phoneNumber = userDoc.data()?['phoneNumber']?.toString() ?? '-';
          });
        }
      }

      if (_userRole == 'CoopAdmin' || _userRole == 'MarketManager') {
        final userSnapshot = await FirebaseFirestore.instance.collection('${formattedCoopName}_users').get();
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
      logger.e('Error fetching user details or role: $e\nStack trace: $stackTrace');
      setState(() {
        _feedbackMessage = 'Error loading user details: $e';
      });
    }
  }

  Future<void> _addOrEditFarmSize(bool isEdit, [String currentFarmSize = '']) async {
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
        String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
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

        await _logActivity('${isEdit ? 'Updated' : 'Added'} farm size $result for user $_userId in cooperative ${widget.cooperativeName}');
        setState(() {
          _feedbackMessage = 'Farm size ${isEdit ? 'updated' : 'added'} successfully';
        });
      } catch (e, stackTrace) {
        logger.e('Error ${isEdit ? 'updating' : 'adding'} farm size: $e\nStack trace: $stackTrace');
        setState(() {
          _feedbackMessage = 'Error ${isEdit ? 'updating' : 'adding'} farm size: $e';
        });
      }
    }
    _farmSizeController.clear();
  }

  Future<void> _viewSubmissions(String userId, String farmerName, String coopName) async {
    final formattedCoopName = coopName.replaceAll(' ', '_');
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
                logger.e('Error loading submissions: ${snapshot.error}\nPath: ${formattedCoopName}_FarmerProduce/$userId/submissions');
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No submissions found.');
              }

              final submissions = snapshot.data!.docs.map((doc) => FarmerProduce.fromDocument(doc)).toList();
              logger.i('Fetched ${submissions.length} submissions for user $userId');
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Amount (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: submissions.map((submission) {
                      final formattedDate = submission.submissionDate.isNotEmpty
                          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(submission.submissionDate))
                          : '-';
                      return DataRow(cells: [
                        DataCell(Text(formattedDate)),
                        DataCell(Text(submission.totalAmount.toStringAsFixed(2))),
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
      String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_feedbackMessage!)));
        setState(() => _feedbackMessage = null);
      });
    }

    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: Text(
          'Produce - ${widget.cooperativeName}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      _coopNames.map((coopName) {
                        return FirebaseFirestore.instance
                            .collection('${coopName}_users')
                            .snapshots()
                            .asyncMap((userSnapshot) async {
                              List<ProduceData> produceList = [];
                              for (var userDoc in userSnapshot.docs) {
                                final userData = {
                                  'id': userDoc.id,
                                  'fullName': userDoc.data()['fullName']?.toString() ?? '-',
                                  'phoneNumber': userDoc.data()['phoneNumber']?.toString() ?? '-',
                                };
                                final produceDoc = await FirebaseFirestore.instance
                                    .collection('${coopName}_ProduceData')
                                    .doc(userDoc.id)
                                    .get();
                                final submissionSnapshot = await FirebaseFirestore.instance
                                    .collection('${coopName}_FarmerProduce')
                                    .doc(userDoc.id)
                                    .collection('submissions')
                                    .orderBy('submissionDate', descending: true)
                                    .limit(1)
                                    .get();
                                double latestTotalAmount = submissionSnapshot.docs.isNotEmpty
                                    ? (submissionSnapshot.docs.first.data()['totalAmount'] as num?)?.toDouble() ?? 0.0
                                    : 0.0;
                                produceList.add(ProduceData.fromDocument(
                                  produceDoc.exists ? produceDoc : null,
                                  userData,
                                  latestTotalAmount,
                                  coopName,
                                ));
                              }
                              return produceList;
                            });
                      }).toList(),
                    ).map((lists) => lists.expand((list) => list).toList()),
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
                          child: Text('No produce data available.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        );
                      }

                      final produceData = snapshot.data!;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Cooperative', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Farmer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Farm Area', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Produce (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: produceData.map((data) => DataRow(cells: [
                                  DataCell(Text(data.cooperative)),
                                  DataCell(Text(data.farmerName)),
                                  DataCell(Text(data.contact)),
                                  DataCell(Text(data.farmArea)),
                                  DataCell(Text(data.latestTotalAmount == 0.0 ? '-' : data.latestTotalAmount.toStringAsFixed(2))),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.visibility, color: Colors.blue),
                                      onPressed: () => _viewSubmissions(data.id, data.farmerName, data.cooperative),
                                    ),
                                  ),
                                ])).toList(),
                          ),
                        ),
                      );
                    },
                  )
                : StreamBuilder<List<ProduceData>>(
                    stream: CombineLatestStream.list(
                      (_userRole == 'Farmer' ? [_userId!] : _coopUsers.map((u) => u['id']!)).map((userId) {
                        return FirebaseFirestore.instance
                            .collection('${formattedCoopName}_users')
                            .doc(userId)
                            .snapshots()
                            .asyncMap((userDoc) async {
                              final userData = {
                                'id': userDoc.id,
                                'fullName': userDoc.data()?['fullName']?.toString() ?? '-',
                                'phoneNumber': userDoc.data()?['phoneNumber']?.toString() ?? '-',
                              };
                              final produceDoc = await FirebaseFirestore.instance
                                  .collection('${formattedCoopName}_ProduceData')
                                  .doc(userDoc.id)
                                  .get();
                              final submissionSnapshot = await FirebaseFirestore.instance
                                  .collection('${formattedCoopName}_FarmerProduce')
                                  .doc(userDoc.id)
                                  .collection('submissions')
                                  .orderBy('submissionDate', descending: true)
                                  .limit(1)
                                  .get();
                              double latestTotalAmount = submissionSnapshot.docs.isNotEmpty
                                  ? (submissionSnapshot.docs.first.data()['totalAmount'] as num?)?.toDouble() ?? 0.0
                                  : 0.0;
                              return ProduceData.fromDocument(
                                produceDoc.exists ? produceDoc : null,
                                userData,
                                latestTotalAmount,
                              );
                            });
                      }).toList(),
                    ),
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
                          child: Text('No produce data added yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        );
                      }

                      final produceData = snapshot.data!;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Farmer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Farm Area', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Produce (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: produceData.map((data) => DataRow(cells: [
                                  DataCell(Text(data.farmerName)),
                                  DataCell(Text(data.contact)),
                                  DataCell(Text(data.farmArea)),
                                  DataCell(Text(data.latestTotalAmount == 0.0 ? '-' : data.latestTotalAmount.toStringAsFixed(2))),
                                  DataCell(Row(
                                    children: [
                                      if (data.id == _userId)
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _addOrEditFarmSize(true, data.farmArea),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.visibility, color: Colors.blue),
                                        onPressed: () => _viewSubmissions(data.id, data.farmerName, widget.cooperativeName),
                                      ),
                                    ],
                                  )),
                                ])).toList(),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}