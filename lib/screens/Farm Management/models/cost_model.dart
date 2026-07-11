import 'package:cloud_firestore/cloud_firestore.dart';

/// Cost category, aligned with the old data_manager.dart cost buckets
/// (labour, mechanical/equipment, input, miscellaneous).
enum CostCategory { labour, mechanical, input, miscellaneous }

extension CostCategoryX on CostCategory {
  String get label {
    switch (this) {
      case CostCategory.labour:
        return 'Labour';
      case CostCategory.mechanical:
        return 'Mechanical/Equipment';
      case CostCategory.input:
        return 'Input';
      case CostCategory.miscellaneous:
        return 'Miscellaneous';
    }
  }

  String get storageValue => name;

  static CostCategory fromStorage(String? value) {
    return CostCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => CostCategory.miscellaneous,
    );
  }
}

/// A single cost/expense entry attached to a farm + cycle.
class CostEntry {
  final String? id;
  final String farmId;
  final String cycleId;
  final String userId;
  final CostCategory category;
  final String description;
  final double amount;
  final DateTime date;
  final DateTime createdAt;

  const CostEntry({
    this.id,
    required this.farmId,
    required this.cycleId,
    required this.userId,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  factory CostEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CostEntry(
      id: doc.id,
      farmId: data['farmId'] as String? ?? '',
      cycleId: data['cycleId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      category: CostCategoryX.fromStorage(data['category'] as String?),
      description: data['description'] as String? ?? '',
      amount: (data['amount'] as num? ?? 0).toDouble(),
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
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
      'category': category.storageValue,
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
