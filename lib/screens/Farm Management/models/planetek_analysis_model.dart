import 'package:cloud_firestore/cloud_firestore.dart';

/// Result of Planetek's certified EUDR deforestation-analysis API — a
/// second, independent check alongside the Global Forest Watch screening
/// in [EudrComplianceData]. Stored on `FarmPolygon.planetekAnalysis`,
/// never replacing the GFW result.
///
/// Unlike the GFW check, this result is digitally signed by Planetek
/// (ed25519-sha256); [signatureVerified] reflects whether
/// `runPlanetekDeforestationAnalysis` (functions/index.js) was able to
/// verify that signature server-side before returning the result.
class PlanetekAnalysisData {
  final String? aoi;
  final bool? deforestationCertified;
  final double? forestArea2020Ha;
  final double? deforestedAreaHa;
  final double? deforestedPercentage;
  final String? algorithmVersion;
  final String? deploymentVersion;
  final String? deploymentId;
  final String flowRunId;
  final bool signatureVerified;
  final String signatureNote;
  final DateTime checkedAt;

  const PlanetekAnalysisData({
    this.aoi,
    this.deforestationCertified,
    this.forestArea2020Ha,
    this.deforestedAreaHa,
    this.deforestedPercentage,
    this.algorithmVersion,
    this.deploymentVersion,
    this.deploymentId,
    required this.flowRunId,
    required this.signatureVerified,
    required this.signatureNote,
    required this.checkedAt,
  });

  /// Builds from the raw Map returned by the `runPlanetekDeforestationAnalysis`
  /// callable (see functions/index.js).
  factory PlanetekAnalysisData.fromCallableResult(Map<String, dynamic> map) {
    return PlanetekAnalysisData(
      aoi: map['aoi'] as String?,
      deforestationCertified: map['deforestationCertified'] as bool?,
      forestArea2020Ha: (map['forestArea2020Ha'] as num?)?.toDouble(),
      deforestedAreaHa: (map['deforestedAreaHa'] as num?)?.toDouble(),
      deforestedPercentage: (map['deforestedPercentage'] as num?)?.toDouble(),
      algorithmVersion: map['algorithmVersion'] as String?,
      deploymentVersion: map['deploymentVersion'] as String?,
      deploymentId: map['deploymentId'] as String?,
      flowRunId: map['flowRunId'] as String? ?? '',
      signatureVerified: map['signatureVerified'] as bool? ?? false,
      signatureNote: map['signatureNote'] as String? ?? '',
      checkedAt: DateTime.now(),
    );
  }

  factory PlanetekAnalysisData.fromMap(Map<String, dynamic> map) {
    return PlanetekAnalysisData(
      aoi: map['aoi'] as String?,
      deforestationCertified: map['deforestationCertified'] as bool?,
      forestArea2020Ha: (map['forestArea2020Ha'] as num?)?.toDouble(),
      deforestedAreaHa: (map['deforestedAreaHa'] as num?)?.toDouble(),
      deforestedPercentage: (map['deforestedPercentage'] as num?)?.toDouble(),
      algorithmVersion: map['algorithmVersion'] as String?,
      deploymentVersion: map['deploymentVersion'] as String?,
      deploymentId: map['deploymentId'] as String?,
      flowRunId: map['flowRunId'] as String? ?? '',
      signatureVerified: map['signatureVerified'] as bool? ?? false,
      signatureNote: map['signatureNote'] as String? ?? '',
      checkedAt: map['checkedAt'] != null
          ? (map['checkedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (aoi != null) 'aoi': aoi,
      if (deforestationCertified != null)
        'deforestationCertified': deforestationCertified,
      if (forestArea2020Ha != null) 'forestArea2020Ha': forestArea2020Ha,
      if (deforestedAreaHa != null) 'deforestedAreaHa': deforestedAreaHa,
      if (deforestedPercentage != null)
        'deforestedPercentage': deforestedPercentage,
      if (algorithmVersion != null) 'algorithmVersion': algorithmVersion,
      if (deploymentVersion != null) 'deploymentVersion': deploymentVersion,
      if (deploymentId != null) 'deploymentId': deploymentId,
      'flowRunId': flowRunId,
      'signatureVerified': signatureVerified,
      'signatureNote': signatureNote,
      'checkedAt': Timestamp.fromDate(checkedAt),
    };
  }

  /// True only when Planetek both certified the AoI as deforestation-free
  /// AND the response's signature was verified — the strict "safe to act
  /// on this" reading. UI should still show the raw values even when this
  /// is false, so the difference between "flagged non-compliant" and
  /// "couldn't verify authenticity" stays visible.
  bool get isCertifiedAndVerified =>
      (deforestationCertified ?? false) && signatureVerified;
}
