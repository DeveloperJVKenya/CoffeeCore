import 'dart:typed_data';

import 'package:coffeecore/screens/Farm%20Management/models/dds_readiness_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates the downloadable "Field Ledger" document handed to an
/// exporter as evidence for their own EU Due Diligence Statement filing —
/// see the JV Almacis Field Ledger wireframe. This is a record of what
/// JV Almacis's own checks found; it is NOT a certificate and JV Almacis
/// never submits anything to TRACES itself — the exporter uses this
/// document (or the underlying data) in their own filing, on their own
/// TRACES account. See dds_export_batch_model.dart and
/// traces_dds_export_service.dart for the machine-readable equivalent of
/// the same evidence.
///
/// Colors below mirror FarmTheme.accentGood/accentBad — kept as literal
/// PdfColor values since the `pdf` package can't consume Flutter's
/// Color/Theme objects directly.
class FieldLedgerPdfService {
  static const PdfColor _accentGood = PdfColor.fromInt(0xFF4CAF50);
  static const PdfColor _accentBad = PdfColor.fromInt(0xFFE53935);
  static const PdfColor _accentWarn = PdfColor.fromInt(0xFFFF9800);
  static const PdfColor _muted = PdfColor.fromInt(0xFF757575);
  static const String _eudrBaseline = 'Dec 31 2020 – present';

  static PdfColor _statusColor(DdsReadinessStatus status) {
    switch (status) {
      case DdsReadinessStatus.readyNegligibleRisk:
        return _accentGood;
      case DdsReadinessStatus.nonNegligibleRisk:
        return _accentBad;
      case DdsReadinessStatus.boundaryOverlap:
      case DdsReadinessStatus.signatureNotVerified:
        return _accentWarn;
      case DdsReadinessStatus.notYetChecked:
        return _muted;
    }
  }

  static String _statusLabel(DdsReadinessStatus status) {
    switch (status) {
      case DdsReadinessStatus.readyNegligibleRisk:
        return 'NEGLIGIBLE RISK';
      case DdsReadinessStatus.nonNegligibleRisk:
        return 'NON-NEGLIGIBLE RISK';
      case DdsReadinessStatus.boundaryOverlap:
      case DdsReadinessStatus.signatureNotVerified:
        return 'NEEDS REVIEW';
      case DdsReadinessStatus.notYetChecked:
        return 'NOT YET CHECKED';
    }
  }

  static pw.Widget _header() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'JV ALMACIS — TRACEABILITY PLATFORM',
          style: pw.TextStyle(fontSize: 9, color: _muted, letterSpacing: 1.2),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Field Ledger',
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Not a certificate. A chain of evidence — from plot to package — '
          'that an exporter uses to file their own EU due diligence statement.',
          style: pw.TextStyle(
              fontSize: 10, fontStyle: pw.FontStyle.italic, color: _muted),
        ),
        pw.SizedBox(height: 16),
        pw.Divider(thickness: 1.2),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _muted)),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 10, font: pw.Font.courier())),
        ],
      ),
    );
  }

  static pw.Widget _plotCard(FarmPolygon farm, DdsReadiness readiness) {
    final planetek = farm.planetekAnalysis;
    final color = _statusColor(readiness.status);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      margin: const pw.EdgeInsets.only(bottom: 16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('PLOT · ${farm.farmId ?? "UNSAVED"}',
                  style: pw.TextStyle(
                      fontSize: 9, color: _muted, font: pw.Font.courier())),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: color, width: 1),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(_statusLabel(readiness.status),
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: color,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text('${farm.farmName} — Coffee, ${farm.areaLabel}',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300),
          _kv('Coordinates',
              '${farm.center.latitude.toStringAsFixed(4)}, ${farm.center.longitude.toStringAsFixed(4)}'),
          _kv('Deforestation baseline', _eudrBaseline),
          _kv('Algorithm version', planetek?.algorithmVersion ?? 'n/a'),
          _kv(
            'Last verified',
            planetek != null
                ? dateFmt.format(planetek.checkedAt)
                : 'Not yet run',
          ),
          _kv(
            'Signature',
            planetek == null
                ? 'n/a'
                : (planetek.signatureVerified ? 'Verified ✓' : 'NOT verified'),
          ),
          if (readiness.status != DdsReadinessStatus.readyNegligibleRisk &&
              readiness.status != DdsReadinessStatus.notYetChecked)
            _kv('Flag reason', readiness.headline),
          pw.SizedBox(height: 10),
          pw.Text(
            readiness.explanation,
            style: pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('JV ALMACIS / FIELD LEDGER',
                style: pw.TextStyle(fontSize: 8, color: _muted)),
            pw.Text(
              'Evidence record — not a compliance certificate. '
              'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds a Field Ledger PDF for a single plot.
  static Future<Uint8List> buildSingleFarmLedger(
    FarmPolygon farm,
    DdsReadiness readiness,
  ) {
    return buildMultiFarmLedger([farm], {farm.farmId ?? '': readiness});
  }

  /// Builds a Field Ledger PDF covering multiple plots (e.g. a
  /// cooperative rollup) — one card per plot, in the order given.
  /// [readinessByFarmId] must have an entry for every farm's farmId.
  static Future<Uint8List> buildMultiFarmLedger(
    List<FarmPolygon> farms,
    Map<String, DdsReadiness> readinessByFarmId,
  ) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) =>
            context.pageNumber == 1 ? _header() : pw.SizedBox(),
        footer: _footer,
        build: (context) => farms.map((farm) {
          final readiness = readinessByFarmId[farm.farmId ?? ''] ??
              DdsReadiness.evaluate(farm);
          return _plotCard(farm, readiness);
        }).toList(),
      ),
    );

    return doc.save();
  }
}
