import 'package:cloud_firestore/cloud_firestore.dart';

/// A record of an amount actually disbursed to a farmer against their
/// settlement balance. Stored at
/// `{coop}_FarmerPayouts/{userId}/entries/{payoutId}`.
class FarmerPayout {
  final String? id;
  final String userId;
  final double amount;
  final String date; // yyyy-MM-dd, matching FarmerProduce.submissionDate
  final String note;
  final String recordedBy;
  final Timestamp timestamp;

  const FarmerPayout({
    this.id,
    required this.userId,
    required this.amount,
    required this.date,
    required this.note,
    required this.recordedBy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'date': date,
      'note': note,
      'recordedBy': recordedBy,
      'timestamp': timestamp,
    };
  }

  factory FarmerPayout.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FarmerPayout(
      id: doc.id,
      userId:
          doc.reference.parent.parent?.id ?? data['userId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: data['date']?.toString() ?? '',
      note: data['note']?.toString() ?? '',
      recordedBy: data['recordedBy']?.toString() ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
