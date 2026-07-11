import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';
import 'package:coffeecore/screens/Cooperative%20Section/user_management_screen.dart';
import 'package:coffeecore/screens/learn_coffee_farming.dart';
import 'package:coffeecore/screens/manuals_screen.dart';
import 'package:coffeecore/screens/Farm%20Management/screens/farm_management_home_screen.dart';
import 'package:coffeecore/screens/Cooperative%20Section/coop_collection_management_screen.dart';

class CoopAdminManagementScreen extends StatefulWidget {
  const CoopAdminManagementScreen({super.key});

  @override
  State<CoopAdminManagementScreen> createState() =>
      _CoopAdminManagementScreenState();
}

class _CoopAdminManagementScreenState extends State<CoopAdminManagementScreen> {
  final Logger logger = Logger(printer: PrettyPrinter());
  final TextEditingController _coopNameController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();
  String? _cooperativeName;
  String? _userId;
  final Map<String, String> _collectionDisplayNames = {
    'users': 'Users',
    'marketmanagers': 'Market Managers',
    //'loanmanagers': 'Loan Managers',
    'coffeeprices': 'Coffee Prices',
    'coffee_disease_interventions': 'Disease Data',
    'coffee_pest_interventions': 'Pest Data',
    'coffee_soil_data': 'Soil Data',
  };
  final List<String> _allCollections = [
    'users',
    'marketmanagers',
    //'loanmanagers',
    'coffeeprices',
    'coffee_disease_interventions',
    'coffee_pest_interventions',
    'coffee_soil_data',
  ];
  final List<String> _globalCollections = [
    'coffee_disease_interventions',
    'coffee_pest_interventions',
    'coffee_soil_data',
  ];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _checkCoopName();
  }

  Future<void> _checkCoopName() async {
    try {
      DocumentSnapshot coopAdminDoc = await FirebaseFirestore.instance
          .collection('CoopAdmins')
          .doc(_userId)
          .get();
      if (!coopAdminDoc.exists ||
          !coopAdminDoc.data().toString().contains('cooperative')) {
        if (mounted) {
          _showCreateCoopDialog();
        }
        return;
      }
      String assignedCoop = coopAdminDoc['cooperative'].replaceAll('_', ' ');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('cooperative_name_$_userId', assignedCoop);
      setState(() {
        _cooperativeName = assignedCoop;
      });
    } catch (e) {
      logger.e('Error checking cooperative name: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cooperative: $e')),
        );
      }
    }
  }

  Future<void> _showCreateCoopDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Create Cooperative',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _coopNameController,
          decoration: InputDecoration(
            labelText: 'Cooperative Name',
            hintText: 'e.g., Green Valley Coffee',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_coopNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a cooperative name')),
                );
                return;
              }
              _createCooperative(_coopNameController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCooperative(String coopName) async {
    try {
      String formattedCoopName = coopName.replaceAll(' ', '_');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('cooperative_name_$_userId', coopName);

      await FirebaseFirestore.instance
          .collection('cooperatives')
          .doc(formattedCoopName)
          .set({
        'name': coopName,
        'createdBy': _userId,
        'timestamp': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('CoopAdmins')
          .doc(_userId)
          .set({
        'cooperative': formattedCoopName,
        'uid': _userId,
      }, SetOptions(merge: true));

      setState(() {
        _cooperativeName = coopName;
      });
      logger.i('Cooperative $coopName created for user $_userId');
    } catch (e) {
      logger.e('Error creating cooperative: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating cooperative: $e')),
        );
      }
    }
  }

  Future<void> _assignUserRole(String uid, String role) async {
    if (_cooperativeName == null) return;
    try {
      String formattedCoopName = _cooperativeName!.replaceAll(' ', '_');
      final userDoc = await FirebaseFirestore.instance
          .collection('${formattedCoopName}_users')
          .doc(uid)
          .get();
      if (!userDoc.exists) throw 'User not found in this cooperative';
      final userData = userDoc.data() as Map<String, dynamic>;

      String collection =
          role == 'Market Manager' ? 'marketmanagers' : 'loanmanagers';
      await FirebaseFirestore.instance
          .collection('${formattedCoopName}_$collection')
          .doc(uid)
          .set({
        'fullName': userData['fullName'] ?? '',
        'county': userData['county'] ?? '',
        'constituency': userData['constituency'] ?? '',
        'ward': userData['ward'] ?? '',
        'phoneNumber': userData['phoneNumber'] ?? '',
        'email': userData['email'] ?? '',
        'uid': uid,
      });
      await _logActivity(
          'Assigned $role role to $uid in cooperative $_cooperativeName');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$role assigned successfully!')),
        );
      }
    } catch (e) {
      logger.e('Error assigning $role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning $role: $e')),
        );
      }
    }
  }

  Future<void> _logActivity(String action) async {
    try {
      String formattedCoopName = _cooperativeName!.replaceAll(' ', '_');
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

  void _showAssignUserRoleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign User Role',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Assign Market Manager'),
              onTap: () {
                Navigator.pop(context);
                _showAssignRoleDialog('Market Manager');
              },
            ),
            ListTile(
              title: const Text('Assign Loan Manager'),
              onTap: () {
                Navigator.pop(context);
                _showAssignRoleDialog('Loan Manager');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAssignRoleDialog(String role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('Assign $role', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  const SnackBar(content: Text('Please enter a UID')),
                );
                return;
              }
              _assignUserRole(_uidController.text, role);
              Navigator.pop(context);
              _uidController.clear();
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showUserListDialog() {
    if (_cooperativeName == null) return;
    String formattedCoopName = _cooperativeName!.replaceAll(' ', '_');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select User',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('${formattedCoopName}_users')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                logger.e('Error in user list dialog: ${snapshot.error}');
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No users found in this cooperative.');
              }
              final users = snapshot.data!.docs;
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index].data() as Map<String, dynamic>;
                  final uid = users[index].id;
                  return ListTile(
                    title: Text(user['fullName'] ?? 'No Name'),
                    subtitle: Text('UID: $uid'),
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

  void _showCombinedDataScreen() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Combined Data functionality coming soon!')),
    );
  }

  @override
  void dispose() {
    _coopNameController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Co-op Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: _cooperativeName == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _cooperativeName!,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildCollectionStats(),
                          const SizedBox(height: 20),
                          _buildManagementOptions(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCollectionStats() {
    String formattedCoopName = _cooperativeName!.replaceAll(' ', '_');
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
            ..._allCollections.map((collection) => FutureBuilder<List<String>>(
                  future: _globalCollections.contains(collection)
                      ? FirebaseFirestore.instance
                          .collection('${formattedCoopName}_users')
                          .get()
                          .then((snapshot) =>
                              snapshot.docs.map((doc) => doc.id).toList())
                      : Future.value([]),
                  builder: (context, userIdsSnapshot) {
                    if (userIdsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (userIdsSnapshot.hasError) {
                      logger.e(
                          'Error fetching user IDs for $collection: ${userIdsSnapshot.error}');
                      return ListTile(
                        title: Text(
                          _collectionDisplayNames[collection] ?? collection,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        trailing: const Text('Error',
                            style: TextStyle(fontSize: 16, color: Colors.red)),
                      );
                    }
                    final coopUserIds = userIdsSnapshot.data ?? [];
                    if (_globalCollections.contains(collection)) {
                      if (coopUserIds.isEmpty) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CoopCollectionManagementScreen(
                                  cooperativeName: _cooperativeName!,
                                  collectionName: collection,
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            title: Text(
                              _collectionDisplayNames[collection] ?? collection,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            trailing: const Text('0',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.brown)),
                          ),
                        );
                      }

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
                          .collection(collection)
                          .where('userId', whereIn: batch)
                          .snapshots());

                      return StreamBuilder<List<QuerySnapshot>>(
                        stream: CombineLatestStream.list(streams),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (snapshot.hasError) {
                            logger.e(
                                'Error in batch query for $collection: ${snapshot.error}');
                            return ListTile(
                              title: Text(
                                _collectionDisplayNames[collection] ??
                                    collection,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              trailing: const Text('Error',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.red)),
                            );
                          }
                          if (!snapshot.hasData) {
                            return ListTile(
                              title: Text(
                                _collectionDisplayNames[collection] ??
                                    collection,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              trailing: const Text('0',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.brown)),
                            );
                          }

                          final totalCount = snapshot.data!.fold<int>(
                              0,
                              (previous, querySnapshot) =>
                                  previous + querySnapshot.docs.length);

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CoopCollectionManagementScreen(
                                    cooperativeName: _cooperativeName!,
                                    collectionName: collection,
                                  ),
                                ),
                              );
                            },
                            child: ListTile(
                              title: Text(
                                _collectionDisplayNames[collection] ??
                                    collection,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              trailing: Text('$totalCount',
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.brown)),
                            ),
                          );
                        },
                      );
                    } else {
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('${formattedCoopName}_$collection')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (snapshot.hasError) {
                            logger.e(
                                'Error in collection stats for $collection: ${snapshot.error}');
                            return ListTile(
                              title: Text(
                                _collectionDisplayNames[collection] ??
                                    collection,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              trailing: const Text('Error',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.red)),
                            );
                          }
                          final docs = snapshot.data?.docs ?? [];
                          final count = docs.length;
                          return GestureDetector(
                            onTap: () {
                              if (collection == 'users') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserManagementScreen(
                                      cooperativeName: _cooperativeName!,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CoopCollectionManagementScreen(
                                      cooperativeName: _cooperativeName!,
                                      collectionName: collection,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: ListTile(
                              title: Text(
                                _collectionDisplayNames[collection] ??
                                    collection,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              trailing: Text('$count',
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.brown)),
                            ),
                          );
                        },
                      );
                    }
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
            () => _showAssignUserRoleDialog()),
        _buildOptionCard(
            'Combined Data', Icons.data_usage, () => _showCombinedDataScreen()),
      ],
    );
  }

  Widget _buildOptionCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.brown[700]),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Manuals'),
        BottomNavigationBarItem(
            icon: Icon(Icons.supervisor_account), label: 'F-Management'),
        BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Tips'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.brown[700],
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
        switch (index) {
          case 0:
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CoopAdminManagementScreen()),
            );
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManualsScreen()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const FarmManagementHomeScreen()),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const LearnCoffeeFarming()),
            );
            break;
        }
      },
    );
  }
}
