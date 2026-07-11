import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:coffeecore/utils/excel_utils.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cost_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/revenue_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/finance_service.dart';

/// Excel + PDF export for a cycle's cost/revenue/P&L report.
/// Reuses `ExcelUtils.downloadExcel` for the spreadsheet output and the
/// `pdf` package for a printable summary document.
class ReportExportService {
  final Logger _log = Logger(printer: PrettyPrinter());

  Future<void> exportCostsRevenueExcel({
    required BuildContext context,
    required String farmName,
    required String cycleName,
    required List<CostEntry> costs,
    required List<RevenueEntry> revenues,
  }) async {
    final List<Map<String, dynamic>> rows = [
      ...costs.map((c) => {
            'type': 'Cost',
            'category': c.category.label,
            'description': c.description,
            'amount': c.amount.toStringAsFixed(2),
            'date': c.date.toIso8601String().substring(0, 10),
          }),
      ...revenues.map((r) => {
            'type': 'Revenue',
            'category': r.variety,
            'description': r.grade ?? '',
            'amount': r.amount.toStringAsFixed(2),
            'date': r.date.toIso8601String().substring(0, 10),
          }),
    ];

    await ExcelUtils.downloadExcel(
      context: context,
      data: rows,
      headers: const ['Type', 'Category', 'Description', 'Amount', 'Date'],
      fileName: '${farmName}_${cycleName}_report.xlsx',
      shareText: 'Farm finance report for $farmName – $cycleName',
      logger: _log,
      sheetName: 'Report',
    );
  }

  Future<void> exportProfitLossPdf({
    required BuildContext context,
    required String farmName,
    required String cycleName,
    required List<CostEntry> costs,
    required List<RevenueEntry> revenues,
    required ProfitLossSummary summary,
  }) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          build: (pw.Context ctx) => [
            pw.Header(level: 0, text: 'Farm Finance Report'),
            pw.Text('Farm: $farmName'),
            pw.Text('Cycle: $cycleName'),
            pw.SizedBox(height: 12),
            pw.Text('Total Cost: ${summary.totalCost.toStringAsFixed(2)}'),
            pw.Text(
                'Total Revenue: ${summary.totalRevenue.toStringAsFixed(2)}'),
            pw.Text('Profit/Loss: ${summary.profitLoss.toStringAsFixed(2)}'),
            pw.SizedBox(height: 16),
            pw.Header(level: 1, text: 'Costs'),
            pw.TableHelper.fromTextArray(
              headers: const ['Category', 'Description', 'Amount', 'Date'],
              data: costs
                  .map((c) => [
                        c.category.label,
                        c.description,
                        c.amount.toStringAsFixed(2),
                        c.date.toIso8601String().substring(0, 10),
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Header(level: 1, text: 'Revenue'),
            pw.TableHelper.fromTextArray(
              headers: const ['Variety', 'Grade', 'Amount', 'Date'],
              data: revenues
                  .map((r) => [
                        r.variety,
                        r.grade ?? '-',
                        r.amount.toStringAsFixed(2),
                        r.date.toIso8601String().substring(0, 10),
                      ])
                  .toList(),
            ),
          ],
        ),
      );

      String outputDir;
      if (Platform.isAndroid) {
        outputDir = '/storage/emulated/0/Download';
      } else if (Platform.isIOS) {
        outputDir = (await getApplicationDocumentsDirectory()).path;
      } else {
        outputDir = (await getDownloadsDirectory())?.path ??
            (await getApplicationDocumentsDirectory()).path;
      }
      final fileName = '${farmName}_${cycleName}_report.pdf';
      final file = File('$outputDir/$fileName');
      await file.create(recursive: true);
      await file.writeAsBytes(await doc.save());
      _log.i(
          'ReportExportService.exportProfitLossPdf: Saved PDF to ${file.path}');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF report saved: $fileName'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () async {
              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile(file.path)],
                  text: 'Farm finance report for $farmName – $cycleName',
                ),
              );
            },
          ),
        ),
      );
    } catch (e, st) {
      _log.e('ReportExportService.exportProfitLossPdf: Error – $e',
          stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF report: $e')),
        );
      }
    }
  }
}
