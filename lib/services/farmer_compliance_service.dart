import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:coffeecore/models/agripoints.dart';
import 'package:coffeecore/models/coffee_disease_models.dart';
import 'package:coffeecore/models/coffee_pest_models.dart';
import 'package:coffeecore/models/farmer_compliance_score.dart';
import 'package:coffeecore/models/fertilization_week.dart';
import 'package:coffeecore/models/intervention_category.dart';

/// Grace window past a due date that still counts as "on time" — a farmer
/// checking in a few hours late shouldn't lose the on-time bonus.
const _onTimeGrace = Duration(days: 1);

/// Computes a farmer's own IPM compliance score from their own
/// `coffee_pest_interventions` + `coffee_disease_interventions` documents —
/// both already readable by their owner under existing Firestore rules, so
/// this needs no new rules or backend infrastructure.
class FarmerComplianceService {
  FarmerComplianceService._();

  static Future<FarmerComplianceScore> computeForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const FarmerComplianceScore(
        categorizationRate: null,
        followUpCompletionRate: null,
        averageEffectiveness: null,
        totalInterventions: 0,
        completedCheckIns: 0,
      );
    }

    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db
          .collection('coffee_pest_interventions')
          .where('userId', isEqualTo: uid)
          .where('isDeleted', isEqualTo: false)
          .get(),
      db
          .collection('coffee_disease_interventions')
          .where('userId', isEqualTo: uid)
          .where('isDeleted', isEqualTo: false)
          .get(),
    ]);

    final pestInterventions = results[0]
        .docs
        .map((doc) => CoffeePestIntervention.fromFirestore(doc, null))
        .where((i) => i.intervention.trim().isNotEmpty)
        .toList();
    final diseaseInterventions = results[1]
        .docs
        .map((doc) => CoffeeDiseaseIntervention.fromFirestore(doc, null))
        .where((i) => i.intervention.trim().isNotEmpty)
        .toList();

    final total = pestInterventions.length + diseaseInterventions.length;
    if (total == 0) {
      return const FarmerComplianceScore(
        categorizationRate: null,
        followUpCompletionRate: null,
        averageEffectiveness: null,
        totalInterventions: 0,
        completedCheckIns: 0,
      );
    }

    final categorizedCount = pestInterventions
            .where((i) => i.category != InterventionCategory.other)
            .length +
        diseaseInterventions
            .where((i) => i.category != InterventionCategory.other)
            .length;
    final categorizationRate = categorizedCount / total * 100;

    final duePest = pestInterventions.where((i) => i.followUpDueAt != null);
    final dueDisease =
        diseaseInterventions.where((i) => i.followUpDueAt != null);
    final dueCount = duePest.length + dueDisease.length;
    final completedCount = duePest.where((i) => i.followUpCompleted).length +
        dueDisease.where((i) => i.followUpCompleted).length;
    final followUpCompletionRate =
        dueCount == 0 ? null : completedCount / dueCount * 100;

    final scoredOutcomes = [
      ...pestInterventions
          .where((i) => i.followUpCompleted && i.followUpOutcome != null)
          .map((i) => i.followUpOutcome!.score),
      ...diseaseInterventions
          .where((i) => i.followUpCompleted && i.followUpOutcome != null)
          .map((i) => i.followUpOutcome!.score),
    ];
    final averageEffectiveness = scoredOutcomes.isEmpty
        ? null
        : scoredOutcomes.fold<int>(0, (t, s) => t + s) / scoredOutcomes.length;

    return FarmerComplianceScore(
      categorizationRate: categorizationRate,
      followUpCompletionRate: followUpCompletionRate,
      averageEffectiveness: averageEffectiveness,
      totalInterventions: total,
      completedCheckIns: scoredOutcomes.length,
    );
  }

  static bool _onTime(DateTime? completedAt, DateTime dueAt) {
    if (completedAt == null) return false;
    return !completedAt.isAfter(dueAt.add(_onTimeGrace));
  }

  static const _emptyAgriPoints = AgriPointsSummary(
    total: 0,
    fromOnTimeFollowUps: 0,
    fromLateFollowUps: 0,
    fromSuggestedMethods: 0,
    fromFertilizationWeeks: 0,
    fromCompletedPlans: 0,
  );

  /// Points rules — see Phase 8 in the plan for the rationale. Missed
  /// follow-ups (past due, never completed) earn zero points, never a
  /// penalty: consistency is rewarded by what a farmer does complete, not
  /// punished for what they don't.
  static Future<AgriPointsSummary> computeAgriPointsForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _emptyAgriPoints;
    return computeAgriPointsForUser(uid);
  }

  /// Same computation as [computeAgriPointsForCurrentUser], for an arbitrary
  /// farmer — used by Coop/Main Admin ranking views. Relies on the same
  /// Firestore rules already granting Admin/Coop Admin read access to these
  /// three collections (see firestore.rules), so no separate backend
  /// endpoint is needed.
  static Future<AgriPointsSummary> computeAgriPointsForUser(String uid) async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db
          .collection('coffee_pest_interventions')
          .where('userId', isEqualTo: uid)
          .where('isDeleted', isEqualTo: false)
          .get(),
      db
          .collection('coffee_disease_interventions')
          .where('userId', isEqualTo: uid)
          .where('isDeleted', isEqualTo: false)
          .get(),
      db
          .collection('fertilization_weeks')
          .where('userId', isEqualTo: uid)
          .where('isDeleted', isEqualTo: false)
          .get(),
    ]);

    return _fromDocs(
      pestDocs: results[0].docs,
      diseaseDocs: results[1].docs,
      fertilizationDocs: results[2].docs,
    );
  }

  /// Batch variant for a whole cooperative (or, for Main Admin, the whole
  /// platform) — issues Firestore `whereIn` queries in chunks of 10 instead
  /// of one round-trip per farmer, then groups results locally by userId.
  /// Farmers with zero logged activity are included with an empty score so
  /// callers can still rank/list them.
  static Future<Map<String, AgriPointsSummary>> computeAgriPointsForUsers(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final db = FirebaseFirestore.instance;
    const batchSize = 10;
    final batches = <List<String>>[];
    for (var i = 0; i < userIds.length; i += batchSize) {
      batches.add(userIds.sublist(
          i, i + batchSize > userIds.length ? userIds.length : i + batchSize));
    }

    final pestDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final diseaseDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final fertilizationDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final batch in batches) {
      final results = await Future.wait([
        db
            .collection('coffee_pest_interventions')
            .where('userId', whereIn: batch)
            .where('isDeleted', isEqualTo: false)
            .get(),
        db
            .collection('coffee_disease_interventions')
            .where('userId', whereIn: batch)
            .where('isDeleted', isEqualTo: false)
            .get(),
        db
            .collection('fertilization_weeks')
            .where('userId', whereIn: batch)
            .where('isDeleted', isEqualTo: false)
            .get(),
      ]);
      pestDocs.addAll(results[0].docs);
      diseaseDocs.addAll(results[1].docs);
      fertilizationDocs.addAll(results[2].docs);
    }

    final byUser = <String, AgriPointsSummary>{
      for (final uid in userIds) uid: _emptyAgriPoints,
    };
    final pestByUser =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final d in pestDocs) {
      pestByUser.putIfAbsent(d.data()['userId'] as String, () => []).add(d);
    }
    final diseaseByUser =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final d in diseaseDocs) {
      diseaseByUser.putIfAbsent(d.data()['userId'] as String, () => []).add(d);
    }
    final fertByUser =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final d in fertilizationDocs) {
      fertByUser.putIfAbsent(d.data()['userId'] as String, () => []).add(d);
    }

    for (final uid in userIds) {
      byUser[uid] = _fromDocs(
        pestDocs: pestByUser[uid] ?? const [],
        diseaseDocs: diseaseByUser[uid] ?? const [],
        fertilizationDocs: fertByUser[uid] ?? const [],
      );
    }
    return byUser;
  }

  static AgriPointsSummary _fromDocs({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pestDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> diseaseDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
        fertilizationDocs,
  }) {
    final pestInterventions = pestDocs
        .map((doc) => CoffeePestIntervention.fromFirestore(doc, null))
        .where((i) => i.intervention.trim().isNotEmpty)
        .toList();
    final diseaseInterventions = diseaseDocs
        .map((doc) => CoffeeDiseaseIntervention.fromFirestore(doc, null))
        .where((i) => i.intervention.trim().isNotEmpty)
        .toList();
    final fertilizationWeeks = fertilizationDocs
        .map((doc) => FertilizationWeekRecord.fromFirestore(doc))
        .toList();

    var onTimeFollowUps = 0;
    var lateFollowUps = 0;
    for (final i in pestInterventions) {
      if (i.followUpDueAt == null || !i.followUpCompleted) continue;
      if (_onTime(i.followUpCompletedAt, i.followUpDueAt!)) {
        onTimeFollowUps++;
      } else {
        lateFollowUps++;
      }
    }
    for (final i in diseaseInterventions) {
      if (i.followUpDueAt == null || !i.followUpCompleted) continue;
      if (_onTime(i.followUpCompletedAt, i.followUpDueAt!)) {
        onTimeFollowUps++;
      } else {
        lateFollowUps++;
      }
    }

    final suggestedMethodCount = pestInterventions
            .where((i) => i.category != InterventionCategory.other)
            .length +
        diseaseInterventions
            .where((i) => i.category != InterventionCategory.other)
            .length;

    var onTimeWeeks = 0;
    var lateWeeks = 0;
    for (final w in fertilizationWeeks) {
      if (!w.completed) continue;
      if (_onTime(w.completedAt, w.dueAt)) {
        onTimeWeeks++;
      } else {
        lateWeeks++;
      }
    }

    final weeksBySoilData = <String, List<FertilizationWeekRecord>>{};
    for (final w in fertilizationWeeks) {
      weeksBySoilData.putIfAbsent(w.soilDataId, () => []).add(w);
    }
    final completedPlans = weeksBySoilData.values
        .where((weeks) => weeks.isNotEmpty && weeks.every((w) => w.completed))
        .length;

    const onTimePoints = 10;
    const latePoints = 4;
    const suggestedMethodPoints = 6;
    const completedPlanBonus = 25;

    final fromOnTimeFollowUps = onTimeFollowUps * onTimePoints;
    final fromLateFollowUps = lateFollowUps * latePoints;
    final fromSuggestedMethods = suggestedMethodCount * suggestedMethodPoints;
    final fromFertilizationWeeks =
        onTimeWeeks * onTimePoints + lateWeeks * latePoints;
    final fromCompletedPlans = completedPlans * completedPlanBonus;

    return AgriPointsSummary(
      total: fromOnTimeFollowUps +
          fromLateFollowUps +
          fromSuggestedMethods +
          fromFertilizationWeeks +
          fromCompletedPlans,
      fromOnTimeFollowUps: fromOnTimeFollowUps,
      fromLateFollowUps: fromLateFollowUps,
      fromSuggestedMethods: fromSuggestedMethods,
      fromFertilizationWeeks: fromFertilizationWeeks,
      fromCompletedPlans: fromCompletedPlans,
    );
  }
}
