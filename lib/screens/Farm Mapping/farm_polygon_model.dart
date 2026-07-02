import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:coffeecore/screens/Farm%20Mapping/eudr_compliance_service.dart';

// ── EUDR Compliance Data ────────────────────────────────────
class EudrComplianceData {
  final bool isCompliant;
  final bool wasForestedBefore2020;
  final double treeCoverPercent2000;
  final double treeCoverLossAreaHa;
  final double remainingTreeCoverPercent;
  final String explanation;
  final String recommendation;
  final String dataSource;
  final DateTime checkedAt;

  const EudrComplianceData({
    required this.isCompliant,
    required this.wasForestedBefore2020,
    required this.treeCoverPercent2000,
    required this.treeCoverLossAreaHa,
    required this.remainingTreeCoverPercent,
    required this.explanation,
    required this.recommendation,
    required this.dataSource,
    required this.checkedAt,
  });

  factory EudrComplianceData.fromResult(EudrComplianceResult result) {
    return EudrComplianceData(
      isCompliant: result.isCompliant,
      wasForestedBefore2020: result.wasForestedBefore2020,
      treeCoverPercent2000: result.treeCoverPercent2000,
      treeCoverLossAreaHa: result.treeCoverLossAreaHa,
      remainingTreeCoverPercent: result.remainingTreeCoverPercent,
      explanation: result.explanation,
      recommendation: result.recommendation,
      dataSource: result.dataSource,
      checkedAt: result.checkedAt,
    );
  }

  factory EudrComplianceData.fromMap(Map<String, dynamic> map) {
    return EudrComplianceData(
      isCompliant: map['isCompliant'] as bool? ?? false,
      wasForestedBefore2020: map['wasForestedBefore2020'] as bool? ?? false,
      treeCoverPercent2000: (map['treeCoverPercent2000'] as num? ?? 0).toDouble(),
      treeCoverLossAreaHa: (map['treeCoverLossAreaHa'] as num? ?? 0).toDouble(),
      remainingTreeCoverPercent: (map['remainingTreeCoverPercent'] as num? ?? 0).toDouble(),
      explanation: map['explanation'] as String? ?? '',
      recommendation: map['recommendation'] as String? ?? '',
      dataSource: map['dataSource'] as String? ?? '',
      checkedAt: map['checkedAt'] != null
          ? (map['checkedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isCompliant': isCompliant,
      'wasForestedBefore2020': wasForestedBefore2020,
      'treeCoverPercent2000': treeCoverPercent2000,
      'treeCoverLossAreaHa': treeCoverLossAreaHa,
      'remainingTreeCoverPercent': remainingTreeCoverPercent,
      'explanation': explanation,
      'recommendation': recommendation,
      'dataSource': dataSource,
      'checkedAt': Timestamp.fromDate(checkedAt),
    };
  }
}

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
  final String? agroMonitoringPolyId;
  final EudrComplianceData? eudrCompliance;

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
    this.eudrCompliance,
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
      eudrCompliance: data['eudrCompliance'] != null
          ? EudrComplianceData.fromMap(
              data['eudrCompliance'] as Map<String, dynamic>)
          : null,
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
      if (eudrCompliance != null) 'eudrCompliance': eudrCompliance!.toMap(),
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
    EudrComplianceData? eudrCompliance,
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
      eudrCompliance: eudrCompliance ?? this.eudrCompliance,
    );
  }

  // ── Derived helpers ─────────────────────────────────────────

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

  String get areaLabel {
    if (areaHectares >= 1.0) {
      return '${areaHectares.toStringAsFixed(2)} ha';
    }
    return '${(areaHectares * 10000).toStringAsFixed(0)} m²';
  }

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
  final double humidity;
  final double rainfallMm;
  final double windSpeedMs;
  final String weatherDescription;
  final String weatherIcon;
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

  // Google Weather API returns an iconBaseUri that needs a file-type suffix.
  String get iconUrl => weatherIcon.isEmpty ? '' : '$weatherIcon.png';
}

// ── Satellite / NDVI data snapshot ───────────────────────────
class SatelliteData {
  final double ndviScore;
  final String vegetationHealth;
  final double soilMoistureIndex;
  final DateTime fetchedAt;
  final String dataSource;

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

  Color get healthColor {
    switch (vegetationHealth.toLowerCase()) {
      case 'excellent':
        return const Color(0xFF2E7D32);
      case 'good':
        return const Color(0xFF66BB6A);
      case 'fair':
        return const Color(0xFFFFB300);
      case 'poor':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF78909C);
    }
  }

  double get ndviFraction => ((ndviScore + 1) / 2).clamp(0.0, 1.0);
}