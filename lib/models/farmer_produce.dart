import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerProduce {
  final String id;
  final String farmerName;
  final String contact;
  final double totalAmount;
  final Timestamp timestamp;
  final String submissionDate;
  final String submissionId;
  // Coffee variety selected at submission time, and the price/kg snapshot
  // from {coop}_coffeeprices at that moment — not a live lookup, so a later
  // price change never rewrites a historical submission's value. '' / 0 for
  // submissions recorded before this field existed (pre-settlement-feature).
  final String variety;
  final double pricePerKg;
  final double grossValue;

  FarmerProduce({
    required this.id,
    required this.farmerName,
    required this.contact,
    required this.totalAmount,
    required this.timestamp,
    required this.submissionDate,
    required this.submissionId,
    this.variety = '',
    this.pricePerKg = 0,
    this.grossValue = 0,
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
      'variety': variety,
      'pricePerKg': pricePerKg,
      'grossValue': grossValue,
    };
  }

  factory FarmerProduce.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FarmerProduce(
      // Derived from the Firestore path (submissions live at
      // {coop}_FarmerProduce/{userId}/submissions/{submissionId}) rather
      // than trusting a stored 'id' field, since that field can be absent
      // on documents written before it was included, or edited by hand.
      id: doc.reference.parent.parent?.id ?? data['id']?.toString() ?? '',
      farmerName: data['farmerName']?.toString() ?? 'Unknown',
      contact: data['contact']?.toString() ?? 'N/A',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      submissionDate: data['submissionDate']?.toString() ?? '',
      submissionId: data['submissionId']?.toString() ?? doc.id,
      variety: data['variety']?.toString() ?? '',
      pricePerKg: (data['pricePerKg'] as num?)?.toDouble() ?? 0.0,
      grossValue: (data['grossValue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
