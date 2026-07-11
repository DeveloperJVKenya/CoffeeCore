import 'package:cloud_firestore/cloud_firestore.dart';

enum InventoryCategory { fertilizer, pesticide, tool, seedling, other }

extension InventoryCategoryX on InventoryCategory {
  String get label {
    switch (this) {
      case InventoryCategory.fertilizer:
        return 'Fertilizer';
      case InventoryCategory.pesticide:
        return 'Pesticide';
      case InventoryCategory.tool:
        return 'Tool/Equipment';
      case InventoryCategory.seedling:
        return 'Seedling';
      case InventoryCategory.other:
        return 'Other';
    }
  }

  String get storageValue => name;

  static InventoryCategory fromStorage(String? value) {
    return InventoryCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => InventoryCategory.other,
    );
  }
}

/// A stock keeping item tracked for a farm (e.g. fertilizer, tools).
class InventoryItem {
  final String? id;
  final String farmId;
  final String userId;
  final String name;
  final InventoryCategory category;
  final String unit;
  final double quantityOnHand;
  final double reorderLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryItem({
    this.id,
    required this.farmId,
    required this.userId,
    required this.name,
    required this.category,
    required this.unit,
    this.quantityOnHand = 0,
    this.reorderLevel = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => quantityOnHand <= reorderLevel;

  factory InventoryItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return InventoryItem(
      id: doc.id,
      farmId: data['farmId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      category: InventoryCategoryX.fromStorage(data['category'] as String?),
      unit: data['unit'] as String? ?? 'kg',
      quantityOnHand: (data['quantityOnHand'] as num? ?? 0).toDouble(),
      reorderLevel: (data['reorderLevel'] as num? ?? 0).toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'farmId': farmId,
      'userId': userId,
      'name': name,
      'category': category.storageValue,
      'unit': unit,
      'quantityOnHand': quantityOnHand,
      'reorderLevel': reorderLevel,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

enum InventoryTransactionType { stockIn, stockOut }

extension InventoryTransactionTypeX on InventoryTransactionType {
  String get label =>
      this == InventoryTransactionType.stockIn ? 'Stock In' : 'Stock Out';

  String get storageValue => name;

  static InventoryTransactionType fromStorage(String? value) {
    return InventoryTransactionType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => InventoryTransactionType.stockOut,
    );
  }
}

/// A single stock movement (in or out) against an [InventoryItem].
class InventoryTransaction {
  final String? id;
  final String farmId;
  final String itemId;
  final String userId;
  final InventoryTransactionType type;
  final double quantity;
  final DateTime date;
  final String? relatedActivityId;
  final DateTime createdAt;

  const InventoryTransaction({
    this.id,
    required this.farmId,
    required this.itemId,
    required this.userId,
    required this.type,
    required this.quantity,
    required this.date,
    this.relatedActivityId,
    required this.createdAt,
  });

  factory InventoryTransaction.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return InventoryTransaction(
      id: doc.id,
      farmId: data['farmId'] as String? ?? '',
      itemId: data['itemId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      type: InventoryTransactionTypeX.fromStorage(data['type'] as String?),
      quantity: (data['quantity'] as num? ?? 0).toDouble(),
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      relatedActivityId: data['relatedActivityId'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'farmId': farmId,
      'itemId': itemId,
      'userId': userId,
      'type': type.storageValue,
      'quantity': quantity,
      'date': Timestamp.fromDate(date),
      if (relatedActivityId != null) 'relatedActivityId': relatedActivityId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
