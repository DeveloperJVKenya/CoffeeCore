// One-off asset tool: trims transparent padding around the splash screen's
// coffee plant image so its stem base sits flush with the image's bottom
// edge (needed so the widget can anchor it to the ground with no gap), and
// downsizes it from the original 4000x4000/10MB source to a size sensible
// for a widget displayed at ~240 logical pixels tall.
//
// Run with: dart run tool/process_splash_asset.dart
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const String srcPath = 'assets/lushcoffeeplantwithripeberries.png';
  const String outPath = 'assets/lushcoffeeplantwithripeberries.png';
  const int targetHeight = 900; // generous headroom above 240 * max DPR

  final File srcFile = File(srcPath);
  if (!srcFile.existsSync()) {
    stderr.writeln('Source not found: $srcPath');
    exit(1);
  }

  final img.Image? original = img.decodePng(srcFile.readAsBytesSync());
  if (original == null) {
    stderr.writeln('Failed to decode $srcPath');
    exit(1);
  }
  print('Original: ${original.width}x${original.height}');

  // Trim fully-transparent rows/columns from every edge so the opaque
  // plant content reaches all four edges of the bounding box.
  final img.Image trimmed = img.trim(
    original,
    mode: img.TrimMode.transparent,
  );
  print('Trimmed: ${trimmed.width}x${trimmed.height}');

  final img.Image resized = img.copyResize(
    trimmed,
    height: targetHeight,
    interpolation: img.Interpolation.average,
  );
  print('Resized: ${resized.width}x${resized.height}');

  final List<int> encoded = img.encodePng(resized, level: 9);
  File(outPath).writeAsBytesSync(encoded);
  print('Wrote $outPath (${(encoded.length / 1024).round()} KB)');
}
