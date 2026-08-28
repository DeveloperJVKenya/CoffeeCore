import 'package:cloud_firestore/cloud_firestore.dart';

/// A farmer's registered farm details plus their latest produce submission
/// total, stored at `{coop}_ProduceData/{userId}`.
class ProduceData {
  final String id; // Document ID (userId)
  final String farmerName;
  final String contact;
  final String farmArea;
  final double latestTotalAmount; // From latest submission
  final Timestamp timestamp;
  final String cooperative; // For MainAdmins

  ProduceData({
    required this.id,
    required this.farmerName,
    required this.contact,
    required this.farmArea,
    required this.latestTotalAmount,
    required this.timestamp,
    this.cooperative = '',
  });

  // Writes lowercase keys, matching the sibling {coop}_FarmerProduce
  // submissions collection's convention (farmerName/contact/totalAmount).
  // Older documents written before this change have capitalized keys
  // (FarmerName/Contact/FarmArea) instead — fromDocument below reads both,
  // so those documents keep working without a data migration. This uses
  // SetOptions(merge: true) at the call site, so an old document's
  // capitalized fields aren't deleted by a write in the new format; they're
  // simply superseded and left unused.
  Map<String, dynamic> toMap() {
    return {
      'farmerName': farmerName,
      'contact': contact,
      'farmArea': farmArea,
      'timestamp': timestamp,
    };
  }

  factory ProduceData.fromDocument(DocumentSnapshot? doc,
      Map<String, String?> userData, double latestTotalAmount,
      [String cooperative = '']) {
    final data = doc?.data() as Map<String, dynamic>? ?? {};
    return ProduceData(
      id: doc?.id ?? userData['id']!,
      // Prefer the new lowercase key; fall back to the legacy capitalized
      // key for documents written before this model was normalized.
      farmerName: data['farmerName']?.toString() ??
          data['FarmerName']?.toString() ??
          userData['fullName'] ??
          '-',
      contact: data['contact']?.toString() ??
          data['Contact']?.toString() ??
          userData['phoneNumber'] ??
          '-',
      farmArea:
          data['farmArea']?.toString() ?? data['FarmArea']?.toString() ?? '-',
      latestTotalAmount: latestTotalAmount,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      cooperative: cooperative,
    );
  }
}
