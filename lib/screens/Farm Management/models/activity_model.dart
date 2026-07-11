import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cycle_stage.dart';

/// Kind of farm activity being logged. Mirrors the old
/// labour/mechanical/input/miscellaneous cost categories from
/// `data_manager.dart` plus a non-cost "observation" type.
enum ActivityType { labour, mechanical, input, miscellaneous, observation }

extension ActivityTypeX on ActivityType {
  String get label {
    switch (this) {
      case ActivityType.labour:
        return 'Labour';
      case ActivityType.mechanical:
        return 'Mechanical';
      case ActivityType.input:
        return 'Input';
      case ActivityType.miscellaneous:
        return 'Miscellaneous';
      case ActivityType.observation:
        return 'Observation';
    }
  }

  String get storageValue => name;

  static ActivityType fromStorage(String? value) {
    return ActivityType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ActivityType.observation,
    );
  }
}

/// A single logged farm activity, scoped to a farm and cycle.
class FarmActivity {
  final String? id;
  final String farmId;
  final String cycleId;
  final String userId;
  final ActivityType type;
  final CycleStage stage;
  final DateTime date;
  final String description;
  final double? quantity;
  final String? unit;
  final double cost;
  final List<String> photoUrls;
  final DateTime createdAt;

  const FarmActivity({
    this.id,
    required this.farmId,
    required this.cycleId,
    required this.userId,
    required this.type,
    required this.stage,
    required this.date,
    required this.description,
    this.quantity,
    this.unit,
    this.cost = 0,
    this.photoUrls = const [],
    required this.createdAt,
  });

  factory FarmActivity.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FarmActivity(
      id: doc.id,
      farmId: data['farmId'] as String? ?? '',
      cycleId: data['cycleId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      type: ActivityTypeX.fromStorage(data['type'] as String?),
      stage: CycleStageX.fromStorage(data['stage'] as String?),
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      description: data['description'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble(),
      unit: data['unit'] as String?,
      cost: (data['cost'] as num? ?? 0).toDouble(),
      photoUrls: List<String>.from(data['photoUrls'] ?? const []),
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
      'type': type.storageValue,
      'stage': stage.storageValue,
      'date': Timestamp.fromDate(date),
      'description': description,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      'cost': cost,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
