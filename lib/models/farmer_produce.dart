import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerProduce {
  final String id;
  final String farmerName;
  final String contact;
  final double totalAmount;
  final Timestamp timestamp;
  final String submissionDate;
  final String submissionId;

  FarmerProduce({
    required this.id,
    required this.farmerName,
    required this.contact,
    required this.totalAmount,
    required this.timestamp,
    required this.submissionDate,
    required this.submissionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'farmerName': farmerName,
      'contact': contact,
      'totalAmount': totalAmount,
      'timestamp': timestamp,
      'submissionDate': submissionDate,
      'submissionId': submissionId,
    };
  }

  factory FarmerProduce.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FarmerProduce(
      id: data['id']?.toString() ?? '',
      farmerName: data['farmerName']?.toString() ?? 'Unknown',
      contact: data['contact']?.toString() ?? 'N/A',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      timestamp: data['timestamp'] ?? Timestamp.now(),
      submissionDate: data['submissionDate']?.toString() ?? '',
      submissionId: data['submissionId']?.toString() ?? doc.id,
    );
  }
}
