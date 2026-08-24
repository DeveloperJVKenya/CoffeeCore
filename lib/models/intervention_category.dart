/// Shared category taxonomy for both pest and disease interventions.
///
/// Disease `culturalControls` (pruning, removing infected material, drainage)
/// map to [mechanical] — both are physical/manual actions on the plant,
/// distinct from [chemical] products and [biological] control agents.
enum InterventionCategory {
  chemical,
  mechanical,
  biological,
  other;

  String get label {
    switch (this) {
      case InterventionCategory.chemical:
        return 'Chemical';
      case InterventionCategory.mechanical:
        return 'Mechanical';
      case InterventionCategory.biological:
        return 'Biological';
      case InterventionCategory.other:
        return 'Other';
    }
  }

  static InterventionCategory fromName(String? name) {
    return InterventionCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => InterventionCategory.other,
    );
  }
}
