import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String? bulkAction;
  List<String> selectedUids = [];

  Future<void> _deleteUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted from Firestore!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      if (email.isEmpty) throw 'Email is required';
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset email sent!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending password reset: $e')));
      }
    }
  }

  Future<void> _messageUser(String uid) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messaging not implemented yet')));
    }
  }

  Future<void> _editUser(String uid, Map<String, dynamic> currentData) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final Map<String, TextEditingController> controllers = {};
    currentData.forEach((key, value) {
      if (key != 'profileImage') {
        controllers[key] = TextEditingController(text: value?.toString() ?? '');
      }
    });

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit User $uid',
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
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
            onPressed: () => Navigator.pop(
                dialogContext,
                controllers
                    .map((key, controller) => MapEntry(key, controller.text))),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(uid)
            .update(result);
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('User updated successfully!')));
      } catch (e) {
        scaffoldMessenger
            .showSnackBar(SnackBar(content: Text('Error updating user: $e')));
      }
    }

    controllers.forEach((_, controller) => controller.dispose());
  }

  void _confirmDeleteUser(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to delete this user? This action cannot be undone.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) {
              setState(() {
                bulkAction = value;
                selectedUids.clear();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Bulk Delete',
                child: Row(
                  children: const [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Bulk Delete'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Bulk Reset Password',
                child: Row(
                  children: const [
                    Icon(Icons.lock_reset, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('Bulk Reset Password'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Bulk Message',
                child: Row(
                  children: const [
                    Icon(Icons.message, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Bulk Message'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Total Users: ${snapshot.data!.docs.length}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('Users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                final users = snapshot.data!.docs;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columns: [
                        if (bulkAction != null)
                          const DataColumn(
                              label: Text('Select',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: Text('Profile',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: Text('Full Name',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: Text('Email',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: Text('County',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: Text('Constituency',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: Text('Ward',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: Text('Phone Number',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: Text('Status',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: Text('Actions',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: users.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final uid = doc.id;
                        return DataRow(cells: [
                          if (bulkAction != null)
                            DataCell(
                              Checkbox(
                                value: selectedUids.contains(uid),
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedUids.add(uid);
                                    } else {
                                      selectedUids.remove(uid);
                                    }
                                  });
                                },
                              ),
                            ),
                          DataCell(
                            data['profileImage'] != null
                                ? Image.memory(
                                    base64Decode(data['profileImage']),
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.person, size: 28),
                          ),
                          DataCell(Text(data['fullName'] ?? 'N/A')),
                          DataCell(Text(data['email'] ?? 'N/A')),
                          DataCell(Text(data['county'] ?? 'N/A')),
                          DataCell(Text(data['constituency'] ?? 'N/A')),
                          DataCell(Text(data['ward'] ?? 'N/A')),
                          DataCell(Text(data['phoneNumber'] ?? 'N/A')),
                          DataCell(Text(data['isDisabled'] == true
                              ? 'Disabled'
                              : 'Active')),
                          DataCell(
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'Delete') {
                                  _confirmDeleteUser(uid);
                                } else if (value == 'Reset Password') {
                                  _resetPassword(data['email'] ?? '');
                                } else if (value == 'Edit') {
                                  _editUser(uid, data);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'Delete',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.delete,
                                          color: Colors.red, size: 20),
                                      SizedBox(width: 8),
                                      Text('Delete User'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'Reset Password',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.lock_reset,
                                          color: Colors.orange, size: 20),
                                      SizedBox(width: 8),
                                      Text('Reset Password'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'Edit',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.edit,
                                          color: Colors.blue, size: 20),
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
                );
              },
            ),
          ),
          if (bulkAction != null && selectedUids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () async {
                  if (bulkAction == 'Bulk Delete') {
                    for (var uid in selectedUids) {
                      await _deleteUser(uid);
                    }
                  } else if (bulkAction == 'Bulk Reset Password') {
                    for (var uid in selectedUids) {
                      final doc = await FirebaseFirestore.instance
                          .collection('Users')
                          .doc(uid)
                          .get();
                      await _resetPassword(doc['email'] ?? '');
                    }
                  } else if (bulkAction == 'Bulk Message') {
                    for (var uid in selectedUids) {
                      await _messageUser(uid);
                    }
                  }
                  setState(() {
                    bulkAction = null;
                    selectedUids.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[700],
                  foregroundColor: Colors.white,
                ),
                child: Text('Execute $bulkAction'),
              ),
            ),
        ],
      ),
    );
  }
}
