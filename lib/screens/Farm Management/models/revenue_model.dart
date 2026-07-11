import 'package:cloud_firestore/cloud_firestore.dart';

/// A single revenue/sale entry attached to a farm + cycle.
class RevenueEntry {
  final String? id;
  final String farmId;
  final String cycleId;
  final String userId;
  final String variety;
  final double kg;
  final String? grade;
  final double pricePerKg;
  final double amount;
  final DateTime date;
  final DateTime createdAt;

  const RevenueEntry({
    this.id,
    required this.farmId,
    required this.cycleId,
    required this.userId,
    required this.variety,
    required this.kg,
    this.grade,
    required this.pricePerKg,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  factory RevenueEntry.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return RevenueEntry(
      id: doc.id,
      farmId: data['farmId'] as String? ?? '',
      cycleId: data['cycleId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      variety: data['variety'] as String? ?? '',
      kg: (data['kg'] as num? ?? 0).toDouble(),
      grade: data['grade'] as String?,
      pricePerKg: (data['pricePerKg'] as num? ?? 0).toDouble(),
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
      'variety': variety,
      'kg': kg,
      if (grade != null) 'grade': grade,
      'pricePerKg': pricePerKg,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
