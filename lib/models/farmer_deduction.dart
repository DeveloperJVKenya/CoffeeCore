import 'package:cloud_firestore/cloud_firestore.dart';

/// Category of a cooperative-side deduction against a farmer's settlement
/// balance — inputs the cooperative supplied the farmer, or costs incurred
/// moving their coffee from submission to market.
enum DeductionCategory {
  seedlings,
  fertilizer,
  transport,
  processingFee,
  other
}

extension DeductionCategoryX on DeductionCategory {
  String get label {
    switch (this) {
      case DeductionCategory.seedlings:
        return 'Seedlings';
      case DeductionCategory.fertilizer:
        return 'Fertilizer';
      case DeductionCategory.transport:
        return 'Transport';
      case DeductionCategory.processingFee:
        return 'Processing Fee';
      case DeductionCategory.other:
        return 'Other';
    }
  }

  String get storageValue => name;

  static DeductionCategory fromStorage(String? value) {
    return DeductionCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => DeductionCategory.other,
    );
  }
}

/// A single deduction entry against a farmer's running settlement balance —
/// not tied to any specific produce submission. Stored at
/// `{coop}_FarmerDeductions/{userId}/entries/{deductionId}`.
class FarmerDeduction {
  final String? id;
  final String userId;
  final DeductionCategory category;
  final String description;
  final double amount;
  final String date; // yyyy-MM-dd, matching FarmerProduce.submissionDate
  final String recordedBy;
  final Timestamp timestamp;

  const FarmerDeduction({
    this.id,
    required this.userId,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.recordedBy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'category': category.storageValue,
      'description': description,
      'amount': amount,
      'date': date,
      'recordedBy': recordedBy,
      'timestamp': timestamp,
    };
  }

  factory FarmerDeduction.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FarmerDeduction(
      id: doc.id,
      userId:
          doc.reference.parent.parent?.id ?? data['userId']?.toString() ?? '',
      category: DeductionCategoryX.fromStorage(data['category']?.toString()),
      description: data['description']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: data['date']?.toString() ?? '',
      recordedBy: data['recordedBy']?.toString() ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
