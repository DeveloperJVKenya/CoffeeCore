import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── Main farm polygon record ──────────────────────────────────
class FarmPolygon {
  final String? farmId;
  final String userId;
  final String farmName;
  final List<LatLng> coordinates;
  final double areaHectares;
  final double perimeterMeters;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final ClimateData? climateData;
  final SatelliteData? satelliteData;
  final String? agroMonitoringPolyId; // Polygon ID from AgroMonitoring API

  const FarmPolygon({
    this.farmId,
    required this.userId,
    required this.farmName,
    required this.coordinates,
    required this.areaHectares,
    required this.perimeterMeters,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.climateData,
    this.satelliteData,
    this.agroMonitoringPolyId,
  });

  // ── Firestore deserialization ───────────────────────────────
  factory FarmPolygon.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    final rawCoords = (data['coordinates'] as List<dynamic>? ?? []);
    final coordsList = rawCoords.map((c) {
      final map = c as Map<String, dynamic>;
      return LatLng(
        (map['lat'] as num).toDouble(),
        (map['lng'] as num).toDouble(),
      );
    }).toList();

    return FarmPolygon(
      farmId: doc.id,
      userId: data['userId'] as String? ?? '',
      farmName: data['farmName'] as String? ?? 'Unnamed Farm',
      coordinates: coordsList,
      areaHectares: (data['areaHectares'] as num? ?? 0).toDouble(),
      perimeterMeters: (data['perimeterMeters'] as num? ?? 0).toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      description: data['description'] as String?,
      agroMonitoringPolyId: data['agroMonitoringPolyId'] as String?,
      climateData: data['climateData'] != null
          ? ClimateData.fromMap(data['climateData'] as Map<String, dynamic>)
          : null,
      satelliteData: data['satelliteData'] != null
          ? SatelliteData.fromMap(
              data['satelliteData'] as Map<String, dynamic>)
          : null,
    );
  }

  // ── Firestore serialization ─────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'farmName': farmName,
      'coordinates': coordinates
          .map((c) => {'lat': c.latitude, 'lng': c.longitude})
          .toList(),
      'areaHectares': areaHectares,
      'perimeterMeters': perimeterMeters,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (agroMonitoringPolyId != null)
        'agroMonitoringPolyId': agroMonitoringPolyId,
      if (climateData != null) 'climateData': climateData!.toMap(),
      if (satelliteData != null) 'satelliteData': satelliteData!.toMap(),
    };
  }

  // ── Immutable copy helper ───────────────────────────────────
  FarmPolygon copyWith({
    String? farmId,
    String? farmName,
    List<LatLng>? coordinates,
    double? areaHectares,
    double? perimeterMeters,
    DateTime? updatedAt,
    String? description,
    ClimateData? climateData,
    SatelliteData? satelliteData,
    String? agroMonitoringPolyId,
  }) {
    return FarmPolygon(
      farmId: farmId ?? this.farmId,
      userId: userId,
      farmName: farmName ?? this.farmName,
      coordinates: coordinates ?? this.coordinates,
      areaHectares: areaHectares ?? this.areaHectares,
      perimeterMeters: perimeterMeters ?? this.perimeterMeters,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      climateData: climateData ?? this.climateData,
      satelliteData: satelliteData ?? this.satelliteData,
      agroMonitoringPolyId:
          agroMonitoringPolyId ?? this.agroMonitoringPolyId,
    );
  }

  // ── Derived helpers ─────────────────────────────────────────

  /// Geometric center of the polygon for camera targeting
  LatLng get center {
    if (coordinates.isEmpty) return const LatLng(0, 0);
    final lat = coordinates
            .map((c) => c.latitude)
            .reduce((a, b) => a + b) /
        coordinates.length;
    final lng = coordinates
            .map((c) => c.longitude)
            .reduce((a, b) => a + b) /
        coordinates.length;
    return LatLng(lat, lng);
  }

  /// Human-readable area label (ha or m²)
  String get areaLabel {
    if (areaHectares >= 1.0) {
      return '${areaHectares.toStringAsFixed(2)} ha';
    }
    return '${(areaHectares * 10000).toStringAsFixed(0)} m²';
  }

  /// Human-readable perimeter label (km or m)
  String get perimeterLabel {
    if (perimeterMeters >= 1000) {
      return '${(perimeterMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${perimeterMeters.toStringAsFixed(0)} m';
  }
}

