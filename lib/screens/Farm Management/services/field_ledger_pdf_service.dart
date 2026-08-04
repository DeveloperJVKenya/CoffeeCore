import 'dart:math' as math;
import 'dart:typed_data';

import 'package:coffeecore/screens/Farm%20Management/models/dds_readiness_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_polygon_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
///
/// All dynamic text run through [_ascii] before being handed to a pw.Text:
/// the `pdf` package's built-in Helvetica base font only carries plain
/// ASCII glyphs, so em/en dashes, curly quotes and check marks render as
/// empty tofu boxes instead of raising a build error — sanitizing at this
/// boundary keeps the on-screen (fully Unicode-capable) copy untouched.
class FieldLedgerPdfService {
  static const PdfColor _accentGood = PdfColor.fromInt(0xFF4CAF50);
  static const PdfColor _accentBad = PdfColor.fromInt(0xFFE53935);
  static const PdfColor _accentWarn = PdfColor.fromInt(0xFFFF9800);
  static const PdfColor _muted = PdfColor.fromInt(0xFF757575);
  static const String _eudrBaseline = 'Dec 31 2020 - present';
  static const double _thumbBoxSize = 108;

  static String _ascii(String input) {
    return input
        .replaceAll('—', ' - ')
        .replaceAll('–', '-')
        .replaceAll('✓', '(verified)')
        .replaceAll('·', '-')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
  }

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
          'JV ALMACIS - TRACEABILITY PLATFORM',
          style: pw.TextStyle(fontSize: 9, color: _muted, letterSpacing: 1.2),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Field Ledger',
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          _ascii(
            'Not a certificate. A chain of evidence — from plot to package — '
            'that an exporter uses to file their own EU due diligence statement.',
          ),
          style: pw.TextStyle(
              fontSize: 10, fontStyle: pw.FontStyle.italic, color: _muted),
        ),
        pw.SizedBox(height: 16),
        pw.Divider(thickness: 1.2),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _kv(String label, String value, {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _muted)),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 10,
                font: pw.Font.courier(),
                color: valueColor ?? PdfColors.black,
                fontWeight: valueColor != null
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the plot's mapped boundary to scale inside a fixed-size box —
  /// an equirectangular projection (longitude scaled by cos(latitude) so
  /// the shape isn't stretched east-west) centered and scaled to fit,
  /// which is accurate enough at single-plot scale. Falls back to a plain
  /// label when fewer than 3 vertices were captured (EUDR allows a single
  /// point instead of a full polygon for plots under 4 ha).
  static pw.Widget _polygonThumbnail(FarmPolygon farm, PdfColor color) {
    final points = farm.coordinates;

    if (points.length < 3) {
      return pw.Container(
        width: _thumbBoxSize,
        height: _thumbBoxSize,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey400, width: 0.75),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Center(
          child: pw.Text(
            points.isEmpty ? 'No boundary\nmapped' : 'Point location\nonly',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ),
      );
    }

    return pw.Container(
      width: _thumbBoxSize,
      height: _thumbBoxSize,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.75),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.CustomPaint(
        size: PdfPoint(_thumbBoxSize - 20, _thumbBoxSize - 20),
        painter: (canvas, size) {
          final lats = points.map((LatLng p) => p.latitude).toList();
          final lngs = points.map((LatLng p) => p.longitude).toList();
          final minLat = lats.reduce(math.min);
          final maxLat = lats.reduce(math.max);
          final minLng = lngs.reduce(math.min);
          final cosLat = math.cos((minLat + maxLat) / 2 * math.pi / 180);

          final xs = points
              .map((LatLng p) => (p.longitude - minLng) * cosLat)
              .toList();
          final ys = points.map((LatLng p) => p.latitude - minLat).toList();
          final maxX = xs.reduce(math.max);
          final maxY = ys.reduce(math.max);
          final span = math.max(maxX, maxY) == 0 ? 1.0 : math.max(maxX, maxY);

          PdfPoint project(int i) {
            final px = (xs[i] - maxX / 2) / span;
            final py = (ys[i] - maxY / 2) / span;
            return PdfPoint((px + 0.5) * size.x, (py + 0.5) * size.y);
          }

          final fillColor = PdfColor(color.red, color.green, color.blue, 0.16);

          void tracePath() {
            final first = project(0);
            canvas.moveTo(first.x, first.y);
            for (var i = 1; i < points.length; i++) {
              final p = project(i);
              canvas.lineTo(p.x, p.y);
            }
            canvas.closePath();
          }

          canvas.setFillColor(fillColor);
          tracePath();
          canvas.fillPath();

          canvas.setStrokeColor(color);
          canvas.setLineWidth(1.2);
          tracePath();
          canvas.strokePath();
        },
      ),
    );
  }

  static pw.Widget _plotCard(FarmPolygon farm, DdsReadiness readiness) {
    final planetek = farm.planetekAnalysis;
    final color = _statusColor(readiness.status);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final flagged =
        readiness.status != DdsReadinessStatus.readyNegligibleRisk &&
            readiness.status != DdsReadinessStatus.notYetChecked;

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
              pw.Text('PLOT - ${farm.farmId ?? "UNSAVED"}',
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
          pw.Text('${_ascii(farm.farmName)} - Coffee, ${farm.areaLabel}',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _polygonThumbnail(farm, color),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kv('Coordinates',
                        '${farm.center.latitude.toStringAsFixed(4)}, ${farm.center.longitude.toStringAsFixed(4)}'),
                    _kv(
                      'Boundary points',
                      farm.coordinates.length >= 3
                          ? '${farm.coordinates.length} vertices'
                          : 'Not mapped',
                    ),
                    _kv('Perimeter', farm.perimeterLabel),
                    _kv('Deforestation baseline', _eudrBaseline),
                    _kv('Algorithm version',
                        planetek?.algorithmVersion ?? 'n/a'),
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
                          : (planetek.signatureVerified
                              ? 'Verified'
                              : 'NOT verified'),
                      valueColor: planetek == null
                          ? null
                          : (planetek.signatureVerified
                              ? _accentGood
                              : _accentBad),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (flagged) ...[
            pw.SizedBox(height: 8),
            _kv('Flag reason', _ascii(readiness.headline), valueColor: color),
          ],
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              _ascii(readiness.explanation),
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
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
              _ascii(
                'Evidence record — not a compliance certificate. '
                'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              ),
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
