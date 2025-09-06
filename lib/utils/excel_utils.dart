import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelUtils {
  static Future<void> downloadExcel({
    required BuildContext context,
    required List<Map<String, dynamic>> data,
    required List<String> headers,
    required String fileName,
    required String shareText,
    required Logger logger,
    String sheetName = 'Sheet1',
  }) async {
    try {
      String outputPath;
      try {
        final downloadsDir = await getDownloadsDirectory();
        outputPath = downloadsDir?.path ?? '/storage/emulated/0/Download';
        logger.i('Downloads path from getDownloadsDirectory: $outputPath');
      } catch (e) {
        logger.w('Failed to get Downloads directory: $e');
        outputPath = '/storage/emulated/0/Download';
      }

      if (Platform.isAndroid) {
        outputPath = '/storage/emulated/0/Download';
      } else if (Platform.isIOS) {
        outputPath = (await getApplicationDocumentsDirectory()).path;
      }
      logger.i('Final Downloads path: $outputPath');

      var excel = Excel.createExcel();
      Sheet sheet = excel[sheetName];

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (var item in data) {
        List<TextCellValue> row = [];
        for (var header in headers) {
          row.add(TextCellValue(item[header.toLowerCase()]?.toString() ?? 'N/A'));
        }
        sheet.appendRow(row);
      }

      String fullPath = '$outputPath/$fileName';
      File excelFile = File(fullPath);
      await excelFile.create(recursive: true);
      await excelFile.writeAsBytes(excel.encode()!);

      if (await excelFile.exists()) {
        logger.i('File exists at $fullPath, size: ${await excelFile.length()} bytes');
      } else {
        logger.w('File does not exist at $fullPath');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel saved to Downloads: $fileName'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () async {
                try {
                  final box = context.findRenderObject() as RenderBox?;
                  final shareParams = ShareParams(
                    files: [XFile(fullPath)],
                    text: shareText,
                    sharePositionOrigin: (box != null && Platform.isIOS)
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null,
                  );
                  await SharePlus.instance.share(shareParams);
                  logger.i('File shared: $fullPath');
                } catch (e) {
                  logger.e('Error sharing file: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error sharing file: $e')),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      logger.e('Error downloading Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving Excel: $e')),
        );
      }
    }
  }
}