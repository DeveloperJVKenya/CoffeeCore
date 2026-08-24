/// What the farmer observed when checking back in on a logged intervention,
/// roughly a week after applying it. [score] is a 0-100 effectiveness proxy
/// reserved for a later phase (aggregate effectiveness-by-method scoring) —
/// stored here now so outcomes captured today don't need re-deriving later.
enum FollowUpOutcome {
  fullyRecovered,
  improved,
  noChange,
  worsened,
  spreadFurther;

  String get label {
    switch (this) {
      case FollowUpOutcome.fullyRecovered:
        return 'Fully recovered';
      case FollowUpOutcome.improved:
        return 'Improved';
      case FollowUpOutcome.noChange:
        return 'No change';
      case FollowUpOutcome.worsened:
        return 'Worsened';
      case FollowUpOutcome.spreadFurther:
        return 'Spread further';
    }
  }

  String get description {
    switch (this) {
      case FollowUpOutcome.fullyRecovered:
        return 'No visible signs remain on the crop';
      case FollowUpOutcome.improved:
        return 'Clearly better, but some signs remain';
      case FollowUpOutcome.noChange:
        return 'About the same as before';
      case FollowUpOutcome.worsened:
        return 'Signs are more severe than before';
      case FollowUpOutcome.spreadFurther:
        return 'Spread to more of the crop';
    }
  }

  int get score {
    switch (this) {
      case FollowUpOutcome.fullyRecovered:
        return 100;
      case FollowUpOutcome.improved:
        return 75;
      case FollowUpOutcome.noChange:
        return 50;
      case FollowUpOutcome.worsened:
        return 25;
      case FollowUpOutcome.spreadFurther:
        return 0;
    }
  }

  static FollowUpOutcome? fromName(String? name) {
    if (name == null) return null;
    for (final value in FollowUpOutcome.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
