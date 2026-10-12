import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:coffeecore/screens/Farm%20Management/services/service_exceptions.dart';

/// A single NDWI (Normalized Difference Water Index) statistics snapshot.
class NdwiData {
  final double mean;
  final double min;
  final double max;
  final double stDev;
  final DateTime fetchedAt;

  const NdwiData({
    required this.mean,
    required this.min,
    required this.max,
    required this.stDev,
    required this.fetchedAt,
  });
}

/// A single NDVI (Normalized Difference Vegetation Index) statistics
/// snapshot — the Sentinel Hub / Copernicus Data Space Ecosystem
/// counterpart to `ClimateSatelliteService.fetchLatestNdvi`'s AgroMonitoring
/// result, used for the satellite-source comparison toggle.
class NdviStatsData {
  final double mean;
  final double min;
  final double max;
  final double stDev;
  final DateTime fetchedAt;

  const NdviStatsData({
    required this.mean,
    required this.min,
    required this.max,
    required this.stDev,
    required this.fetchedAt,
  });
}

/// A colorized, per-pixel NDVI/NDWI raster (PNG) for a farm polygon, ready
/// to render as a [GroundOverlay]. Pixels outside the farm boundary (or
/// with no valid satellite data) are transparent, so the image reads as
/// clipped to the exact farm shape once overlaid on the map.
class RasterOverlayData {
  final Uint8List pngBytes;
  final LatLngBounds bounds;
  final DateTime fetchedAt;

  const RasterOverlayData({
    required this.pngBytes,
    required this.bounds,
    required this.fetchedAt,
  });
}

/// Fetches real NDWI (water/moisture index) values, computed directly from
/// Sentinel-2 Green/NIR bands (McFeeters, 1996: (Green-NIR)/(Green+NIR)),
/// via a single Cloud Function endpoint (`sentinelHubNdwi`).
///
/// Unlike the AgroMonitoring/GFW integrations, this does NOT call the
/// upstream provider (Copernicus Data Space Ecosystem / Sentinel Hub)
/// directly on any platform, even native — the OAuth2 client credentials
/// required to authenticate are a long-lived secret, and both a compiled
/// web bundle and a decompiled APK are effectively public, so embedding
/// them in the app (on any platform) would expose them to anyone. The
/// Cloud Function holds the credentials server-side (Google Secret
/// Manager) and returns only the computed statistics.
///
/// Like the other Farm Management services, this never fabricates data on
/// failure; it throws [ServiceUnavailableException] and lets the caller
/// surface [ServiceUnavailableException.userMessage].
class SentinelHubService {
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _endpoint =
      'https://us-central1-coffeecore-7111a.cloudfunctions.net/sentinelHubNdwi';
  static const String _rasterEndpoint =
      'https://us-central1-coffeecore-7111a.cloudfunctions.net/sentinelHubRaster';

  static const Duration _timeout = Duration(seconds: 25);
  static const Duration _rasterTimeout = Duration(seconds: 45);

  Future<NdwiData> fetchNdwi({
    required List<LatLng> coordinates,
    DateTime? from,
    DateTime? to,
  }) async {
    final stats = await _fetchIndexStats(
      metric: 'ndwi',
      coordinates: coordinates,
      from: from,
      to: to,
      metricLabel: 'moisture (NDWI)',
    );
    return NdwiData(
      mean: stats.mean,
      min: stats.min,
      max: stats.max,
      stDev: stats.stDev,
      fetchedAt: stats.fetchedAt,
    );
  }

  /// NDVI counterpart to [fetchNdwi] — same Cloud Function, same
  /// no-registration request shape, just `metric: 'ndvi'`. Used as the
  /// Sentinel Hub side of the AgroMonitoring/Sentinel Hub satellite-source
  /// toggle: unlike AgroMonitoring's polygon registration, every call here
  /// sends the farm's geometry directly, so there's nothing to leak or run
  /// out of quota on.
  Future<NdviStatsData> fetchNdviStats({
    required List<LatLng> coordinates,
    DateTime? from,
    DateTime? to,
  }) async {
    final stats = await _fetchIndexStats(
      metric: 'ndvi',
      coordinates: coordinates,
      from: from,
      to: to,
      metricLabel: 'vegetation (NDVI)',
    );
    return NdviStatsData(
      mean: stats.mean,
      min: stats.min,
      max: stats.max,
      stDev: stats.stDev,
      fetchedAt: stats.fetchedAt,
    );
  }

  Future<_IndexStats> _fetchIndexStats({
    required String metric,
    required List<LatLng> coordinates,
    required String metricLabel,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final ring = coordinates.map((c) => [c.longitude, c.latitude]).toList();
      if (ring.isNotEmpty &&
          (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
        ring.add(ring.first);
      }

      final rangeEnd = to ?? DateTime.now();
      final rangeStart = from ?? rangeEnd.subtract(const Duration(days: 30));

      final rangeStartUtc = rangeStart.toUtc();
      final rangeEndUtc = rangeEnd.toUtc();

      _log.i(
        'SentinelHubService._fetchIndexStats: '
        'Requesting $metric statistics for ${coordinates.length} vertices '
        '(${rangeStartUtc.toIso8601String()} → ${rangeEndUtc.toIso8601String()})',
      );

      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'coordinates': ring,
              'metric': metric,
              'from': rangeStartUtc.toIso8601String(),
              'to': rangeEndUtc.toIso8601String(),
            }),
          )
          .timeout(_timeout);

