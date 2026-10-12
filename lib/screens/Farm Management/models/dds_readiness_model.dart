import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';

/// Suggested next action for a farm plot's EUDR Due Diligence Statement
/// readiness, synthesized from three independent signals already on
/// [FarmPolygon]:
///   - Planetek's signed, certified post-2020 deforestation analysis
///     (the primary EUDR-relevant evidence — see planetek_analysis_model.dart)
///   - GFW's pre-2020 conversion-history screening (a secondary signal —
///     see eudr_compliance_service.dart)
///   - Boundary-overlap against other registered farms (a data-integrity
///     check, not a deforestation check — see boundary_overlap_service.dart)
///
/// This is a *suggestion* the app surfaces, not a legal determination —
/// EUDR due diligence also requires a legality assessment (Article 3(b))
/// this system doesn't evaluate, and any DDS still needs a named,
/// accountable signatory. See docs/planetek_eudr/README.md and the
/// TRACES/DDS integration notes for the broader context.
enum DdsReadinessStatus {
  /// No certified Planetek analysis has been run yet for this plot.
  notYetChecked,

  /// This plot overlaps another registered farm's boundary — a
  /// data-integrity/fraud signal that must be resolved before this plot's
  /// evidence can be trusted, independent of what the deforestation
  /// checks say.
  boundaryOverlap,

  /// Planetek's response could not be cryptographically verified —
  /// don't treat it as certified evidence.
  signatureNotVerified,

  /// Planetek certified this plot as deforested/converted since the 2020
  /// baseline.
  nonNegligibleRisk,

  /// Certified, signature-verified, no boundary conflicts.
  readyNegligibleRisk,
}

class DdsReadiness {
  final DdsReadinessStatus status;
  final String headline;
  final String explanation;

  const DdsReadiness({
    required this.status,
    required this.headline,
    required this.explanation,
  });

  bool get isReady => status == DdsReadinessStatus.readyNegligibleRisk;

  factory DdsReadiness.evaluate(FarmPolygon farm) {
    if (farm.hasBoundaryOverlap) {
      return DdsReadiness(
        status: DdsReadinessStatus.boundaryOverlap,
        headline: 'Needs review — boundary overlap',
        explanation:
            'This plot\'s mapped boundary overlaps ${farm.overlapsWithFarmIds.length} '
            'other registered farm${farm.overlapsWithFarmIds.length == 1 ? '' : 's'}. '
            'Resolve the boundary conflict before including this plot in a DDS — '
            'two independent operators cannot legitimately claim the same physical land.',
      );
    }

    final planetek = farm.planetekAnalysis;
    if (planetek == null) {
      return const DdsReadiness(
        status: DdsReadinessStatus.notYetChecked,
        headline: 'Not yet checked',
        explanation:
            'Run the certified deforestation analysis (KSA) for this plot '
            'before it can be considered for a Due Diligence Statement.',
      );
    }

    if (!planetek.signatureVerified) {
      return DdsReadiness(
        status: DdsReadinessStatus.signatureNotVerified,
        headline: 'Needs review — signature not verified',
        explanation:
            '${planetek.signatureNote} Do not treat this result as certified '
            'evidence for a DDS filing until it verifies successfully — re-run '
            'the analysis.',
      );
    }

    if (planetek.deforestationCertified != true) {
      return const DdsReadiness(
        status: DdsReadinessStatus.nonNegligibleRisk,
        headline: 'Non-negligible risk',
        explanation:
            'KSA\'s certified analysis found deforestation on this plot '
            'since the 31 Dec 2020 baseline. Do not include in a DDS without '
            'Article 10/11 risk-mitigation documentation.',
      );
    }

    return const DdsReadiness(
      status: DdsReadinessStatus.readyNegligibleRisk,
      headline: 'Negligible risk — ready for DDS',
      explanation:
          'Certified deforestation-free since the 31 Dec 2020 baseline, '
          'signature verified, no boundary conflicts. Still confirm the '
          'legality (Article 3(b)) documentation separately — this check '
          'covers deforestation only.',
    );
  }
}
