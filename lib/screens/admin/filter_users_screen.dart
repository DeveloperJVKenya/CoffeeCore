import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class FilterUsersScreen extends StatefulWidget {
  const FilterUsersScreen({super.key});

  @override
  State<FilterUsersScreen> createState() => _FilterUsersScreenState();
}

class _FilterUsersScreenState extends State<FilterUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final logger = Logger(printer: PrettyPrinter());
  String _searchQuery = '';
  String _sortField = 'fullName';
  bool _sortAscending = true;
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  List<String> selectedFields = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _showSuggestions = _searchQuery.isNotEmpty;
      _updateSuggestions();
    });
  }

  Future<void> _updateSuggestions() async {
    try {
      final collections = await _getAllCollections();
      Set<String> suggestions = {};
      for (var collection in collections) {
        final snapshot = await FirebaseFirestore.instance.collection(collection).get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          suggestions.addAll(data.entries
              .where((e) => e.value is String)
              .map((e) => e.value.toString().toLowerCase()));
        }
      }
      _suggestions = suggestions
          .where((s) => s.isNotEmpty && s.contains(_searchQuery))
          .toList()
          .take(10)
          .toList();
      setState(() {});
    } catch (e) {
      logger.e('Error updating suggestions: $e');
    }
  }

  Future<List<String>> _getAllCollections() async {
    List<String> collections = [
      'Users',
      'Admins',
      'CoopAdmins',
    ];
    final coopSnapshot = await FirebaseFirestore.instance.collection('cooperatives').get();
    for (var doc in coopSnapshot.docs) {
      final coopName = doc.id.replaceAll(' ', '_');
      collections.addAll(['${coopName}_users', '${coopName}_marketmanagers']);
    }
    return collections;
  }

  Future<List<Map<String, dynamic>>> _fetchMergedUserData() async {
    final collections = await _getAllCollections();
    Map<String, Map<String, dynamic>> mergedUsers = {};

    for (var collection in collections) {
      final snapshot = await FirebaseFirestore.instance.collection(collection).get();
      for (var doc in snapshot.docs) {
        final uid = doc.id;
        final data = doc.data();
        if (!mergedUsers.containsKey(uid)) {
          mergedUsers[uid] = {'uid': uid};
        }
        if (collection == 'Users') {
          mergedUsers[uid]!.addAll({
            'fullName': data['fullName'] ?? 'N/A',
            'email': data['email'] ?? 'N/A',
            'county': data['county'] ?? 'N/A',
            'constituency': data['constituency'] ?? 'N/A',
            'ward': data['ward'] ?? 'N/A',
            'phoneNumber': data['phoneNumber'] ?? 'N/A',
            'isDisabled': data['isDisabled'] ?? false,
          });
        }
        String role = collection == 'Admins'
            ? 'Admin'
            : collection == 'CoopAdmins'
                ? 'CoopAdmin'
                : collection.contains('_marketmanagers')
                    ? 'MarketManager'
                    : collection.contains('_users')
                        ? 'CoopUser'
                        : 'User';
        mergedUsers[uid]!['role'] = role;
      }
    }

    return mergedUsers.values.toList();
  }

  Future<void> _downloadExcel(List<Map<String, dynamic>> filteredUsers) async {
    try {
      String outputPath = '/storage/emulated/0/Download';
      if (Platform.isAndroid) {
        outputPath = '/storage/emulated/0/Download';
      } else if (Platform.isIOS) {
        outputPath = (await getApplicationDocumentsDirectory()).path;
      }

      var excel = Excel.createExcel();
      Sheet sheet = excel['Users'];

      List<String> headers = selectedFields.isEmpty
          ? ['Full Name', 'Email', 'County', 'Constituency', 'Ward', 'Phone Number', 'Status', 'Role']
          : selectedFields;
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (var user in filteredUsers) {
        List<TextCellValue> row = [];
        for (var header in headers) {
          row.add(TextCellValue(user[header.toLowerCase()]?.toString() ?? 'N/A'));
        }
        sheet.appendRow(row);
      }

      String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      String fileName = 'Filtered_Users_$timestamp.xlsx';
      String fullPath = '$outputPath/$fileName';

      File excelFile = File(fullPath);
      await excelFile.create(recursive: true);
      await excelFile.writeAsBytes(excel.encode()!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel saved to Downloads: $fileName'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () async {
                try {
                  final box = context.findRenderObject() as RenderBox?;
                  final shareParams = ShareParams(
                    files: [XFile(fullPath)],
                    text: 'Filtered Users Export: $fileName',
                    // Include sharePositionOrigin only if box is non-null and on iOS
                    sharePositionOrigin: (box != null && Platform.isIOS)
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null,
                  );
                  await SharePlus.instance.share(shareParams);
                } catch (e) {
                  logger.e('Error sharing file: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error sharing file: $e')),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      logger.e('Error downloading Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving Excel: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Filter Users',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by any field',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_showSuggestions && _suggestions.isNotEmpty)
                  Positioned(
                    top: 56,
                    left: 0,
                    right: 0,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(_suggestions[index]),
                              onTap: () {
                                _searchController.text = _suggestions[index];
                                _searchQuery = _suggestions[index].toLowerCase();
                                _showSuggestions = false;
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchMergedUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                logger.e('Error fetching merged data: ${snapshot.error}');
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No users found.'));
              }

              final allUsers = snapshot.data!;
              final filteredUsers = _searchQuery.isEmpty
                  ? allUsers
                  : allUsers.where((user) {
                      return user.values.any((value) =>
                          value.toString().toLowerCase().contains(_searchQuery));
                    }).toList();

              Set<String> allFields = {
                'fullName',
                'email',
                'county',
                'constituency',
                'ward',
                'phoneNumber',
                'isDisabled',
                'role',
              };
              List<String> fields = allFields.toList()..sort();

              if (_sortField.isEmpty || !fields.contains(_sortField)) {
                _sortField = 'fullName';
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${filteredUsers.length} user${filteredUsers.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: filteredUsers.isEmpty
                              ? null
                              : () => _showFieldSelectionDialog(fields, filteredUsers),
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: const Text('Export to Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Text('Sort by: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          value: _sortField,
                          items: fields
                              .map((field) => DropdownMenuItem(value: field, child: Text(field)))
                              .toList(),
                          onChanged: (value) => setState(() => _sortField = value!),
                          style: const TextStyle(color: Colors.black),
                        ),
                        IconButton(
                          icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                          onPressed: () => setState(() => _sortAscending = !_sortAscending),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          sortColumnIndex: fields.indexOf(_sortField),
                          sortAscending: _sortAscending,
                          columns: [
                            DataColumn(
                                label: Text('Full Name',
                                    style: const TextStyle(fontWeight: FontWeight.bold))),
                            ...fields
                                .where((field) => field != 'fullName')
                                .map((field) => DataColumn(
                                    label: Text(field,
                                        style: const TextStyle(fontWeight: FontWeight.bold)))),
                            const DataColumn(
                                label: Text('Actions',
                                    style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filteredUsers.map((user) {
                            return DataRow(cells: [
                              DataCell(Text(user['fullName'] ?? 'N/A')),
                              ...fields
                                  .where((field) => field != 'fullName')
                                  .map((field) => DataCell(Text(
                                        field == 'isDisabled'
                                            ? user[field] == true
                                                ? 'Disabled'
                                                : 'Active'
                                            : user[field]?.toString() ?? 'N/A',
                                      ))),
                              DataCell(
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'Edit') {
                                      _editUser(user['uid'], user);
                                    } else if (value == 'Delete') {
                                      _confirmDeleteUser(user['uid']);
                                    } else if (value == 'Reset Password') {
                                      _resetPassword(user['email'] ?? '');
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'Delete',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.delete, color: Colors.red, size: 20),
                                          SizedBox(width: 8),
                                          Text('Delete User'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Reset Password',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.lock_reset, color: Colors.orange, size: 20),
                                          SizedBox(width: 8),
                                          Text('Reset Password'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Edit',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.edit, color: Colors.blue, size: 20),
                                          SizedBox(width: 8),
                                          Text('Edit'),
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
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editUser(String uid, Map<String, dynamic> currentData) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final Map<String, TextEditingController> controllers = {};
    currentData.forEach((key, value) {
      if (key != 'uid' && key != 'profileImage' && key != 'role') {
        controllers[key] = TextEditingController(text: value?.toString() ?? '');
      }
    });

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit User $uid', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(
                  controller: entry.value,
                  decoration: InputDecoration(
                    labelText: entry.key,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controllers.map((key, controller) => MapEntry(key, controller.text))),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        await FirebaseFirestore.instance.collection('Users').doc(uid).update(result);
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('User updated successfully!')));
      } catch (e) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error updating user: $e')));
      }
    }

    controllers.forEach((_, controller) => controller.dispose());
  }

  Future<void> _resetPassword(String email) async {
    try {
      if (email.isEmpty) throw 'Email is required';
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending password reset: $e')));
      }
    }
  }

  void _confirmDeleteUser(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteUser(uid);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted from Firestore!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
      }
    }
  }

  void _showFieldSelectionDialog(List<String> fields, List<Map<String, dynamic>> filteredUsers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Fields to Export', style: TextStyle(fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView(
              children: fields.map((field) => CheckboxListTile(
                    title: Text(field),
                    value: selectedFields.contains(field),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          selectedFields.add(field);
                        } else {
                          selectedFields.remove(field);
                        }
                      });
                    },
                  )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadExcel(filteredUsers);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }
}