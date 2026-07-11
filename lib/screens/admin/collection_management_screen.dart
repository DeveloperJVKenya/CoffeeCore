import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class CollectionManagementScreen extends StatefulWidget {
  final String collectionName;

  const CollectionManagementScreen({required this.collectionName, super.key});

  @override
  State<CollectionManagementScreen> createState() =>
      _CollectionManagementScreenState();
}

class _CollectionManagementScreenState
    extends State<CollectionManagementScreen> {
  String _sortField = '';
  bool _sortAscending = true;
  final logger = Logger(printer: PrettyPrinter());
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy HH:mm');

  Future<Map<String, String>?> _fetchUserName(
      String uid, String sourceCollection) async {
    try {
      final collection = sourceCollection == 'Admins'
          ? 'Admins'
          : sourceCollection == 'CoopAdmins'
              ? 'CoopAdmins'
              : 'Users';
      final userDoc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .get();
      if (userDoc.exists) {
        return {
          'fullName': userDoc['fullName'] ?? 'N/A',
          'email': userDoc['email'] ?? 'N/A'
        };
      }
    } catch (e) {
      logger.e(
          'Error fetching user name for UID $uid from $sourceCollection: $e');
    }
    return {'fullName': 'N/A', 'email': 'N/A'};
  }

  Future<void> _deleteDocument(String docId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm Deletion',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content:
              const Text('Are you sure you want to soft delete this document?'),
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
        await FirebaseFirestore.instance
            .collection(widget.collectionName)
            .doc(docId)
            .update({
          'isDeleted': true,
          'deletedAt': Timestamp.now(),
        });
        await _logActivity('soft_delete', widget.collectionName, docId);
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Document soft deleted!')));
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error soft deleting document: $e')));
      }
    }
  }

  Future<void> _restoreDocument(String docId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(docId)
          .update({
        'isDeleted': false,
        'deletedAt': null,
      });
      await _logActivity('restore', widget.collectionName, docId);
      scaffoldMessenger
          .showSnackBar(const SnackBar(content: Text('Document restored!')));
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error restoring document: $e')));
      }
    }
  }

  Future<void> _editDocument(
      String docId, Map<String, dynamic> currentData) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final Map<String, TextEditingController> controllers = {};
    DateTime? interventionFollowUpDate;

    // Define fields for coffee_soil_data
    final coffeeSoilFields = [
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
    ];

    if (widget.collectionName == 'coffee_soil_data') {
      interventionFollowUpDate = currentData['interventionFollowUpDate'] != null
          ? (currentData['interventionFollowUpDate'] as Timestamp).toDate()
          : null;
      for (var field in coffeeSoilFields) {
        controllers[field] =
            TextEditingController(text: currentData[field]?.toString() ?? '');
      }
    } else {
      currentData.forEach((key, value) {
        if (!_excludedFields.contains(key) &&
            key != 'fullName' &&
            key != 'timestamp') {
          controllers[key] =
              TextEditingController(text: value?.toString() ?? '');
        }
      });
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Document $docId',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.collectionName == 'coffee_soil_data') ...[
                ...coffeeSoilFields.map((field) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextField(
                        controller: controllers[field]!,
                        decoration: InputDecoration(
                          labelText: field,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: [
                          'ph',
                          'nitrogen',
                          'phosphorus',
                          'potassium',
                          'magnesium',
                          'calcium'
                        ].contains(field)
                            ? TextInputType.number
                            : TextInputType.text,
                      ),
                    )),
                ListTile(
                  title: Text(
                      'Intervention Follow-Up: ${interventionFollowUpDate?.toString().substring(0, 10) ?? 'N/A'}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: interventionFollowUpDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      interventionFollowUpDate = picked;
                    }
                  },
                ),
              ] else ...[
                ...controllers.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: entry.key,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )),
              ],
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
        final updateData = <String, dynamic>{};
        result.forEach((key, value) {
          if (widget.collectionName == 'coffee_soil_data' &&
              [
                'ph',
                'nitrogen',
                'phosphorus',
                'potassium',
                'magnesium',
                'calcium'
              ].contains(key)) {
            updateData[key] = value.isNotEmpty ? double.tryParse(value) : null;
          } else {
            updateData[key] = value.isNotEmpty ? value : null;
          }
        });
        if (widget.collectionName == 'coffee_soil_data' &&
            interventionFollowUpDate != null) {
          updateData['interventionFollowUpDate'] =
              Timestamp.fromDate(interventionFollowUpDate!);
        }
        await FirebaseFirestore.instance
            .collection(widget.collectionName)
            .doc(docId)
            .update(updateData);
        await _logActivity('edit', widget.collectionName, docId);
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Document updated successfully!')));
      } catch (e) {
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error updating document: $e')));
      }
    }

    controllers.forEach((_, controller) => controller.dispose());
  }

  Future<void> _logActivity(
      String action, String collection, String docId) async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      final adminDoc = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(adminUid)
          .get();
      final adminName = adminDoc.exists ? adminDoc['fullName'] ?? 'N/A' : 'N/A';
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'action': '$action in $collection ($docId) by (User: $adminName)',
        'collection': collection,
        'documentId': docId,
        'timestamp': Timestamp.now(),
        'adminUid': adminUid,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

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

  @override
  Widget build(BuildContext context) {
    bool isCoopCollection = widget.collectionName.contains('_users') ||
        widget.collectionName.contains('_marketmanagers') ||
        widget.collectionName.contains('_coffeeprices');
    String baseCollection = widget.collectionName.contains('_coffeeprices')
        ? 'coffeeprices'
        : widget.collectionName;
    String nameSourceCollection = widget.collectionName == 'admin_logs'
        ? 'Admins'
        : widget.collectionName == 'cooperatives'
            ? 'CoopAdmins'
            : 'Users';

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${widget.collectionName}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(widget.collectionName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No documents found.'));
          }

          final docs = snapshot.data!.docs;
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
          } else if (widget.collectionName == 'User_logs') {
            fields = ['action', 'details', 'collection', 'timestamp'];
          } else if (widget.collectionName == 'admin_logs') {
            fields = ['action', 'collection', 'timestamp'];
          } else if (widget.collectionName == 'cooperatives') {
            fields = ['name', 'timestamp'];
          } else if (widget.collectionName.contains('_coffeeprices')) {
            fields = ['variety', 'price', 'timestamp'];
          } else {
            fields = firstDocData.keys
                .where((key) =>
                    !_excludedFields.contains(key) && key != 'fullName')
                .toList()
                .cast<String>();
          }

          if (fields.isEmpty) {
            fields = ['unknown'];
          }

          if (_sortField.isEmpty || !fields.contains(_sortField)) {
            _sortField = fields.first;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text('Sort by: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _sortField,
                      items: fields
                          .map((field) => DropdownMenuItem(
                              value: field, child: Text(field)))
                          .toList(),
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
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _processDocuments(docs, isCoopCollection,
                      baseCollection, nameSourceCollection),
                  builder: (context, futureSnapshot) {
                    if (futureSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (futureSnapshot.hasError) {
                      return Center(
                          child: Text('Error: ${futureSnapshot.error}'));
                    }

                    final dataRows = futureSnapshot.data ?? [];
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
                                    isCoopCollection &&
                                            baseCollection != 'coffeeprices'
                                        ? 'Full Name'
                                        : 'Name',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                            ...fields.map((field) => DataColumn(
                                label: Text(field,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)))),
                            const DataColumn(
                                label: Text('Actions',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                          rows: dataRows.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            final docId = docs[index].id;
                            final isDeleted = data['isDeleted'] == true;
                            return DataRow(cells: [
                              DataCell(Text(data['fullName'] ??
                                  data['displayName'] ??
                                  'N/A')),
                              ...fields.map((field) => DataCell(Text(
                                    field == 'timestamp' ||
                                            field == 'createdAt' ||
                                            field == 'updatedAt' ||
                                            field == 'deletedAt' ||
                                            field == 'interventionFollowUpDate'
                                        ? data[field] != null
                                            ? _dateFormat.format(
                                                (data[field] as Timestamp)
                                                    .toDate())
                                            : 'N/A'
                                        : data[field]?.toString() ?? 'N/A',
                                  ))),
                              DataCell(
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'Edit' && !isDeleted) {
                                      _editDocument(docId, data);
                                    } else if (value == 'Delete' &&
                                        !isDeleted) {
                                      _deleteDocument(docId);
                                    } else if (value == 'Restore' &&
                                        isDeleted) {
                                      _restoreDocument(docId);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'Edit',
                                      enabled: !isDeleted,
                                      child: Row(
                                        children: const [
                                          Icon(Icons.edit,
                                              color: Colors.blue, size: 20),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Delete',
                                      enabled: !isDeleted,
                                      child: Row(
                                        children: const [
                                          Icon(Icons.delete,
                                              color: Colors.red, size: 20),
                                          SizedBox(width: 8),
                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Restore',
                                      enabled: isDeleted,
                                      child: Row(
                                        children: const [
                                          Icon(Icons.restore,
                                              color: Colors.green, size: 20),
                                          SizedBox(width: 8),
                                          Text('Restore'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_vert),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _processDocuments(
      List<QueryDocumentSnapshot> docs,
      bool isCoopCollection,
      String baseCollection,
      String nameSourceCollection) async {
    List<Map<String, dynamic>> processedData = [];
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      Map<String, dynamic> rowData = Map.from(data);

      if (widget.collectionName == 'User_logs') {
        final userInfo = await _fetchUserName(data['userId'] ?? '', 'Users');
        rowData['fullName'] = userInfo?['fullName'] ?? 'N/A';
      } else if (widget.collectionName == 'admin_logs') {
        final userInfo = await _fetchUserName(data['adminUid'] ?? '', 'Admins');
        rowData['fullName'] = userInfo?['fullName'] ?? 'N/A';
      } else if ([
        'coffee_disease_interventions',
        'coffee_pest_interventions',
        'coffee_soil_data'
      ].contains(widget.collectionName)) {
        final userInfo = await _fetchUserName(data['userId'] ?? '', 'Users');
        rowData['fullName'] = userInfo?['fullName'] ?? 'N/A';
      } else if (widget.collectionName == 'cooperatives') {
        final userInfo =
            await _fetchUserName(data['createdBy'] ?? '', 'CoopAdmins');
        rowData['fullName'] = userInfo?['fullName'] ?? 'N/A';
      } else if (isCoopCollection && baseCollection == 'coffeeprices') {
        final userInfo = await _fetchUserName(data['updatedBy'] ?? '', 'Users');
        rowData['fullName'] = userInfo?['fullName'] ?? 'N/A';
      } else if (isCoopCollection &&
          (baseCollection.contains('_users') ||
              baseCollection.contains('_marketmanagers'))) {
        final userInfo = await _fetchUserName(doc.id, 'Users');
        rowData['fullName'] = userInfo?['fullName'] ?? 'N/A';
      } else {
        rowData['fullName'] = rowData['fullName'] ?? doc.id;
      }

      processedData.add(rowData);
    }
    return processedData;
  }
}
