import 'package:cloud_firestore/cloud_firestore.dart';

/// Post-harvest pipeline stage for a tagged produce submission ("bag"), from
/// the moment it's received at the cooperative through to market dispatch.
enum ProduceStage {
  received,
  milling,
  dryingSorting,
  readyForMarket,
  dispatchedToMarket,
}

extension ProduceStageX on ProduceStage {
  String get label {
    switch (this) {
      case ProduceStage.received:
        return 'Received';
      case ProduceStage.milling:
        return 'Milling';
      case ProduceStage.dryingSorting:
        return 'Drying / Sorting';
      case ProduceStage.readyForMarket:
        return 'Ready for Market';
      case ProduceStage.dispatchedToMarket:
        return 'Dispatched to Market';
    }
  }

  String get storageValue => name;

  static ProduceStage fromStorage(String? value) {
    return ProduceStage.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProduceStage.received,
    );
  }

  /// The next stage forward in the pipeline, or null if already at the
  /// final stage — the scan screen only ever offers this, enforcing
  /// forward-only progression (no skipping or reverting via a scan).
  ProduceStage? get next {
    final values = ProduceStage.values;
    final i = values.indexOf(this);
    return i + 1 < values.length ? values[i + 1] : null;
  }
}

/// A single stage-transition record for one produce submission. Stored at
/// `{coop}_FarmerProduce/{userId}/submissions/{submissionId}/traceStages/{entryId}`.
class ProduceTraceEntry {
  final String? id;
  final ProduceStage stage;
  final String scannedBy;
  final String scannedByName;
  final String note;
  final Timestamp timestamp;

  const ProduceTraceEntry({
    this.id,
    required this.stage,
    required this.scannedBy,
    required this.scannedByName,
    required this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'stage': stage.storageValue,
      'scannedBy': scannedBy,
      'scannedByName': scannedByName,
      'note': note,
      'timestamp': timestamp,
    };
  }

  factory ProduceTraceEntry.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProduceTraceEntry(
      id: doc.id,
      stage: ProduceStageX.fromStorage(data['stage']?.toString()),
      scannedBy: data['scannedBy']?.toString() ?? '',
      scannedByName: data['scannedByName']?.toString() ?? '',
      note: data['note']?.toString() ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
