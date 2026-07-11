import 'package:cloud_firestore/cloud_firestore.dart';

/// A single harvest yield record attached to a farm + cycle.
class YieldRecord {
  final String? id;
  final String farmId;
  final String cycleId;
  final String userId;
  final DateTime date;
  final double kgHarvested;
  final String? grade;
  final double? moistureContent;
  final String? notes;
  final DateTime createdAt;

  const YieldRecord({
    this.id,
    required this.farmId,
    required this.cycleId,
    required this.userId,
    required this.date,
    required this.kgHarvested,
    this.grade,
    this.moistureContent,
    this.notes,
    required this.createdAt,
  });

  factory YieldRecord.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return YieldRecord(
      id: doc.id,
      farmId: data['farmId'] as String? ?? '',
      cycleId: data['cycleId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      kgHarvested: (data['kgHarvested'] as num? ?? 0).toDouble(),
      grade: data['grade'] as String?,
      moistureContent: (data['moistureContent'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'farmId': farmId,
      'cycleId': cycleId,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'kgHarvested': kgHarvested,
      if (grade != null) 'grade': grade,
      if (moistureContent != null) 'moistureContent': moistureContent,
      if (notes != null) 'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
