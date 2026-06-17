import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:coffeecore/models/coffee_pest_models.dart';
import 'package:logger/logger.dart';
import 'package:timezone/timezone.dart' as tz;

class CoffeeViewInterventionsPage extends StatefulWidget {
  final CoffeePestData pestData;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const CoffeeViewInterventionsPage({
    required this.pestData,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<CoffeeViewInterventionsPage> createState() => _CoffeeViewInterventionsPageState();
}

class _CoffeeViewInterventionsPageState extends State<CoffeeViewInterventionsPage> {
  final _logger = Logger();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saved Interventions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF6F4E37),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Please log in to view interventions.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Interventions', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('coffee_pest_interventions')
            .where('userId', isEqualTo: user.uid)
            .where('pestName', isEqualTo: widget.pestData.name)
            .where('isDeleted', isEqualTo: false)
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
            return const Center(child: Text('No interventions saved yet.'));
          }

          final interventions = snapshot.data!.docs.map((doc) {
            try {
              return CoffeePestIntervention.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null);
            } catch (e) {
              _logger.e('Error parsing intervention ${doc.id}: $e');
              return null;
            }
          }).where((item) => item != null).cast<CoffeePestIntervention>().toList();

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
                        Text('Pest: ${intervention.pestName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Stage: ${intervention.cropStage}'),
                        Text('Intervention: ${intervention.intervention.isNotEmpty ? intervention.intervention : "None"}'),
                        Text('Amount: ${intervention.amount ?? "N/A"}'),
                        Text('Area: ${intervention.area ?? "N/A"} ${intervention.areaUnit}'),
                        Text('Saved: ${intervention.timestamp.toDate().toString()}'),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editIntervention(intervention),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteIntervention(intervention),
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications, color: Colors.green),
                              onPressed: () => _scheduleFollowUp(intervention),
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

  Future<void> _editIntervention(CoffeePestIntervention intervention) async {
    final controller = TextEditingController(text: intervention.intervention);
    final amountController = TextEditingController(text: intervention.amount ?? '');
    final areaController = TextEditingController(text: intervention.area?.toString() ?? '');
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
                TextField(controller: controller, decoration: const InputDecoration(labelText: 'Intervention Used')),
                TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount Applied')),
                TextField(controller: areaController, decoration: const InputDecoration(labelText: 'Total Area Affected'), keyboardType: TextInputType.number),
                SwitchListTile(
                  title: const Text('Use SQM'),
                  value: useSQM,
                  onChanged: (value) => setDialogState(() => useSQM = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('coffee_pest_interventions').doc(intervention.id).update({
          'intervention': controller.text,
          'amount': amountController.text.isNotEmpty ? amountController.text : null,
          'area': areaController.text.isNotEmpty ? double.parse(areaController.text) : null,
          'areaUnit': useSQM ? 'SQM' : 'Acres',
        });

        await FirebaseFirestore.instance.collection('User_logs').add({
          'userId': intervention.userId,
          'action': 'edit',
          'collection': 'coffee_pest_interventions',
          'documentId': intervention.id,
          'timestamp': Timestamp.now(),
          'details': 'Updated intervention for ${intervention.pestName}',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention updated successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating intervention: $e')));
        }
      }
    }
  }

  Future<void> _deleteIntervention(CoffeePestIntervention intervention) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this intervention? It can be restored by an admin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('coffee_pest_interventions').doc(intervention.id).update({
          'isDeleted': true,
        });

        await FirebaseFirestore.instance.collection('User_logs').add({
          'userId': intervention.userId,
          'action': 'delete',
          'collection': 'coffee_pest_interventions',
          'documentId': intervention.id,
          'timestamp': Timestamp.now(),
          'details': 'Soft-deleted intervention for ${intervention.pestName}',
        });

        if (mounted) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Intervention deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error deleting intervention: $e')));
        }
      }
    }
  }

  Future<void> _scheduleFollowUp(CoffeePestIntervention intervention) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    DateTime? date = DateTime.now().add(const Duration(days: 7));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Follow-Up Reminder'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Date: ${date!.toString().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date!,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, {'date': date}),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final tzDateTime = tz.TZDateTime.from(result['date'] as DateTime, tz.local);
      const androidDetails = AndroidNotificationDetails(
        'coffee_pest_followup_channel',
        'Coffee Pest Follow-Up Reminders',
        channelDescription: 'Reminders for coffee pest intervention follow-ups',
        importance: Importance.max,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      try {
        await widget.notificationsPlugin.zonedSchedule(
          id: intervention.id.hashCode, // Unique ID for the notification
          title: 'Follow-Up for ${intervention.pestName}',
          body: 'Evaluate effectiveness of ${intervention.intervention}',
          scheduledDate: tzDateTime,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Ensures exact scheduling
        );
        if (mounted) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Follow-up reminder scheduled')));
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error scheduling reminder: $e')));
        }
      }
    }
  }
}