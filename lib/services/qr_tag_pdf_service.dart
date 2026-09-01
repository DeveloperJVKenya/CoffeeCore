import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:coffeecore/services/produce_qr_service.dart';

/// Generates the printable QR bag tag for a produce submission — same
/// `pw.Document` / static-builder shape as FieldLedgerPdfService. Text is
/// kept ASCII-only for the same reason as that service: the pdf package's
/// base Helvetica font has no glyphs for em-dashes/curly quotes/etc.
class QrTagPdfService {
  QrTagPdfService._();

  // A compact label size (~4x6in) rather than a full A4 page — meant to be
  // printed and physically attached to a coffee bag.
  static final PdfPageFormat _tagFormat = PdfPageFormat(
      4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch,
      marginAll: 16);

  static String _ascii(String input) {
    return input
        .replaceAll('—', ' - ')
        .replaceAll('–', '-')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .trim();
  }

  static Future<Uint8List> buildTag({
    required String cooperativeName,
    required String farmerName,
    required String submissionDate,
    required double kg,
    required String variety,
    required String coopId,
    required String userId,
    required String submissionId,
  }) async {
    final doc = pw.Document();
    final qrData = ProduceQrService.encode(
      coopId: coopId,
      userId: userId,
      submissionId: submissionId,
    );

    doc.addPage(
      pw.Page(
        pageFormat: _tagFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(_ascii(cooperativeName.toUpperCase()),
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.1)),
              pw.SizedBox(height: 2),
              pw.Text('COFFEE PRODUCE TAG',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
              pw.SizedBox(height: 14),
              pw.Container(
                width: 180,
                height: 180,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                ),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(submissionId,
                  style: pw.TextStyle(
                      fontSize: 8,
                      font: pw.Font.courier(),
                      color: PdfColors.grey600)),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 0.75),
              pw.SizedBox(height: 8),
              _row('Farmer', _ascii(farmerName)),
              _row('Date', submissionDate),
              _row('Variety', _ascii(variety)),
              _row('Weight', '${kg.toStringAsFixed(1)} kg'),
              pw.SizedBox(height: 12),
              pw.Text(
                _ascii('Scan at each stage to record movement through milling, '
                    'processing and market dispatch.'),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 7.5,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Builds a downloadable/shareable file name that leads with the
  /// cooperative and farmer name, so the tag is identifiable at a glance
  /// among a device's other downloads rather than showing up as an opaque
  /// `produce_tag_<id>.pdf`. Trailed with the date and a short slice of the
  /// submission id to keep same-day, same-farmer deliveries from
  /// overwriting each other.
  static String fileName({
    required String cooperativeName,
    required String farmerName,
    required String submissionDate,
    required String submissionId,
  }) {
    final shortId =
        submissionId.length > 8 ? submissionId.substring(0, 8) : submissionId;
    return '${_fileNameSegment(cooperativeName)}_'
        '${_fileNameSegment(farmerName)}_'
        'ProduceTag_${submissionDate}_$shortId.pdf';
  }

  /// Collapses whitespace to underscores and strips characters that are
  /// invalid in file names on Windows/macOS — cooperative/farmer names are
  /// free-text and can contain slashes, colons, etc.
  static String _fileNameSegment(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
