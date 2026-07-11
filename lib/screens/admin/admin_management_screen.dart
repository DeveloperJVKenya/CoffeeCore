import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/admin/manage_users_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:coffeecore/screens/admin/filter_users_screen.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/admin/collection_management_screen.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final logger = Logger(printer: PrettyPrinter());
  final TextEditingController _uidController = TextEditingController();
  List<String> _allCollections = [];

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    try {
      List<String> collections = [
        'Users',
        'Admins',
        'CoopAdmins',
        'User_logs',
        'admin_logs',
        'coffee_disease_interventions',
        'coffee_pest_interventions',
        'coffee_soil_data',
        'cooperatives',
      ];

      final coopSnapshot =
          await FirebaseFirestore.instance.collection('cooperatives').get();
      for (var doc in coopSnapshot.docs) {
        final coopName = doc.id.replaceAll(' ', '_');
        collections.addAll([
          '${coopName}_users',
          '${coopName}_marketmanagers',
          '${coopName}_coffeeprices',
        ]);
      }

      setState(() {
        _allCollections = collections;
      });
    } catch (e) {
      logger.e('Error fetching collections: $e');
    }
  }

  Future<void> _assignRole(String uid, String collection) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (!userDoc.exists) throw 'User not found';

      final userData = userDoc.data() as Map<String, dynamic>;
      final roleData = {
        'fullName': userData['fullName'] ?? '',
        'county': userData['county'] ?? '',
        'constituency': userData['constituency'] ?? '',
        'ward': userData['ward'] ?? '',
        'phoneNumber': userData['phoneNumber'] ?? '',
        'email': userData['email'] ?? '',
        'isDisabled': userData['isDisabled'] ?? false,
      };

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .set(roleData);
      await _logActivity(
          'Assigned $collection role to $uid (User: ${userData['fullName']})');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${collection.replaceAll('s', '')} role assigned successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error assigning role: $e')));
      }
    }
  }

  Future<void> _logActivity(String action) async {
    try {
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'action': action,
        'timestamp': Timestamp.now(),
        'adminUid': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCollectionStats(),
              const SizedBox(height: 20),
              _buildManagementOptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionStats() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collection Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_allCollections.isEmpty)
              const CircularProgressIndicator()
            else
              ..._allCollections
                  .map((collection) => StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection(collection)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          final count = snapshot.data?.docs.length ?? 0;
                          return ListTile(
                            title: Text(collection,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            trailing: Text('$count',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.brown)),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => collection == 'Users'
                                    ? const ManageUsersScreen()
                                    : CollectionManagementScreen(
                                        collectionName: collection),
                              ),
                            ),
                          );
                        },
                      )),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementOptions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildOptionCard('Assign User Role', Icons.person_add,
            () => _showRoleSelectionDialog()),
        _buildOptionCard(
            'Filter Users',
            Icons.filter_list,
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FilterUsersScreen()))),
      ],
    );
  }

  Widget _buildOptionCard(String title, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: onTap == null ? Colors.grey[300] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.brown[700]),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign User Role',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAssignRoleDialog('Admins');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Assign Admin Role'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAssignRoleDialog('CoopAdmins');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Assign Co-op Admin Role'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAssignRoleDialog(String collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign ${collection.replaceAll('s', '')} Role',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _uidController,
                decoration: InputDecoration(
                  labelText: 'Enter User UID',
                  hintText: 'e.g., abc123xyz789',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showUserListDialog(),
              tooltip: 'Select User',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_uidController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a UID')));
                return;
              }
              _assignRole(_uidController.text, collection);
              Navigator.pop(context);
              _uidController.clear();
            },
            child: const Text('Assign.'),
          ),
        ],
      ),
    );
  }

  void _showUserListDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select User',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No users found.');
              }
              final users = snapshot.data!.docs;
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index].data() as Map<String, dynamic>;
                  final uid = users[index].id;
                  return ListTile(
                    title: Text(user['fullName'] ?? 'No Name'),
                    subtitle: Text('Email: ${user['email'] ?? 'N/A'}'),
                    onTap: () {
                      _uidController.text = uid;
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
