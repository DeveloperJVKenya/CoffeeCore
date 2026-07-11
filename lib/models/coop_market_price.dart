import 'package:cloud_firestore/cloud_firestore.dart';

class CoopMarketPrice {
  final String id;
  final String cooperative;
  final String variety;
  final double price;
  final String updatedBy;
  final Timestamp timestamp;

  CoopMarketPrice({
    required this.id,
    required this.cooperative,
    required this.variety,
    required this.price,
    required this.updatedBy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'cooperative': cooperative,
      'variety': variety,
      'price': price,
      'updatedBy': updatedBy,
      'timestamp': timestamp,
    };
  }

  factory CoopMarketPrice.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data()!;
    return CoopMarketPrice(
      id: snapshot.id,
      cooperative: data['cooperative'] ?? '',
      variety: data['variety'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      updatedBy: data['updatedBy'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
