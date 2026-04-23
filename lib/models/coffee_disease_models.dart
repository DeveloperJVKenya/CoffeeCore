import 'package:cloud_firestore/cloud_firestore.dart';

class CoffeeDiseaseData {
  final String name;
  final String description;
  final String symptoms;
  final List<String> chemicalControls;
  final List<String> mechanicalControls;
  final List<String> biologicalControls;
  final List<String> possibleCauses;
  final List<String> preventiveMeasures;
  //final List<String> lifecycleImages; // Added this field

  CoffeeDiseaseData({
    required this.name,
    required this.description,
    required this.symptoms,
    required this.chemicalControls,
    required this.mechanicalControls,
    required this.biologicalControls,
    required this.possibleCauses,
    required this.preventiveMeasures,
   // required this.lifecycleImages,// Added this parameter
  });
}

class CoffeeDiseaseIntervention {
  final String? id;
  final String diseaseName;
  final String cropStage;
  final String intervention;
  final double? area;
  final String areaUnit;
  final Timestamp timestamp;
  final String userId;
  final bool isDeleted;
  final String? amount;

  CoffeeDiseaseIntervention({
    this.id,
    required this.diseaseName,
    required this.cropStage,
    required this.intervention,
    this.area,
    required this.areaUnit,
    required this.timestamp,
    required this.userId,
    required this.isDeleted,
    this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'diseaseName': diseaseName,
      'cropStage': cropStage,
      'intervention': intervention,
      'area': area,
      'areaUnit': areaUnit,
      'timestamp': timestamp,
      'userId': userId,
      'isDeleted': isDeleted,
      'amount': amount,
    };
  }

  factory CoffeeDiseaseIntervention.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data()!;
    return CoffeeDiseaseIntervention(
      id: snapshot.id,
      diseaseName: data['diseaseName'] as String? ?? 'Unknown',
      cropStage: data['cropStage'] as String? ?? 'Unknown',
      intervention: data['intervention'] as String? ?? '',
      area: data['area'] as double?,
      areaUnit: data['areaUnit'] as String? ?? 'Acres',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      userId: data['userId'] as String? ?? 'Unknown',
      isDeleted: data['isDeleted'] as bool? ?? false,
      amount: data['amount'] as String?,
    );
  }
}
