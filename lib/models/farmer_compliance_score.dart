/// A farmer's standing within this system's Integrated Pest, Disease &
/// Fertilizer Management (IPM) programme — how consistently they engage
/// with system-suggested guidance, follow through on scheduled check-ins,
/// and how effective their logged interventions turn out to be.
enum ComplianceTier {
  gettingStarted,
  developingPractices,
  diligentFarmer,
  ipmChampion;

  String get label {
    switch (this) {
      case ComplianceTier.gettingStarted:
        return 'Getting Started';
      case ComplianceTier.developingPractices:
        return 'Developing Practices';
      case ComplianceTier.diligentFarmer:
        return 'Diligent Farmer';
      case ComplianceTier.ipmChampion:
        return 'IPM Champion';
    }
  }

  String get encouragement {
    switch (this) {
      case ComplianceTier.gettingStarted:
        return 'Log a few more interventions and check-ins to build your score.';
      case ComplianceTier.developingPractices:
        return 'Good progress — keep completing your follow-up check-ins.';
      case ComplianceTier.diligentFarmer:
        return 'You\'re consistently following through — strong farm management.';
      case ComplianceTier.ipmChampion:
        return 'Excellent, sustained IPM practice — a model for your cooperative.';
    }
  }

  static ComplianceTier fromScore(double score) {
    if (score >= 80) return ComplianceTier.ipmChampion;
    if (score >= 60) return ComplianceTier.diligentFarmer;
    if (score >= 40) return ComplianceTier.developingPractices;
    return ComplianceTier.gettingStarted;
  }
}

/// Computed, not stored — always derived fresh from the farmer's own
/// intervention documents (see FarmerComplianceService). Three components,
/// each 0-100, present only when there's enough data to compute them, so a
/// new farmer with no follow-ups yet isn't unfairly scored on effectiveness.
class FarmerComplianceScore {
  final double? categorizationRate; // used a real category, not "Other"
  final double? followUpCompletionRate; // completed due check-ins
  final double? averageEffectiveness; // avg of completed check-in outcomes
  final int totalInterventions;
  final int completedCheckIns;

  const FarmerComplianceScore({
    required this.categorizationRate,
    required this.followUpCompletionRate,
    required this.averageEffectiveness,
    required this.totalInterventions,
    required this.completedCheckIns,
  });

  /// Weighted average of whichever components have enough data —
  /// effectiveness (the real-world outcome) counts most when available.
  double get overallScore {
    final parts = <double, double>{}; // score -> weight
    if (categorizationRate != null) parts[categorizationRate!] = 0.3;
    if (followUpCompletionRate != null) parts[followUpCompletionRate!] = 0.3;
    if (averageEffectiveness != null) parts[averageEffectiveness!] = 0.4;

    if (parts.isEmpty) return 0;
    final totalWeight = parts.values.fold<double>(0, (t, w) => t + w);
    final weightedSum =
        parts.entries.fold<double>(0, (t, e) => t + e.key * e.value);
    return weightedSum / totalWeight;
  }

  ComplianceTier get tier => ComplianceTier.fromScore(overallScore);

  bool get hasEnoughData => totalInterventions > 0;
}
