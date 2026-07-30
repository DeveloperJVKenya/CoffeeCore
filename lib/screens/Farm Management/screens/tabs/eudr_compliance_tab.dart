import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';
import 'package:coffeecore/screens/Farm%20Management/models/dds_readiness_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/eudr_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/providers/planetek_eudr_provider.dart';
import 'package:coffeecore/screens/Farm%20Management/services/field_ledger_pdf_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/pdf_download_helper.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/dds_readiness_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/eudr_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/planetek_analysis_card.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/empty_state.dart';
import 'package:coffeecore/screens/Farm%20Management/widgets/loading_error_view.dart';

/// EUDR Compliance tab: two independent deforestation-risk sources shown
/// side by side —
///   1. GFW tree-cover screening, sourced live via `EudrProvider`.
///   2. Planetek's signed, certified deforestation analysis, sourced live
///      via `PlanetekEudrProvider`.
/// Neither ever fabricates a result — each shows its own explanatory empty
/// state with a manual "Run" action until real data exists, and each fails
/// independently without hiding the other's result.
///
/// Below both, a DdsReadinessCard synthesizes both results (plus the
/// farm's last-checked boundary-overlap flag) into one suggested next
/// action for a Due Diligence Statement — see dds_readiness_model.dart.
/// NOTE: the boundary-overlap flag shown here reflects whatever was last
/// persisted on the farm record; there's no in-tab "re-check overlap"
/// action yet (BoundaryOverlapService.checkAndPersist would need to be
/// wired to a trigger — capture/edit flow is the natural place, not yet done).
class EudrComplianceTab extends StatelessWidget {
  const EudrComplianceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(FarmTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GFW Screening', style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceSm),
          Consumer<EudrProvider>(
            builder: (context, provider, _) {
              return LoadingErrorView(
                isLoading: provider.isLoading,
                errorMessage: provider.error,
                onRetry: provider.refreshCompliance,
                builder: (context) {
                  if (provider.compliance == null) {
                    return EmptyState(
                      icon: Icons.forest_outlined,
                      title: 'No EUDR Check Yet',
                      message: 'Run an EU Deforestation Regulation compliance '
                          'check against this farm\'s boundary using satellite '
                          'tree-cover data.',
                      actionLabel: 'Run EUDR Check',
                      onAction: provider.refreshCompliance,
                    );
                  }
                  return EudrCard(
                    data: provider.compliance!,
                    onRefresh: provider.refreshCompliance,
                  );
                },
              );
            },
          ),
          const SizedBox(height: FarmTheme.spaceLg),
          const Divider(),
          const SizedBox(height: FarmTheme.spaceSm),
          Text('Certified Analysis (Planetek)', style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceSm),
          Consumer<PlanetekEudrProvider>(
            builder: (context, provider, _) {
              return LoadingErrorView(
                isLoading: provider.isLoading,
                errorMessage: provider.error,
                onRetry: provider.refreshAnalysis,
                builder: (context) {
                  if (provider.analysis == null) {
                    return EmptyState(
                      icon: Icons.verified_outlined,
                      title: 'No Certified Analysis Yet',
                      message: 'Run Planetek\'s digitally-signed EUDR '
                          'deforestation analysis against this farm\'s '
                          'boundary. This is a second, independent check '
                          'alongside the GFW screening above.',
                      actionLabel: 'Run Certified Analysis',
                      onAction: provider.refreshAnalysis,
                    );
                  }
                  return PlanetekAnalysisCard(
                    data: provider.analysis!,
                    onRefresh: provider.refreshAnalysis,
                  );
                },
              );
            },
          ),
          const SizedBox(height: FarmTheme.spaceLg),
          const Divider(),
          const SizedBox(height: FarmTheme.spaceSm),
          Text('DDS Readiness', style: FarmTheme.cardTitle),
          const SizedBox(height: FarmTheme.spaceSm),
          Builder(
            builder: (context) {
              final eudrProvider = context.watch<EudrProvider>();
              final planetekProvider = context.watch<PlanetekEudrProvider>();
              final effectiveFarm = planetekProvider.farm.copyWith(
                eudrCompliance: eudrProvider.compliance,
                planetekAnalysis: planetekProvider.analysis,
              );
              final readiness = DdsReadiness.evaluate(effectiveFarm);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DdsReadinessCard(readiness: readiness),
                  const SizedBox(height: FarmTheme.spaceSm),
                  _FieldLedgerDownloadButton(
                    farm: effectiveFarm,
                    readiness: readiness,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Generates and downloads/shares the Field Ledger PDF for this plot — the
/// evidence document an exporter uses in their own DDS filing. JV Almacis
/// never submits anything to TRACES itself; this is a handoff artifact.
class _FieldLedgerDownloadButton extends StatefulWidget {
  final FarmPolygon farm;
  final DdsReadiness readiness;

  const _FieldLedgerDownloadButton({
    required this.farm,
    required this.readiness,
  });

  @override
  State<_FieldLedgerDownloadButton> createState() =>
      _FieldLedgerDownloadButtonState();
}

class _FieldLedgerDownloadButtonState
    extends State<_FieldLedgerDownloadButton> {
  bool _isGenerating = false;

  Future<void> _download() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await FieldLedgerPdfService.buildSingleFarmLedger(
        widget.farm,
        widget.readiness,
      );
      final fileName =
          'field_ledger_${widget.farm.farmId ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await PdfDownloadHelper.saveBytes(bytes, fileName);

      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Downloaded $fileName')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved $fileName'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => PdfDownloadHelper.share(
                file,
                text: 'Field Ledger — ${widget.farm.farmName}',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Field Ledger: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isGenerating ? null : _download,
      icon: _isGenerating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label:
          Text(_isGenerating ? 'Generating…' : 'Download Field Ledger (PDF)'),
    );
  }
}
