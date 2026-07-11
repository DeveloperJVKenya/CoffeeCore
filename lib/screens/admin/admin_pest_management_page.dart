import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:coffeecore/models/pest_disease_model.dart';
import 'package:logger/logger.dart';

class AdminPestManagementPage extends StatefulWidget {
  const AdminPestManagementPage({super.key});

  @override
  State<AdminPestManagementPage> createState() =>
      _AdminPestManagementPageState();
}

class _AdminPestManagementPageState extends State<AdminPestManagementPage> {
  final _logger = Logger();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Pest Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pestinterventiondata')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            _logger.e('Error fetching interventions: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No interventions found.'));
          }

          final interventions = snapshot.data!.docs
              .map((doc) {
                try {
                  return PestIntervention.fromFirestore(
                      doc as DocumentSnapshot<Map<String, dynamic>>, null);
                } catch (e) {
                  _logger.e('Error parsing intervention ${doc.id}: $e');
                  return null;
                }
              })
              .where((item) => item != null)
              .cast<PestIntervention>()
              .toList();

          return Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: interventions.length,
              itemBuilder: (context, index) {
                final intervention = interventions[index];
                final isDeleted = intervention.isDeleted;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User: ${intervention.userId}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Pest: ${intervention.pestName}'),
                        Text('Crop: ${intervention.cropType}'),
                        Text('Stage: ${intervention.cropStage}'),
                        Text(
                            'Intervention: ${intervention.intervention.isNotEmpty ? intervention.intervention : "None"}'),
                        Text('Amount: ${intervention.amount ?? "N/A"}'),
                        Text(
                            'Area: ${intervention.area ?? "N/A"} ${intervention.areaUnit}'),
                        Text(
                            'Saved: ${intervention.timestamp.toDate().toString()}'),
                        Text('Deleted: $isDeleted',
                            style: TextStyle(
                                color: isDeleted ? Colors.red : Colors.green)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isDeleted)
                              IconButton(
                                icon: const Icon(Icons.restore,
                                    color: Colors.green),
                                onPressed: () =>
                                    _restoreIntervention(intervention),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever,
                                  color: Colors.red),
                              onPressed: () =>
                                  _hardDeleteIntervention(intervention),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _restoreIntervention(PestIntervention intervention) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('pestinterventiondata')
          .doc(intervention.id)
          .update({
        'isDeleted': false,
      });

      await FirebaseFirestore.instance.collection('User_logs').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'action': 'restore',
        'collection': 'pestinterventiondata',
        'documentId': intervention.id,
        'timestamp': Timestamp.now(),
        'details': 'Restored intervention for user ${intervention.userId}',
      });

      if (mounted) {
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Intervention restored')));
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error restoring intervention: $e')));
      }
    }
  }

  Future<void> _hardDeleteIntervention(PestIntervention intervention) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Hard Deletion'),
        content: const Text(
            'This will permanently delete the intervention. Proceed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('pestinterventiondata')
            .doc(intervention.id)
            .delete();

        await FirebaseFirestore.instance.collection('User_logs').add({
          'userId': FirebaseAuth.instance.currentUser!.uid,
          'action': 'hard_delete',
          'collection': 'pestinterventiondata',
          'documentId': intervention.id,
          'timestamp': Timestamp.now(),
          'details':
              'Hard-deleted intervention for user ${intervention.userId}',
        });
        if (mounted) {
          scaffoldMessenger.showSnackBar(const SnackBar(
              content: Text('Intervention permanently deleted')));
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('Error deleting intervention: $e')));
        }
      }
    }
  }
}
