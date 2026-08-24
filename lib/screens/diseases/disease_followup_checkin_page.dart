import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:coffeecore/models/coffee_disease_models.dart';
import 'package:coffeecore/models/follow_up_outcome.dart';
import 'package:coffeecore/screens/diseases/disease_scan_page.dart';

/// Shown ~1 week after a disease intervention was logged — the farmer either
/// rescans the crop for a fresh AI read, or tells the system directly what
/// they're seeing. Mirrors PestFollowUpCheckinPage exactly.
class DiseaseFollowUpCheckinPage extends StatefulWidget {
  final CoffeeDiseaseIntervention intervention;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const DiseaseFollowUpCheckinPage({
    required this.intervention,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<DiseaseFollowUpCheckinPage> createState() =>
      _DiseaseFollowUpCheckinPageState();
}

class _DiseaseFollowUpCheckinPageState
    extends State<DiseaseFollowUpCheckinPage> {
  static const Color _brand = Color(0xFF6F4E37);
  bool _saving = false;

  Future<void> _completeWith({
    FollowUpOutcome? outcome,
    bool rescanned = false,
  }) async {
    final id = widget.intervention.id;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('coffee_disease_interventions')
          .doc(id)
          .update({
        'followUpCompleted': true,
        'followUpCompletedAt': Timestamp.now(),
        'followUpOutcome': outcome?.name,
        'followUpRescanned': rescanned,
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving check-in: $e')));
      }
    }
  }

  Future<void> _rescan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DiseaseScanPage(notificationsPlugin: widget.notificationsPlugin),
      ),
    );
    if (!mounted) return;
    await _completeWith(rescanned: true);
  }

  @override
  Widget build(BuildContext context) {
    final intervention = widget.intervention;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-Up Check-In',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(intervention.diseaseName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          intervention.intervention.isNotEmpty
                              ? 'You applied: ${intervention.intervention}'
                              : 'Logged on '
                                  '${intervention.timestamp.toDate().toString().substring(0, 10)}',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'It has been about a week — how is the crop doing now?',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _rescan,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Rescan the crop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('— or tell us what you see —',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 12),
                ...FollowUpOutcome.values.map((outcome) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OutcomeCard(
                        outcome: outcome,
                        enabled: !_saving,
                        onTap: () => _completeWith(outcome: outcome),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  final FollowUpOutcome outcome;
  final bool enabled;
  final VoidCallback onTap;

  const _OutcomeCard(
      {required this.outcome, required this.enabled, required this.onTap});

  Color get _color {
    if (outcome.score >= 75) return const Color(0xFF5B8A4A);
    if (outcome.score >= 50) return const Color(0xFFB0763F);
    return const Color(0xFFC0392B);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: _color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(outcome.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(outcome.description,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
