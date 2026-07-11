import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/utils/excel_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class CoopCollectionManagementScreen extends StatefulWidget {
  final String cooperativeName;
  final String collectionName;

  const CoopCollectionManagementScreen({
    required this.cooperativeName,
    required this.collectionName,
    super.key,
  });

  @override
  State<CoopCollectionManagementScreen> createState() =>
      _CoopCollectionManagementScreenState();
}

class _CoopCollectionManagementScreenState
    extends State<CoopCollectionManagementScreen> {
  final Logger logger = Logger(printer: PrettyPrinter());
  String _sortField = 'fullName';
  bool _sortAscending = true;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy HH:mm');
  final Map<String, String> _collectionDisplayNames = {
    'marketmanagers': 'Market Managers',
    'loanmanagers': 'Loan Managers',
    'coffeeprices': 'Coffee Prices',
    'coffee_disease_interventions': 'Disease Data',
    'coffee_pest_interventions': 'Pest Data',
    'coffee_soil_data': 'Soil Data',
  };
  final List<String> _excludedFields = [
    'uid',
    'userId',
    'adminUid',
    'createdBy',
    'updatedBy',
    'added',
    'isDeleted',
    'deletedAt',
    'profileImage',
    'documentId',
  ];
  final List<String> _globalCollections = [
    'coffee_disease_interventions',
    'coffee_pest_interventions',
    'coffee_soil_data',
  ];

  Future<void> _deleteDocument(String docId) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to remove this ${_collectionDisplayNames[widget.collectionName]!.toLowerCase().replaceAll(' data', '')}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        String collectionPath = _globalCollections
                .contains(widget.collectionName)
            ? widget.collectionName
            : '${widget.cooperativeName.replaceAll(' ', '_')}_${widget.collectionName}';
        await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(docId)
            .delete();
        await _logActivity(
          'Removed ${_collectionDisplayNames[widget.collectionName]!.toLowerCase().replaceAll(' data', '')} $docId from cooperative ${widget.cooperativeName}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${_collectionDisplayNames[widget.collectionName]} removed successfully!'),
            ),
          );
        }
      }
    } catch (e) {
      logger.e('Error deleting document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error removing: $e')));
      }
    }
  }

  Future<void> _editDocument(
      String docId, Map<String, dynamic> currentData) async {
    final Map<String, TextEditingController> controllers = {};
    DateTime? interventionDate;

    final fieldsMap = {
      'coffee_soil_data': [
        'stage',
        'structureType',
        'plotId',
        'ph',
        'nitrogen',
        'phosphorus',
        'potassium',
        'magnesium',
        'calcium',
        'interventionMethod',
        'interventionQuantity',
        'interventionUnit',
      ],
    };

    final numericFields = widget.collectionName == 'coffee_soil_data'
        ? ['ph', 'nitrogen', 'phosphorus', 'potassium', 'magnesium', 'calcium']
        : [];

    List<String> fields = [];
    if (widget.collectionName == 'coffee_soil_data') {
      interventionDate = currentData['interventionFollowUpDate'] != null
          ? (currentData['interventionFollowUpDate'] as Timestamp).toDate()
          : null;
      fields = fieldsMap['coffee_soil_data']!;
    } else if (['coffee_disease_interventions', 'coffee_pest_interventions']
        .contains(widget.collectionName)) {
      interventionDate = currentData['interventionFollowUpDate'] != null
          ? (currentData['interventionFollowUpDate'] as Timestamp).toDate()
          : null;
      fields = currentData.keys
          .where((key) =>
              !_excludedFields.contains(key) &&
              key != 'fullName' &&
              key != 'timestamp' &&
              key != 'interventionFollowUpDate')
          .toList();
    } else {
      fields = currentData.keys
          .where((key) =>
              !_excludedFields.contains(key) &&
              key != 'fullName' &&
              key != 'timestamp')
          .toList();
    }

    for (var field in fields) {
      controllers[field] =
          TextEditingController(text: currentData[field]?.toString() ?? '');
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            'Edit ${_collectionDisplayNames[widget.collectionName]!.replaceAll(' Data', '')}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...fields.map((field) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: controllers[field]!,
                      decoration: InputDecoration(
                        labelText: field,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: numericFields.contains(field)
                          ? TextInputType.number
                          : TextInputType.text,
                    ),
                  )),
              if ([
                'coffee_soil_data',
                'coffee_disease_interventions',
                'coffee_pest_interventions'
              ].contains(widget.collectionName))
                ListTile(
                  title: Text(
                    'Intervention Follow-Up: ${interventionDate?.toString().substring(0, 10) ?? '-'}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: interventionDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      interventionDate = picked;
                    }
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final updatedData = controllers
                  .map((key, controller) => MapEntry(key, controller.text));
              Navigator.pop(dialogContext, updatedData);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        String collectionPath = _globalCollections
                .contains(widget.collectionName)
            ? widget.collectionName
            : '${widget.cooperativeName.replaceAll(' ', '_')}_${widget.collectionName}';
        final updateData = <String, dynamic>{};
        result.forEach((key, value) {
          if (numericFields.contains(key)) {
            updateData[key] = value.isNotEmpty ? double.tryParse(value) : null;
          } else if (key == 'price') {
            updateData[key] = value.isNotEmpty ? double.tryParse(value) : null;
            updateData['updatedBy'] = FirebaseAuth.instance.currentUser?.uid;
            updateData['timestamp'] = Timestamp.now();
          } else {
            updateData[key] = value.isNotEmpty ? value : null;
          }
        });
        if ([
              'coffee_soil_data',
              'coffee_disease_interventions',
              'coffee_pest_interventions'
            ].contains(widget.collectionName) &&
            interventionDate != null) {
          updateData['interventionFollowUpDate'] =
              Timestamp.fromDate(interventionDate!);
        }
        await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(docId)
            .update(updateData);
        await _logActivity(
          'Updated ${_collectionDisplayNames[widget.collectionName]!.toLowerCase().replaceAll(' data', '')} $docId in cooperative ${widget.cooperativeName}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${_collectionDisplayNames[widget.collectionName]} updated successfully!'),
            ),
          );
        }
      } catch (e) {
        logger.e('Error updating document: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error updating: $e')));
        }
      }
    }

    controllers.forEach((_, controller) => controller.dispose());
  }

  Future<void> _resetPassword(String email) async {
    try {
      if (email.isEmpty) throw 'Email is required';
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      await _logActivity(
          'Sent password reset email to $email in cooperative ${widget.cooperativeName}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset email sent!')));
      }
    } catch (e) {
      logger.e('Error sending password reset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending password reset: $e')));
      }
    }
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
        'adminUid': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  Future<String> _fetchUserName(String uid) async {
    try {
      String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
      final userDoc = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_users')
          .doc(uid)
          .get();
      return userDoc.exists ? userDoc['fullName'] ?? '-' : '-';
    } catch (e) {
      logger.e('Error fetching user name for UID $uid: $e');
      return '-';
    }
  }

  Future<List<String>> _fetchCoopUserIds() async {
    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_users')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      logger.e('Error fetching cooperative user IDs: $e');
      return [];
    }
  }

  Future<void> _exportToExcel(List<QueryDocumentSnapshot> docs) async {
    try {
      // Define fields
      final firstDocData =
          docs.isNotEmpty ? docs.first.data() as Map<String, dynamic> : {};
      List<String> fields = [];

      if (widget.collectionName == 'coffee_soil_data') {
        fields = [
          'stage',
          'structureType',
          'plotId',
          'ph',
          'nitrogen',
          'phosphorus',
          'potassium',
          'magnesium',
          'calcium',
          'interventionMethod',
          'interventionQuantity',
          'interventionUnit',
          'interventionFollowUpDate',
          'timestamp',
        ];
      } else if (['coffee_disease_interventions', 'coffee_pest_interventions']
          .contains(widget.collectionName)) {
        fields = firstDocData.keys
            .where((key) => !_excludedFields.contains(key) && key != 'fullName')
            .toList()
            .cast<String>();
      } else if (widget.collectionName == 'coffeeprices') {
        fields = ['variety', 'price', 'timestamp'];
      } else {
        fields = firstDocData.keys
            .where((key) => !_excludedFields.contains(key) && key != 'fullName')
            .toList()
            .cast<String>();
      }

      if (fields.isEmpty) {
        fields = ['unknown'];
      }

      // Define headers
      List<String> headers = ['Full Name', ...fields];
      if (widget.collectionName == 'coffeeprices') {
        headers = ['Variety', ...fields, 'Updated By'];
      }

      // Prepare data
      List<Map<String, dynamic>> exportData = [];
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final docId = doc.id;

        // Fetch full name
        final fullName = widget.collectionName == 'coffeeprices'
            ? (data['variety'] ?? 'N/A')
            : await _fetchUserName(data['userId'] ?? docId);

        // Prepare row data
        Map<String, dynamic> rowData = {
          'fullName': fullName,
        };

        for (var field in fields) {
          if (field == 'timestamp' || field == 'interventionFollowUpDate') {
            rowData[field] = data[field] != null
                ? _dateFormat.format((data[field] as Timestamp).toDate())
                : 'N/A';
          } else if (field == 'price') {
            rowData[field] = (data[field] as num?)?.toStringAsFixed(2) ?? 'N/A';
          } else {
            rowData[field] = data[field]?.toString() ?? 'N/A';
          }
        }

        if (widget.collectionName == 'coffeeprices') {
          final updatedBy = await _fetchUserName(data['updatedBy'] ?? '');
          rowData['updatedBy'] = updatedBy;
        }

        exportData.add(rowData);
      }

      // Generate file name with timestamp
      String timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      String fileName =
          '${_collectionDisplayNames[widget.collectionName]}_$timestamp.xlsx';

      // Call ExcelUtils to generate and share the Excel file, but only if mounted
      if (mounted) {
        await ExcelUtils.downloadExcel(
          context: context,
          data: exportData,
          headers: headers,
          fileName: fileName,
          shareText:
              '${_collectionDisplayNames[widget.collectionName]} Export: $fileName',
          logger: logger,
        );
      }

      // Log activity (no context needed)
      await _logActivity(
        'Exported ${_collectionDisplayNames[widget.collectionName]!.toLowerCase()} to Excel file $fileName in cooperative ${widget.cooperativeName}',
      );
    } catch (e) {
      logger.e('Error exporting to Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving Excel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String collectionPath = _globalCollections.contains(widget.collectionName)
        ? widget.collectionName
        : '${widget.cooperativeName.replaceAll(' ', '_')}_${widget.collectionName}';
    String title =
        _collectionDisplayNames[widget.collectionName] ?? widget.collectionName;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (![
            'coffeeprices',
            'coffee_disease_interventions',
            'coffee_pest_interventions',
            'coffee_soil_data'
          ].contains(widget.collectionName))
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text('Sort by: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _sortField,
                    items: const [
                      DropdownMenuItem(
                          value: 'fullName', child: Text('Full Name')),
                      DropdownMenuItem(value: 'county', child: Text('County')),
                      DropdownMenuItem(
                          value: 'constituency', child: Text('Constituency')),
                      DropdownMenuItem(value: 'ward', child: Text('Ward')),
                    ],
                    onChanged: (value) => setState(() => _sortField = value!),
                    style: const TextStyle(color: Colors.black),
                  ),
                  IconButton(
                    icon: Icon(_sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward),
                    onPressed: () =>
                        setState(() => _sortAscending = !_sortAscending),
                  ),
                ],
              ),
            ),
          if (_globalCollections.contains(widget.collectionName))
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: Text('Export $title to Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  String collectionPath = _globalCollections
                          .contains(widget.collectionName)
                      ? widget.collectionName
                      : '${widget.cooperativeName.replaceAll(' ', '_')}_${widget.collectionName}';
                  final snapshot = await FirebaseFirestore.instance
                      .collection(collectionPath)
                      .orderBy('timestamp', descending: !_sortAscending)
                      .get();
                  await _exportToExcel(snapshot.docs);
                },
              ),
            ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _globalCollections.contains(widget.collectionName)
                  ? _fetchCoopUserIds()
                  : Future.value([]),
              builder: (context, userIdsSnapshot) {
                if (userIdsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (userIdsSnapshot.hasError) {
                  logger.e('Error fetching user IDs: ${userIdsSnapshot.error}');
                  return Center(child: Text('Error: ${userIdsSnapshot.error}'));
                }
                final coopUserIds = userIdsSnapshot.data ?? [];
                if (_globalCollections.contains(widget.collectionName) &&
                    coopUserIds.isNotEmpty) {
                  const batchSize = 10;
                  final batches = <List<String>>[];
                  for (var i = 0; i < coopUserIds.length; i += batchSize) {
                    batches.add(coopUserIds.sublist(
                        i,
                        i + batchSize > coopUserIds.length
                            ? coopUserIds.length
                            : i + batchSize));
                  }

                  final streams = batches.map((batch) => FirebaseFirestore
                      .instance
                      .collection(collectionPath)
                      .where('userId', whereIn: batch)
                      .orderBy('timestamp', descending: !_sortAscending)
                      .snapshots());

                  return StreamBuilder<List<QuerySnapshot>>(
                    stream: CombineLatestStream.list(streams),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        logger.e(
                            'Error in batch query for ${widget.collectionName}: ${snapshot.error}');
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                            child: Text(
                                'No ${_collectionDisplayNames[widget.collectionName]!.toLowerCase()} found.'));
                      }

                      final docs = snapshot.data!
                          .expand((querySnapshot) => querySnapshot.docs)
                          .toList();
                      return _buildDataTable(docs);
                    },
                  );
                } else {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(collectionPath)
                        .orderBy(
                            widget.collectionName == 'coffeeprices'
                                ? 'variety'
                                : _sortField,
                            descending: !_sortAscending)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        logger.e(
                            'Error in collection ${widget.collectionName}: ${snapshot.error}');
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                            child: Text(
                                'No ${_collectionDisplayNames[widget.collectionName]!.toLowerCase()} found.'));
                      }

                      final docs = snapshot.data!.docs;
                      return _buildDataTable(docs);
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<QueryDocumentSnapshot> docs) {
    final firstDocData =
        docs.isNotEmpty ? docs.first.data() as Map<String, dynamic> : {};
    List<String> fields = [];

    if (widget.collectionName == 'coffee_soil_data') {
      fields = [
        'stage',
        'structureType',
        'plotId',
        'ph',
        'nitrogen',
        'phosphorus',
        'potassium',
        'magnesium',
        'calcium',
        'interventionMethod',
        'interventionQuantity',
        'interventionUnit',
        'interventionFollowUpDate',
        'timestamp',
      ];
    } else if (['coffee_disease_interventions', 'coffee_pest_interventions']
        .contains(widget.collectionName)) {
      fields = firstDocData.keys
          .where((key) => !_excludedFields.contains(key) && key != 'fullName')
          .toList()
          .cast<String>();
    } else if (widget.collectionName == 'coffeeprices') {
      fields = ['variety', 'price', 'timestamp'];
    } else {
      fields = firstDocData.keys
          .where((key) => !_excludedFields.contains(key) && key != 'fullName')
          .toList()
          .cast<String>();
    }

    if (fields.isEmpty) {
      fields = ['unknown'];
    }

    if (_sortField.isEmpty || !fields.contains(_sortField)) {
      _sortField = fields.first;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          sortColumnIndex: fields.indexOf(_sortField),
          sortAscending: _sortAscending,
          columns: [
            DataColumn(
              label: Text(
                widget.collectionName == 'coffeeprices'
                    ? 'Variety'
                    : 'Full Name',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...fields.map((field) => DataColumn(
                  label: Text(field,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
            if (widget.collectionName == 'coffeeprices')
              const DataColumn(
                label: Text('Updated By',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            const DataColumn(
              label: Text('Actions',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
          rows: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id;
            return DataRow(cells: [
              if (widget.collectionName == 'coffeeprices')
                DataCell(Text(data['variety'] ?? '-'))
              else
                DataCell(FutureBuilder<String>(
                  future: _fetchUserName(data['userId'] ?? docId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    return Text(snapshot.data ?? '-');
                  },
                )),
              ...fields.map((field) => DataCell(Text(
                    field == 'timestamp' || field == 'interventionFollowUpDate'
                        ? data[field] != null
                            ? _dateFormat
                                .format((data[field] as Timestamp).toDate())
                            : '-'
                        : field == 'price'
                            ? (data[field] as num?)?.toStringAsFixed(2) ?? '-'
                            : data[field]?.toString() ?? '-',
                  ))),
              if (widget.collectionName == 'coffeeprices')
                DataCell(FutureBuilder<String>(
                  future: _fetchUserName(data['updatedBy'] ?? ''),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    return Text(snapshot.data ?? '-');
                  },
                )),
              DataCell(
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editDocument(docId, data);
                        break;
                      case 'delete':
                        _deleteDocument(docId);
                        break;
                      case 'reset':
                        if (data['email'] != null) {
                          _resetPassword(data['email']);
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                    if (['marketmanagers', 'loanmanagers']
                        .contains(widget.collectionName))
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.lock_reset, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Reset Password'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
