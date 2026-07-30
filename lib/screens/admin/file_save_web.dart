// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a real browser "Save file" download via a Blob + anchor click.
/// Works on every desktop and mobile browser (unlike the Web Share API,
/// which most desktop browsers don't support for files).
void saveTextFileInBrowser(String contents, String fileName, String mimeType) {
  _download(html.Blob([contents], mimeType), fileName);
}

/// Same, for binary content (e.g. a generated PDF).
void saveBytesFileInBrowser(Uint8List bytes, String fileName, String mimeType) {
  _download(html.Blob([bytes], mimeType), fileName);
}

void _download(html.Blob blob, String fileName) {
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
