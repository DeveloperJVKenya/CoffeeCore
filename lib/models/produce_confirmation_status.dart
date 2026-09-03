/// Whether the farmer has confirmed the value (weight/variety/price)
/// a Market Manager recorded for their delivery. `null` (no stored field)
/// means the submission predates this feature — those are treated as
/// implicitly settled, never gated or prompted, so months-old history
/// doesn't suddenly show "awaiting confirmation".
enum ProduceConfirmationStatus { pending, accepted, declined }

extension ProduceConfirmationStatusX on ProduceConfirmationStatus {
  String get label {
    switch (this) {
      case ProduceConfirmationStatus.pending:
        return 'Awaiting your confirmation';
      case ProduceConfirmationStatus.accepted:
        return 'Confirmed';
      case ProduceConfirmationStatus.declined:
        return 'Declined';
    }
  }

  String get storageValue => name;

  /// Returns null both for a genuinely missing field (legacy submission)
  /// and for anything unrecognized — callers must treat null as "no
  /// confirmation flow applies", not silently coerce it to pending.
  static ProduceConfirmationStatus? fromStorage(String? value) {
    if (value == null) return null;
    for (final status in ProduceConfirmationStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }
}
