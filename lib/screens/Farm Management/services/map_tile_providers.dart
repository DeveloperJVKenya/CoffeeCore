import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── URL-based Tile Provider for Google Maps Flutter ─────────
/// Fetches map tiles from a {z}/{x}/{y} URL template.
/// Works on Android/iOS. Web support depends on the
/// google_maps_flutter_web plugin version.
class UrlTileProvider implements TileProvider {
  final String urlTemplate;

  UrlTileProvider(this.urlTemplate);

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) return Tile(0, 0, Uint8List(0));

    final url = urlTemplate
        .replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString())
        .replaceAll('{z}', zoom.toString());

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return Tile(256, 256, response.bodyBytes);
      }
    } catch (_) {
      // Silently skip missing tiles (ocean, empty areas, etc.)
    }
    return Tile(0, 0, Uint8List(0));
  }
}

// ── GFW Tile URL Templates ──────────────────────────────────
/// Hansen Global Forest Change – Tree Cover Density Year 2000
/// Green = forested, transparent = non-forest.
/// This is the EUDR-relevant baseline layer.
const String gfwTreeCover2000Url =
    'https://tiles.globalforestwatch.org/umd_tree_cover_density_2000/v1.8/{z}/{x}/{y}.png';

/// Hansen Global Forest Change – Tree Cover Loss (all years)
/// Red = area where forest was lost.
const String gfwTreeCoverLossUrl =
    'https://tiles.globalforestwatch.org/umd_tree_cover_loss/v1.8/{z}/{x}/{y}.png';
