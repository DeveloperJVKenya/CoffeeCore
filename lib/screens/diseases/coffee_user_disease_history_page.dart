import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:coffeecore/models/coffee_disease_models.dart';
import 'package:coffeecore/screens/diseases/disease_firestore_service.dart';
import 'package:coffeecore/screens/diseases/disease_followup_checkin_page.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger(printer: PrettyPrinter());

class CoffeeUserDiseaseHistoryPage extends StatefulWidget {
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const CoffeeUserDiseaseHistoryPage(
      {required this.notificationsPlugin, super.key});

  @override
  State<CoffeeUserDiseaseHistoryPage> createState() =>
      _CoffeeUserDiseaseHistoryPageState();
}

class _CoffeeUserDiseaseHistoryPageState
    extends State<CoffeeUserDiseaseHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Disease Management History',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF6F4E37),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Please log in to view history.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Disease Management History',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF6F4E37),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'AI Diagnoses', icon: Icon(Icons.biotech_rounded)),
              Tab(
                  text: 'Manual Interventions',
                  icon: Icon(Icons.edit_note_rounded)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _DiagnosesTab(),
            _InterventionsTab(notificationsPlugin: widget.notificationsPlugin),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI DIAGNOSES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _DiagnosesTab extends StatelessWidget {
  const _DiagnosesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DiseaseDiagnosisRecord>>(
      stream: DiseaseFirestoreService.historyStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.e('Error fetching disease diagnoses', error: snapshot.error);
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final diagnoses = snapshot.data ?? [];
        if (diagnoses.isEmpty) {
          return const Center(child: Text('No AI diagnoses saved yet.'));
        }

        return Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: diagnoses.length,
            itemBuilder: (context, index) {
              final diagnosis = diagnoses[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Disease: ${diagnosis.diseaseName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Stage: ${diagnosis.stage}'),
                      Text('Detection: ${diagnosis.detectionMode}'),
                      if (diagnosis.aiConfidence != null)
                        Text(
                            'Confidence: ${(diagnosis.aiConfidence! * 100).toStringAsFixed(0)}%'),
                      Text('Saved: ${diagnosis.savedAt.toString()}'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _deleteDiagnosis(context, diagnosis),
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
    );
  }

  Future<void> _deleteDiagnosis(
      BuildContext context, DiseaseDiagnosisRecord diagnosis) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this diagnosis?'),
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

    if (confirm == true) {
      try {
        await DiseaseFirestoreService.deleteDiagnosis(diagnosis.id);
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Diagnosis deleted successfully')));
      } catch (e) {
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error deleting diagnosis: $e')));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANUAL INTERVENTIONS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _InterventionsTab extends StatelessWidget {
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const _InterventionsTab({required this.notificationsPlugin});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('coffee_disease_interventions')
          .where('userId', isEqualTo: user.uid)
          .where('isDeleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.e('Error fetching disease intervention history',
              error: snapshot.error);
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('No disease management history available.'));
        }

        final interventions = snapshot.data!.docs
            .map((doc) {
              try {
                return CoffeeDiseaseIntervention.fromFirestore(
                    doc as DocumentSnapshot<Map<String, dynamic>>, null);
              } catch (e) {
                _logger.w('Error parsing intervention ${doc.id}', error: e);
                return null;
              }
            })
            .where((item) => item != null)
            .cast<CoffeeDiseaseIntervention>()
            .toList();

        return Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: interventions.length,
            itemBuilder: (context, index) {
              final intervention = interventions[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Disease: ${intervention.diseaseName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Stage: ${intervention.cropStage}'),
                      Text(
                          'Intervention: ${intervention.intervention.isNotEmpty ? intervention.intervention : "None"}'),
                      Text('Amount: ${intervention.amount ?? "N/A"}'),
                      Text(
                          'Area: ${intervention.area ?? "N/A"} ${intervention.areaUnit}'),
                      Text(
                          'Saved: ${intervention.timestamp.toDate().toString()}'),
                      if (intervention.followUpDueAt != null &&
                          !intervention.followUpCompleted) ...[
                        const SizedBox(height: 8),
                        _FollowUpBadge(
                          dueAt: intervention.followUpDueAt!,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DiseaseFollowUpCheckinPage(
                                  intervention: intervention,
                                  notificationsPlugin: notificationsPlugin,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () =>
                                _editIntervention(context, intervention),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _deleteIntervention(context, intervention),
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
    );
  }

  Future<void> _editIntervention(
      BuildContext context, CoffeeDiseaseIntervention intervention) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: intervention.intervention);
    final amountController =
        TextEditingController(text: intervention.amount ?? '');
    final areaController =
        TextEditingController(text: intervention.area?.toString() ?? '');
    bool useSQM = intervention.areaUnit == 'SQM';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Intervention'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: controller,
                    decoration:
                        const InputDecoration(labelText: 'Intervention Used')),
                TextField(
                    controller: amountController,
                    decoration:
                        const InputDecoration(labelText: 'Amount Applied')),
                TextField(
                    controller: areaController,
                    decoration:
                        const InputDecoration(labelText: 'Total Area Affected'),
                    keyboardType: TextInputType.number),
                SwitchListTile(
                  title: const Text('Use SQM'),
                  value: useSQM,
                  onChanged: (value) => setDialogState(() => useSQM = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await FirebaseFirestore.instance
            .collection('coffee_disease_interventions')
            .doc(intervention.id)
            .update({
          'intervention': controller.text,
          'amount':
              amountController.text.isNotEmpty ? amountController.text : null,
          'area': areaController.text.isNotEmpty
              ? double.tryParse(areaController.text)
              : null,
          'areaUnit': useSQM ? 'SQM' : 'Acres',
        });

        await FirebaseFirestore.instance.collection('User_logs').add({
          'userId': intervention.userId,
          'action': 'edit',
          'collection': 'coffee_disease_interventions',
          'documentId': intervention.id,
          'timestamp': Timestamp.now(),
          'details': 'Updated intervention for ${intervention.diseaseName}',
        });

        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Intervention updated successfully')));
      } catch (e) {
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error updating intervention: $e')));
      }
    }
  }

  Future<void> _deleteIntervention(
      BuildContext context, CoffeeDiseaseIntervention intervention) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
            'Are you sure you want to delete this intervention? It can be restored by an admin.'),
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

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('coffee_disease_interventions')
            .doc(intervention.id)
            .update({
          'isDeleted': true,
        });

        await FirebaseFirestore.instance.collection('User_logs').add({
          'userId': intervention.userId,
          'action': 'delete',
          'collection': 'coffee_disease_interventions',
          'documentId': intervention.id,
          'timestamp': Timestamp.now(),
          'details':
              'Soft-deleted intervention for ${intervention.diseaseName}',
        });

        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Intervention deleted successfully')));
      } catch (e) {
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error deleting intervention: $e')));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Due for follow-up check-in" badge — amber once overdue, grey beforehand.
// ─────────────────────────────────────────────────────────────────────────────

class _FollowUpBadge extends StatelessWidget {
  final DateTime dueAt;
  final VoidCallback onTap;

  const _FollowUpBadge({required this.dueAt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final overdue = DateTime.now().isAfter(dueAt);
    final color = overdue ? Colors.orange.shade800 : Colors.blueGrey;
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  overdue
                      ? Icons.notifications_active_rounded
                      : Icons.schedule_rounded,
                  size: 14,
                  color: color),
              const SizedBox(width: 6),
              Text(
                overdue
                    ? 'Check-in due — tap to update'
                    : 'Check-in scheduled: ${dueAt.day}/${dueAt.month}/${dueAt.year}',
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
