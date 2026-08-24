/// Gamified extension of the compliance score (see FarmerComplianceScore) —
/// AgriPoints and named award levels, computed the same derive-don't-store
/// way from existing intervention/fertilization documents rather than a
/// mutable ledger, so there's nothing that can drift out of sync with the
/// underlying records.
enum AwardLevel {
  sprout,
  grower,
  cultivator,
  harvestMaster,
  ipmChampion;

  String get label {
    switch (this) {
      case AwardLevel.sprout:
        return 'Sprout';
      case AwardLevel.grower:
        return 'Grower';
      case AwardLevel.cultivator:
        return 'Cultivator';
      case AwardLevel.harvestMaster:
        return 'Harvest Master';
      case AwardLevel.ipmChampion:
        return 'IPM Champion';
    }
  }

  String get emoji {
    switch (this) {
      case AwardLevel.sprout:
        return '🌱';
      case AwardLevel.grower:
        return '🌿';
      case AwardLevel.cultivator:
        return '🌾';
      case AwardLevel.harvestMaster:
        return '🏅';
      case AwardLevel.ipmChampion:
        return '🏆';
    }
  }

  int get minPoints {
    switch (this) {
      case AwardLevel.sprout:
        return 0;
      case AwardLevel.grower:
        return 50;
      case AwardLevel.cultivator:
        return 150;
      case AwardLevel.harvestMaster:
        return 350;
      case AwardLevel.ipmChampion:
        return 700;
    }
  }

  static AwardLevel fromPoints(int points) {
    for (final level in AwardLevel.values.reversed) {
      if (points >= level.minPoints) return level;
    }
    return AwardLevel.sprout;
  }

  /// Null once at the top level (IPM Champion has no "next").
  AwardLevel? get next {
    final index = AwardLevel.values.indexOf(this);
    if (index >= AwardLevel.values.length - 1) return null;
    return AwardLevel.values[index + 1];
  }
}

class AgriPointsSummary {
  final int total;
  final int fromOnTimeFollowUps;
  final int fromLateFollowUps;
  final int fromSuggestedMethods;
  final int fromFertilizationWeeks;
  final int fromCompletedPlans;

  const AgriPointsSummary({
    required this.total,
    required this.fromOnTimeFollowUps,
    required this.fromLateFollowUps,
    required this.fromSuggestedMethods,
    required this.fromFertilizationWeeks,
    required this.fromCompletedPlans,
  });

  AwardLevel get level => AwardLevel.fromPoints(total);

  /// Progress toward the next level, 0.0-1.0. 1.0 (maxed) at the top level.
  double get progressToNextLevel {
    final next = level.next;
    if (next == null) return 1.0;
    final span = next.minPoints - level.minPoints;
    if (span <= 0) return 1.0;
    return ((total - level.minPoints) / span).clamp(0.0, 1.0);
  }

  int? get pointsToNextLevel {
    final next = level.next;
    if (next == null) return null;
    return (next.minPoints - total).clamp(0, next.minPoints);
  }
}
