import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:coffeecore/models/fertilization_week.dart';
import 'package:coffeecore/models/follow_up_outcome.dart';

/// Tracks the farmer's own fertilization plan weeks — due/overdue/completed
/// — mirroring the same status-badge + "mark done" pattern already used for
/// pest/disease follow-up check-ins, adapted to a multi-step weekly plan
/// instead of a single yes/no check.
class FertilizationPlanTrackerScreen extends StatefulWidget {
  const FertilizationPlanTrackerScreen({super.key});

  @override
  State<FertilizationPlanTrackerScreen> createState() =>
      _FertilizationPlanTrackerScreenState();
}

class _FertilizationPlanTrackerScreenState
    extends State<FertilizationPlanTrackerScreen> {
  static const Color _brand = Color(0xFF4A2C2A);

  /// [allWeeks] is the full stream snapshot (all plans, all weeks) so this
  /// can tell whether [week] is the last uncompleted week of its plan — the
  /// point at which asking "did the fertilization actually work" makes
  /// agronomic sense (nutrient correction shows over the full cycle, not a
  /// single week), rather than prompting for an outcome every single week.
  Future<void> _markApplied(FertilizationWeekRecord week,
      List<FertilizationWeekRecord> allWeeks) async {
    if (week.id == null) return;

    final planWeeks =
        allWeeks.where((w) => w.soilDataId == week.soilDataId).toList();
    final isFinalWeek = planWeeks.every((w) => w.id == week.id || w.completed);

    FollowUpOutcome? outcome;
    if (isFinalWeek && mounted) {
      outcome = await _pickOutcome();
    }

    try {
      await FirebaseFirestore.instance
          .collection('fertilization_weeks')
          .doc(week.id)
          .update({
        'completed': true,
        'completedAt': Timestamp.now(),
        if (outcome != null) 'outcome': outcome.name,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error updating week: $e')));
      }
    }
  }

  Future<FollowUpOutcome?> _pickOutcome() async {
    return showModalBottomSheet<FollowUpOutcome>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This was the last week of the plan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text(
              'How does the crop look now compared to before this '
              'fertilization plan?',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            for (final outcome in FollowUpOutcome.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OutcomeOption(
                  outcome: outcome,
                  onTap: () => Navigator.pop(ctx, outcome),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Skip — I'm not sure yet"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fertilization Plan Tracker',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Please log in to view your plan.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fertilization Plan Tracker',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('fertilization_weeks')
            .where('userId', isEqualTo: user.uid)
            .where('isDeleted', isEqualTo: false)
            .orderBy('dueAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final weeks = (snapshot.data?.docs ?? [])
              .map((doc) => FertilizationWeekRecord.fromFirestore(doc))
              .toList();

          if (weeks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.eco_outlined,
                        size: 56, color: Colors.brown[200]),
                    const SizedBox(height: 16),
                    const Text(
                      'No fertilization plan tracked yet. Save soil data with '
                      'a generated plan to start tracking weekly applications.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          final pending = weeks.where((w) => !w.completed).toList();
          final completed = weeks.where((w) => w.completed).toList()
            ..sort((a, b) =>
                (b.completedAt ?? b.dueAt).compareTo(a.completedAt ?? a.dueAt));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                const Text('Pending',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                for (final week in pending)
                  _WeekCard(
                    week: week,
                    onMarkApplied: () => _markApplied(week, weeks),
                  ),
                const SizedBox(height: 20),
              ],
              if (completed.isNotEmpty) ...[
                const Text('Completed',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                for (final week in completed)
                  _WeekCard(week: week, onMarkApplied: null),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final FertilizationWeekRecord week;
  final VoidCallback? onMarkApplied;

  const _WeekCard({required this.week, required this.onMarkApplied});

  _Status get _status {
    if (week.completed) return _Status.done;
    final now = DateTime.now();
    if (now.isAfter(week.dueAt)) return _Status.overdue;
    if (now.difference(week.dueAt).abs() < const Duration(days: 2)) {
      return _Status.due;
    }
    return _Status.upcoming;
  }

  Color get _statusColor {
    switch (_status) {
      case _Status.done:
        return const Color(0xFF3A5F0B);
      case _Status.overdue:
        return Colors.red.shade700;
      case _Status.due:
        return Colors.orange.shade800;
      case _Status.upcoming:
        return Colors.blueGrey;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case _Status.done:
        return 'Applied';
      case _Status.overdue:
        return 'Overdue';
      case _Status.due:
        return 'Due now';
      case _Status.upcoming:
        return 'Upcoming';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Week ${week.weekNumber}: ${week.action}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(week.product,
              style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(
              '${week.quantityKgPerAcre.toStringAsFixed(1)} kg/acre · '
              'Due ${week.dueAt.day}/${week.dueAt.month}/${week.dueAt.year}',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          if (week.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(week.notes,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontStyle: FontStyle.italic)),
          ],
          if (week.outcome != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.insights_rounded,
                    size: 14, color: Color(0xFF3A5F0B)),
                const SizedBox(width: 4),
                Text('Plan outcome: ${week.outcome!.label}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A5F0B))),
              ],
            ),
          ],
          if (onMarkApplied != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onMarkApplied,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Mark as Applied'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3A5F0B),
                  side: const BorderSide(color: Color(0xFF3A5F0B)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Status { upcoming, due, overdue, done }

class _OutcomeOption extends StatelessWidget {
  final FollowUpOutcome outcome;
  final VoidCallback onTap;

  const _OutcomeOption({required this.outcome, required this.onTap});

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
        onTap: onTap,
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
