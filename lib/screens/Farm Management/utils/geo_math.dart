import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Boundary geometry shared by every farm-capture flow (live GPS walk and
/// remote zoom-and-tap alike): distance, area, perimeter and their display
/// labels. Kept in one place so the two capture screens can't drift apart.
class GeoMath {
  const GeoMath._();

  static const double earthRadiusMeters = 6371000.0;

  static double haversineDistanceMeters(LatLng a, LatLng b) {
    final double dLat = (b.latitude - a.latitude) * math.pi / 180;
    final double dLng = (b.longitude - a.longitude) * math.pi / 180;
    final double sinDLat = math.sin(dLat / 2);
    final double sinDLng = math.sin(dLng / 2);
    final double aVal = sinDLat * sinDLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinDLng *
            sinDLng;
    return earthRadiusMeters *
        2 *
        math.atan2(
          math.sqrt(aVal),
          math.sqrt(1 - aVal),
        );
  }

  static double shoelaceAreaHectares(List<LatLng> pts) {
    if (pts.length < 3) return 0.0;
    double area = 0.0;
    final int n = pts.length;
    for (int i = 0; i < n; i++) {
      final int j = (i + 1) % n;
      final double xi = pts[i].longitude *
          (math.pi / 180) *
          earthRadiusMeters *
          math.cos(pts[i].latitude * math.pi / 180);
      final double yi = pts[i].latitude * (math.pi / 180) * earthRadiusMeters;
      final double xj = pts[j].longitude *
          (math.pi / 180) *
          earthRadiusMeters *
          math.cos(pts[j].latitude * math.pi / 180);
      final double yj = pts[j].latitude * (math.pi / 180) * earthRadiusMeters;
      area += xi * yj - xj * yi;
    }
    return (area.abs() / 2) / 10000;
  }

  static double haversinePerimeterMeters(List<LatLng> pts) {
    if (pts.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      total += haversineDistanceMeters(pts[i], pts[i + 1]);
    }
    total += haversineDistanceMeters(pts.last, pts.first);
    return total;
  }

  /// Sub-hectare plots read far more clearly in m² than as "0.00 ha".
  static String areaLabel(double hectares) {
    if (hectares >= 1.0) return '${hectares.toStringAsFixed(2)} ha';
    return '${(hectares * 10000).toStringAsFixed(0)} m²';
  }

  /// Keeps large-farm perimeters readable in km instead of a long raw
  /// meter count.
  static String perimeterLabel(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  static LatLng centroid(List<LatLng> pts) {
    if (pts.isEmpty) return const LatLng(0, 0);
    final double lat =
        pts.map((LatLng c) => c.latitude).reduce((a, b) => a + b) / pts.length;
    final double lng =
        pts.map((LatLng c) => c.longitude).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lng);
  }
}