      if (res.statusCode == 404) {
        throw ServiceUnavailableException(
          'Recent satellite imagery for this farm is too cloud-covered to compute $metricLabel data. Try again later.',
        );
      }

      if (res.statusCode != 200) {
        _log.w(
            'SentinelHubService._fetchIndexStats: HTTP ${res.statusCode} – ${res.body}');
        throw ServiceUnavailableException(
          extractApiMessage(res.body) ??
              'Satellite data provider returned an error fetching $metricLabel (HTTP ${res.statusCode}).',
        );
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final fetchedAtStr = decoded['fetchedAt'] as String?;
      final stats = _IndexStats(
        mean: (decoded['mean'] as num? ?? 0).toDouble(),
        min: (decoded['min'] as num? ?? 0).toDouble(),
        max: (decoded['max'] as num? ?? 0).toDouble(),
        stDev: (decoded['stDev'] as num? ?? 0).toDouble(),
        fetchedAt: fetchedAtStr != null
            ? DateTime.parse(fetchedAtStr)
            : DateTime.now(),
      );
      _log.i(
        'SentinelHubService._fetchIndexStats: '
        '$metric mean=${stats.mean.toStringAsFixed(3)} '
        '(min=${stats.min.toStringAsFixed(3)}, max=${stats.max.toStringAsFixed(3)})',
      );
      return stats;
    } on ServiceUnavailableException {
      rethrow;
    } catch (e, st) {
      _log.e('SentinelHubService._fetchIndexStats: Error – $e', stackTrace: st);
      throw ServiceUnavailableException(
        isNetworkError(e)
            ? 'Could not reach the satellite monitoring service — check your internet connection.'
            : 'Something went wrong fetching $metricLabel data.',
        isNetworkError: isNetworkError(e),
      );
    }
  }

  /// Fetches a colorized, per-pixel NDVI or NDWI raster for the farm
  /// polygon, clipped to its exact shape (pixels outside are transparent).
  /// [metric] must be `'ndvi'` or `'ndwi'`.
  Future<RasterOverlayData> fetchColorizedRaster({
    required List<LatLng> coordinates,
    required String metric,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final ring = coordinates.map((c) => [c.longitude, c.latitude]).toList();
      if (ring.isNotEmpty &&
          (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
        ring.add(ring.first);
      }

      final rangeEnd = to ?? DateTime.now();
      final rangeStart = from ?? rangeEnd.subtract(const Duration(days: 30));
      final rangeStartUtc = rangeStart.toUtc();
      final rangeEndUtc = rangeEnd.toUtc();

      _log.i(
        'SentinelHubService.fetchColorizedRaster: '
        'Requesting $metric raster for ${coordinates.length} vertices',
      );

      final res = await http
          .post(
            Uri.parse(_rasterEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'coordinates': ring,
              'metric': metric,
              'from': rangeStartUtc.toIso8601String(),
              'to': rangeEndUtc.toIso8601String(),
            }),
          )
          .timeout(_rasterTimeout);

      if (res.statusCode != 200) {
        _log.w(
            'SentinelHubService.fetchColorizedRaster: HTTP ${res.statusCode} – ${res.body}');
        throw ServiceUnavailableException(
          extractApiMessage(res.body) ??
              'Could not render the $metric map overlay (HTTP ${res.statusCode}).',
        );
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final bbox = decoded['bbox'] as Map<String, dynamic>;
      final fetchedAtStr = decoded['fetchedAt'] as String?;
      final raster = RasterOverlayData(
        pngBytes: base64Decode(decoded['imageBase64'] as String),
        bounds: LatLngBounds(
          southwest: LatLng(
            (bbox['south'] as num).toDouble(),
            (bbox['west'] as num).toDouble(),
          ),
          northeast: LatLng(
            (bbox['north'] as num).toDouble(),
            (bbox['east'] as num).toDouble(),
          ),
        ),
        fetchedAt: fetchedAtStr != null
            ? DateTime.parse(fetchedAtStr)
            : DateTime.now(),
      );
      _log.i(
        'SentinelHubService.fetchColorizedRaster: '
        '${raster.pngBytes.length} bytes received for $metric',
      );
      return raster;
    } on ServiceUnavailableException {
      rethrow;
    } catch (e, st) {
      _log.e('SentinelHubService.fetchColorizedRaster: Error – $e',
          stackTrace: st);
      throw ServiceUnavailableException(
        isNetworkError(e)
            ? 'Could not reach the map overlay service — check your internet connection.'
            : 'Something went wrong rendering the map overlay.',
        isNetworkError: isNetworkError(e),
      );
    }
  }
}

/// Internal shape shared by [SentinelHubService.fetchNdwi] and
/// [SentinelHubService.fetchNdviStats] before being wrapped into their
/// distinct public result types.
class _IndexStats {
  final double mean;
  final double min;
  final double max;
  final double stDev;
  final DateTime fetchedAt;

  const _IndexStats({
    required this.mean,
    required this.min,
    required this.max,
    required this.stDev,
    required this.fetchedAt,
  });
}
