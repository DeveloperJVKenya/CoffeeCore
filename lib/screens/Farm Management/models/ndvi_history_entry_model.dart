import 'package:cloud_firestore/cloud_firestore.dart';

/// A single NDVI/NDWI snapshot appended to a farm's history subcollection,
/// used to compute vegetation/moisture trends over time (e.g. for the
/// Drought Risk Index). Unlike [SatelliteData], which only holds the latest
/// snapshot, entries here accumulate across refreshes.
class NdviHistoryEntry {
  final double ndvi;
  final double? ndwi;
  final DateTime fetchedAt;

  const NdviHistoryEntry({
    required this.ndvi,
    this.ndwi,
    required this.fetchedAt,
  });

  factory NdviHistoryEntry.fromMap(Map<String, dynamic> map) {
    return NdviHistoryEntry(
      ndvi: (map['ndvi'] as num? ?? 0).toDouble(),
      ndwi: (map['ndwi'] as num?)?.toDouble(),
      fetchedAt: map['fetchedAt'] != null
          ? (map['fetchedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ndvi': ndvi,
      if (ndwi != null) 'ndwi': ndwi,
      'fetchedAt': Timestamp.fromDate(fetchedAt),
    };
  }
}
