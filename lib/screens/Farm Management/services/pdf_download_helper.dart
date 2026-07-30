import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:coffeecore/screens/admin/file_save_stub.dart'
    if (dart.library.html) 'package:coffeecore/screens/admin/file_save_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Cross-platform save/share for generated binary documents (e.g. the
/// Field Ledger PDF) — same web-download-vs-native-file-plus-share split
/// already used for GeoJSON exports in farm_geojson_export_screen.dart,
/// generalized here so any future document generator can reuse it instead
/// of re-deriving the platform branching.
class PdfDownloadHelper {
  PdfDownloadHelper._();

  /// Saves [bytes] as [fileName]. On web this triggers a real browser
  /// download and returns null. Natively it writes to the platform's
  /// downloads/documents directory and returns the saved [File] so the
  /// caller can offer a follow-up "Share" action via [share].
  static Future<File?> saveBytes(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/pdf',
  }) async {
    if (kIsWeb) {
      saveBytesFileInBrowser(bytes, fileName, mimeType);
      return null;
    }

    String outputDir;
    if (Platform.isAndroid) {
      outputDir = '/storage/emulated/0/Download';
    } else if (Platform.isIOS) {
      outputDir = (await getApplicationDocumentsDirectory()).path;
    } else {
      outputDir = (await getDownloadsDirectory())?.path ??
          (await getApplicationDocumentsDirectory()).path;
    }

    final file = File('$outputDir/$fileName');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> share(File file, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  }
}
