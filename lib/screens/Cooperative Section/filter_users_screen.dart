import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/utils/excel_utils.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/utils/role_utils.dart';

class FilterUsersScreen extends StatefulWidget {
  final String cooperativeName;

  const FilterUsersScreen({super.key, required this.cooperativeName});

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _triggerIndexCreation();
  }

  Future<void> _triggerIndexCreation() async {
    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
    const fields = [
      'fullName',
      'email',
      'county',
      'constituency',
      'ward',
    ];
    for (final field in fields) {
      try {
        await FirebaseFirestore.instance
            .collection('${formattedCoopName}_users')
            .orderBy(field, descending: false)
            .limit(1)
            .get();
      } catch (e) {
        logger.w('Index needed for ${formattedCoopName}_users.$field (Ascending): $e');
      }
      try {
        await FirebaseFirestore.instance
            .collection('${formattedCoopName}_users')
            .orderBy(field, descending: true)
            .limit(1)
            .get();
      } catch (e) {
        logger.w('Index needed for ${formattedCoopName}_users.$field (Descending): $e');
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _showSuggestions = _searchQuery.isNotEmpty;
      _updateSuggestions();
    });
  }

  Future<void> _updateSuggestions() async {
    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_users')
          .get();
      final marketManagerSnapshot = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_marketmanagers')
          .get();
      final loanManagerSnapshot = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_loanmanagers')
          .get();

      Set<String> suggestions = {};
      for (var doc in userSnapshot.docs) {
        final data = doc.data();
        suggestions.addAll([
          data['fullName']?.toString().toLowerCase() ?? '',
          data['email']?.toString().toLowerCase() ?? '',
          data['county']?.toString().toLowerCase() ?? '',
          data['constituency']?.toString().toLowerCase() ?? '',
          data['ward']?.toString().toLowerCase() ?? '',
          data['phoneNumber']?.toString().toLowerCase() ?? '',
        ]);
      }
      for (var doc in marketManagerSnapshot.docs) {
        final data = doc.data();
        suggestions.addAll([
          data['fullName']?.toString().toLowerCase() ?? '',
          data['email']?.toString().toLowerCase() ?? '',
          data['county']?.toString().toLowerCase() ?? '',
          data['constituency']?.toString().toLowerCase() ?? '',
          data['ward']?.toString().toLowerCase() ?? '',
          data['phoneNumber']?.toString().toLowerCase() ?? '',
        ]);
      }
      for (var doc in loanManagerSnapshot.docs) {
        final data = doc.data();
        suggestions.addAll([
          data['fullName']?.toString().toLowerCase() ?? '',
          data['email']?.toString().toLowerCase() ?? '',
          data['county']?.toString().toLowerCase() ?? '',
          data['constituency']?.toString().toLowerCase() ?? '',
          data['ward']?.toString().toLowerCase() ?? '',
          data['phoneNumber']?.toString().toLowerCase() ?? '',
        ]);
      }
      _suggestions = suggestions
          .where((s) => s.isNotEmpty && s.contains(_searchQuery))
          .toList()
          .take(10)
          .toList();
      setState(() {});
    } catch (e) {
      logger.e('Error updating suggestions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading suggestions: $e')),
        );
      }
    }
  }

  Future<void> _downloadExcel(List<Map<String, dynamic>> filteredUsers) async {
    try {
      // Define headers
      List<String> headers = [
        'Full Name',
        'Email',
        'County',
        'Constituency',
        'Ward',
        'Phone Number',
        'Role',
        'Status',
      ];

      // Prepare data
      List<Map<String, dynamic>> exportData = filteredUsers.map((user) {
        return {
          'fullName': user['fullName']?.toString() ?? 'N/A',
          'email': user['email']?.toString() ?? 'N/A',
          'county': user['county']?.toString() ?? 'N/A',
          'constituency': user['constituency']?.toString() ?? 'N/A',
          'ward': user['ward']?.toString() ?? 'N/A',
          'phoneNumber': user['phoneNumber']?.toString() ?? 'N/A',
          'role': user['role']?.toString() ?? 'User',
          'status': user['isDisabled'] == true ? 'Disabled' : 'Active',
        };
      }).toList();

      // Generate file name with timestamp
      String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      String fileName = 'Filtered_Users_$timestamp.xlsx';

      // Call ExcelUtils to generate and share the Excel file, but only if mounted
      if (mounted) {
        await ExcelUtils.downloadExcel(
          context: context,
          data: exportData,
          headers: headers,
          fileName: fileName,
          shareText: 'Filtered Users Export: $fileName',
          logger: logger,
          sheetName: 'Users',
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
    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
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
                    labelText: 'Search by any field (e.g., Name, Ward)',
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('${formattedCoopName}_users')
                  .orderBy(_sortField, descending: !_sortAscending)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (userSnapshot.hasError) {
                  logger.e('Error in user snapshot: ${userSnapshot.error}');
                  return Center(child: Text('Error: ${userSnapshot.error}'));
                }
                if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('${formattedCoopName}_marketmanagers')
                      .snapshots(),
                  builder: (context, marketManagerSnapshot) {
                    if (marketManagerSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (marketManagerSnapshot.hasError) {
                      logger.e('Error in market manager snapshot: ${marketManagerSnapshot.error}');
                      return Center(child: Text('Error: ${marketManagerSnapshot.error}'));
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('${formattedCoopName}_loanmanagers')
                          .snapshots(),
                      builder: (context, loanManagerSnapshot) {
                        if (loanManagerSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (loanManagerSnapshot.hasError) {
                          logger.e('Error in loan manager snapshot: ${loanManagerSnapshot.error}');
                          return Center(child: Text('Error: ${loanManagerSnapshot.error}'));
                        }

                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _buildUserList(
                            userSnapshot.data!.docs,
                            marketManagerSnapshot.data,
                            loanManagerSnapshot.data,
                          ),
                          builder: (context, futureSnapshot) {
                            if (futureSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (futureSnapshot.hasError) {
                              logger.e('Error in future snapshot: ${futureSnapshot.error}');
                              return Center(child: Text('Error: ${futureSnapshot.error}'));
                            }
                            if (!futureSnapshot.hasData || futureSnapshot.data!.isEmpty) {
                              return const Center(child: Text('No users found.'));
                            }

                            final users = futureSnapshot.data!;
                            final filteredUsers = _searchQuery.isEmpty
                                ? users
                                : users.where((user) {
                                    return user.values.any((value) =>
                                        value.toString().toLowerCase().contains(_searchQuery));
                                  }).toList();

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
                                            : () => _downloadExcel(filteredUsers),
                                        icon: const Icon(Icons.download, color: Colors.white),
                                        label: const Text('Export to Excel'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.brown[700],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
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
                                        items: const [
                                          DropdownMenuItem(value: 'fullName', child: Text('Full Name')),
                                          DropdownMenuItem(value: 'email', child: Text('Email')),
                                          DropdownMenuItem(value: 'county', child: Text('County')),
                                          DropdownMenuItem(value: 'constituency', child: Text('Constituency')),
                                          DropdownMenuItem(value: 'ward', child: Text('Ward')),
                                        ],
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
                                  child: filteredUsers.isEmpty
                                      ? const Center(child: Text('No users match your search.'))
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.vertical,
                                            child: DataTable(
                                              sortColumnIndex: [
                                                'fullName',
                                                'email',
                                                'county',
                                                'constituency',
                                                'ward',
                                              ].indexOf(_sortField),
                                              sortAscending: _sortAscending,
                                              columns: const [
                                                DataColumn(
                                                    label: Text('Full Name',
                                                        style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(
                                                    label: Text('Email',
                                                        style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(
                                                    label: Text('County',
                                                        style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(
                                                    label: Text('Constituency',
                                                        style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(
                                                    label: Text('Ward',
                                                        style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(
                                                    label: Text('Phone Number',
                                                        style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(
                                                    label: Text('Role',
                                                        style: TextStyle(fontWeight: FontWeight.bold))),
                                                DataColumn(
                                                    label: Text('Status',
                                                        style: TextStyle(fontWeight: FontWeight.bold))),
                                              ],
                                              rows: filteredUsers.map((user) {
                                                return DataRow(cells: [
                                                  DataCell(Text(user['fullName'])),
                                                  DataCell(Text(user['email'])),
                                                  DataCell(Text(user['county'])),
                                                  DataCell(Text(user['constituency'])),
                                                  DataCell(Text(user['ward'])),
                                                  DataCell(Text(user['phoneNumber'])),
                                                  DataCell(Text(user['role'])),
                                                  DataCell(
                                                      Text(user['isDisabled'] ? 'Disabled' : 'Active')),
                                                ]);
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _buildUserList(
      List<QueryDocumentSnapshot> userDocs,
      QuerySnapshot? marketManagerSnapshot,
      QuerySnapshot? loanManagerSnapshot) async {
    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
    List<Map<String, dynamic>> users = [];

    // Get Market Manager UIDs
    Set<String> marketManagerUids = {};
    if (marketManagerSnapshot != null) {
      for (var doc in marketManagerSnapshot.docs) {
        marketManagerUids.add(doc.id);
        logger.i('Found Market Manager UID: ${doc.id}');
      }
    } else {
      logger.w('Market Manager snapshot is null for $formattedCoopName');
    }

    // Get Loan Manager UIDs
    Set<String> loanManagerUids = {};
    if (loanManagerSnapshot != null) {
      for (var doc in loanManagerSnapshot.docs) {
        loanManagerUids.add(doc.id);
        logger.i('Found Loan Manager UID: ${doc.id}');
      }
    } else {
      logger.w('Loan Manager snapshot is null for $formattedCoopName');
    }

    for (var doc in userDocs) {
      final data = doc.data() as Map<String, dynamic>;
      String role = 'User'; // Default role

      // Check if user is a Market Manager
      if (marketManagerUids.contains(doc.id)) {
        role = 'Market Manager';
        logger.i('Assigned Market Manager role to UID: ${doc.id} based on marketManagerUids');
      }
      // Check if user is a Loan Manager
      else if (loanManagerUids.contains(doc.id)) {
        role = 'Loan Manager';
        logger.i('Assigned Loan Manager role to UID: ${doc.id} based on loanManagerUids');
      }
      // Check for Coop Admin or Main Admin roles
      else {
        try {
          String fetchedRole = await RoleUtils.getUserRole(doc.id, widget.cooperativeName);
          if (fetchedRole == 'Coop Admin' || fetchedRole == 'Main Admin') {
            role = fetchedRole;
            logger.i('Assigned $role to UID: ${doc.id} based on RoleUtils');
          }
        } catch (e) {
          logger.e('Error getting role for UID ${doc.id}: $e');
          // Keep role as User if no other role is assigned
        }
      }

      users.add({
        'uid': doc.id,
        'fullName': data['fullName'] ?? 'N/A',
        'email': data['email'] ?? 'N/A',
        'county': data['county'] ?? 'N/A',
        'constituency': data['constituency'] ?? 'N/A',
        'ward': data['ward'] ?? 'N/A',
        'phoneNumber': data['phoneNumber'] ?? 'N/A',
        'role': role,
        'isDisabled': data['isDisabled'] ?? false,
      });
    }

    return users;
  }
}