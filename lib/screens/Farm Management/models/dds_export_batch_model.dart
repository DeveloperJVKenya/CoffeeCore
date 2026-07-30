import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a DDS export batch through its lifecycle. JV Almacis never
/// files anything with TRACES itself — [submitted]/[accepted]/[rejected]
/// reflect the *exporter's own* filing, reported back into this system
/// (see [DdsExportBatchService.recordSubmission]) purely for record-
/// keeping, not something this codebase causes to happen.
enum DdsExportBatchStatus { draft, submitted, accepted, rejected }

DdsExportBatchStatus _statusFromString(String? value) {
  return DdsExportBatchStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => DdsExportBatchStatus.draft,
  );
}

/// Tier-03 "exporter package" in the plot → cooperative → exporter chain
/// of evidence: the operator (exporter) identity and commodity details a
/// Due Diligence Statement needs, plus the set of plot (FarmPolygon) IDs
/// it covers. `operatorEori`/`operatorName`/etc. describe the *exporter*,
/// entered so the generated handoff package is addressed to the right
/// filing — not JV Almacis's own identity, which never appears here.
///
/// Once the exporter has actually filed with TRACES on their own account,
/// [ddsReferenceNumber]/[ddsVerificationNumber] can be recorded back here
/// (via [DdsExportBatchService.recordSubmission]) purely so this system's
/// own evidence trail links to the exporter's filing receipt — JV Almacis
/// never obtains these numbers itself. Distinct from any farm/plot
/// record; this is export-batch-level, not per-farm, data.
class DdsExportBatch {
  final String? batchId;
  final String operatorEori;
  final String operatorName;
  final String operatorAddress;
  final String operatorCountry;
  final String hsCode;
  final String tradeName;
  final List<String> includedFarmIds;
  final DdsExportBatchStatus status;
  final String? ddsReferenceNumber;
  final String? ddsVerificationNumber;
  final DateTime createdAt;
  final DateTime? submittedAt;

  const DdsExportBatch({
    this.batchId,
    required this.operatorEori,
    required this.operatorName,
    required this.operatorAddress,
    required this.operatorCountry,
    required this.hsCode,
    required this.tradeName,
    required this.includedFarmIds,
    this.status = DdsExportBatchStatus.draft,
    this.ddsReferenceNumber,
    this.ddsVerificationNumber,
    required this.createdAt,
    this.submittedAt,
  });

  bool get isFiled =>
      ddsReferenceNumber != null && ddsVerificationNumber != null;

  factory DdsExportBatch.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return DdsExportBatch(
      batchId: doc.id,
      operatorEori: data['operatorEori'] as String? ?? '',
      operatorName: data['operatorName'] as String? ?? '',
      operatorAddress: data['operatorAddress'] as String? ?? '',
      operatorCountry: data['operatorCountry'] as String? ?? '',
      hsCode: data['hsCode'] as String? ?? '',
      tradeName: data['tradeName'] as String? ?? '',
      includedFarmIds:
          (data['includedFarmIds'] as List<dynamic>?)?.cast<String>() ??
              const [],
      status: _statusFromString(data['status'] as String?),
      ddsReferenceNumber: data['ddsReferenceNumber'] as String?,
      ddsVerificationNumber: data['ddsVerificationNumber'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      submittedAt: data['submittedAt'] != null
          ? (data['submittedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'operatorEori': operatorEori,
      'operatorName': operatorName,
      'operatorAddress': operatorAddress,
      'operatorCountry': operatorCountry,
      'hsCode': hsCode,
      'tradeName': tradeName,
      'includedFarmIds': includedFarmIds,
      'status': status.name,
      if (ddsReferenceNumber != null) 'ddsReferenceNumber': ddsReferenceNumber,
      if (ddsVerificationNumber != null)
        'ddsVerificationNumber': ddsVerificationNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
    };
  }

  DdsExportBatch copyWith({
    String? batchId,
    List<String>? includedFarmIds,
    DdsExportBatchStatus? status,
    String? ddsReferenceNumber,
    String? ddsVerificationNumber,
    DateTime? submittedAt,
  }) {
    return DdsExportBatch(
      batchId: batchId ?? this.batchId,
      operatorEori: operatorEori,
      operatorName: operatorName,
      operatorAddress: operatorAddress,
      operatorCountry: operatorCountry,
      hsCode: hsCode,
      tradeName: tradeName,
      includedFarmIds: includedFarmIds ?? this.includedFarmIds,
      status: status ?? this.status,
      ddsReferenceNumber: ddsReferenceNumber ?? this.ddsReferenceNumber,
      ddsVerificationNumber:
          ddsVerificationNumber ?? this.ddsVerificationNumber,
      createdAt: createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}