// ── Climate / weather snapshot ────────────────────────────────
class ClimateData {
  final double temperatureCelsius;
  final double humidity; // %
  final double rainfallMm; // mm in last hour
  final double windSpeedMs; // m/s
  final String weatherDescription;
  final String weatherIcon; // OpenWeatherMap icon code e.g. "01d"
  final DateTime fetchedAt;

  const ClimateData({
    required this.temperatureCelsius,
    required this.humidity,
    required this.rainfallMm,
    required this.windSpeedMs,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.fetchedAt,
  });

  factory ClimateData.fromMap(Map<String, dynamic> map) {
    return ClimateData(
      temperatureCelsius:
          (map['temperatureCelsius'] as num? ?? 0).toDouble(),
      humidity: (map['humidity'] as num? ?? 0).toDouble(),
      rainfallMm: (map['rainfallMm'] as num? ?? 0).toDouble(),
      windSpeedMs: (map['windSpeedMs'] as num? ?? 0).toDouble(),
      weatherDescription:
          map['weatherDescription'] as String? ?? '',
      weatherIcon: map['weatherIcon'] as String? ?? '01d',
      fetchedAt: map['fetchedAt'] != null
          ? (map['fetchedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temperatureCelsius': temperatureCelsius,
      'humidity': humidity,
      'rainfallMm': rainfallMm,
      'windSpeedMs': windSpeedMs,
      'weatherDescription': weatherDescription,
      'weatherIcon': weatherIcon,
      'fetchedAt': Timestamp.fromDate(fetchedAt),
    };
  }

  /// OpenWeatherMap icon URL builder
  String get iconUrl =>
      'https://openweathermap.org/img/wn/$weatherIcon@2x.png';
}

// ── Satellite / NDVI data snapshot ───────────────────────────
class SatelliteData {
  /// NDVI score: -1.0 → 1.0
  /// Healthy coffee vegetation: 0.40 – 0.85
  final double ndviScore;
  final String vegetationHealth; // 'Excellent' | 'Good' | 'Fair' | 'Poor'
  final double soilMoistureIndex; // 0 – 100 (%)
  final DateTime fetchedAt;
  final String dataSource; // e.g. 'Sentinel-2 / AgroMonitoring'

  const SatelliteData({
    required this.ndviScore,
    required this.vegetationHealth,
    required this.soilMoistureIndex,
    required this.fetchedAt,
    required this.dataSource,
  });

  factory SatelliteData.fromMap(Map<String, dynamic> map) {
    return SatelliteData(
      ndviScore: (map['ndviScore'] as num? ?? 0).toDouble(),
      vegetationHealth:
          map['vegetationHealth'] as String? ?? 'Unknown',
      soilMoistureIndex:
          (map['soilMoistureIndex'] as num? ?? 0).toDouble(),
      fetchedAt: map['fetchedAt'] != null
          ? (map['fetchedAt'] as Timestamp).toDate()
          : DateTime.now(),
      dataSource: map['dataSource'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ndviScore': ndviScore,
      'vegetationHealth': vegetationHealth,
      'soilMoistureIndex': soilMoistureIndex,
      'fetchedAt': Timestamp.fromDate(fetchedAt),
      'dataSource': dataSource,
    };
  }

  /// Color-coded health badge matching Agronica GIAS convention
  Color get healthColor {
    switch (vegetationHealth.toLowerCase()) {
      case 'excellent':
        return const Color(0xFF2E7D32); // deep green
      case 'good':
        return const Color(0xFF66BB6A); // light green
      case 'fair':
        return const Color(0xFFFFB300); // amber
      case 'poor':
        return const Color(0xFFE53935); // red
      default:
        return const Color(0xFF78909C); // grey
    }
  }

  /// NDVI bar fill fraction (0.0 – 1.0 clamped for display)
  double get ndviFraction => ((ndviScore + 1) / 2).clamp(0.0, 1.0);
}