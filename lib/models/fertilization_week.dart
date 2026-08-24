import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/models/follow_up_outcome.dart';

/// One week of an AI-generated fertilization plan, tracked as its own
/// Firestore document (collection `fertilization_weeks`) rather than nested
/// inside the plan array on the SoilData document — a flat, queryable
/// collection is what lets the scheduled Cloud Function
/// (`sendFollowUpReminders` in functions/index.js) find due-and-uncompleted
/// weeks the same way it already does for pest/disease follow-ups, and lets
/// AgriPoints scoring read it the same way too. The plan-overview array on
/// SoilData (`fertilizationPlan`) is untouched and still drives the existing
/// summary/dialog UI — this is an additional, tracking-focused copy of the
/// same data.
class FertilizationWeekRecord {
  final String? id;
  final String userId;
  final String soilDataId;
  final int weekNumber;
  final String action;
  final String product;
  final double quantityKgPerAcre;
  final double quantityGPerPlant;
  final String timing;
  final String notes;
  final DateTime dueAt;
  final bool completed;
  final DateTime? completedAt;
  final bool pushSent;
  final bool isDeleted;
  final FollowUpOutcome? outcome;

  const FertilizationWeekRecord({
    this.id,
    required this.userId,
    required this.soilDataId,
    required this.weekNumber,
    required this.action,
    required this.product,
    required this.quantityKgPerAcre,
    required this.quantityGPerPlant,
    required this.timing,
    required this.notes,
    required this.dueAt,
    this.completed = false,
    this.completedAt,
    this.pushSent = false,
    this.isDeleted = false,
    this.outcome,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'soilDataId': soilDataId,
      'weekNumber': weekNumber,
      'action': action,
      'product': product,
      'quantityKgPerAcre': quantityKgPerAcre,
      'quantityGPerPlant': quantityGPerPlant,
      'timing': timing,
      'notes': notes,
      'dueAt': Timestamp.fromDate(dueAt),
      'completed': completed,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'pushSent': pushSent,
      'isDeleted': isDeleted,
      'outcome': outcome?.name,
    };
  }

  factory FertilizationWeekRecord.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return FertilizationWeekRecord(
      id: snapshot.id,
      userId: data['userId'] as String? ?? 'Unknown',
      soilDataId: data['soilDataId'] as String? ?? '',
      weekNumber: (data['weekNumber'] as num?)?.toInt() ?? 0,
      action: data['action'] as String? ?? '',
      product: data['product'] as String? ?? '',
      quantityKgPerAcre: (data['quantityKgPerAcre'] as num?)?.toDouble() ?? 0,
      quantityGPerPlant: (data['quantityGPerPlant'] as num?)?.toDouble() ?? 0,
      timing: data['timing'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      dueAt: (data['dueAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completed: data['completed'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      pushSent: data['pushSent'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      outcome: FollowUpOutcome.fromName(data['outcome'] as String?),
    );
  }
}
