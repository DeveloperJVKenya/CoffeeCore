import 'dart:typed_data';

/// Non-web fallback: never called (the export screen only calls this on
/// [kIsWeb]), but required so the conditional import always resolves.
void saveTextFileInBrowser(String contents, String fileName, String mimeType) {
  throw UnsupportedError('Browser download is only available on the web');
}

/// Non-web fallback for binary downloads (e.g. PDFs) — see saveTextFileInBrowser.
void saveBytesFileInBrowser(Uint8List bytes, String fileName, String mimeType) {
  throw UnsupportedError('Browser download is only available on the web');
}
