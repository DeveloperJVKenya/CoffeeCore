import 'package:cloud_firestore/cloud_firestore.dart';

class PestData {
  final String name;
  final String imagePath;
  final List<String> preventionStrategies; // Renamed to Possible Strategies
  final String activeAgent; // Used in Intervention(Active Ingredient)
  final List<String> possibleCauses; // Renamed to Possible Causes
  final List<String> herbicides; // Renamed to Herbicides/Pesticides

  PestData({
    required this.name,
    required this.imagePath,
    required this.preventionStrategies,
    required this.activeAgent,
    required this.possibleCauses,
    required this.herbicides,
  });

  // Static pestLibrary is optional now since PestManagementPage handles dynamic data
  static final Map<String, PestData> pestLibrary = {};
}

class PestIntervention {
  final String? id; // Firestore document ID
  final String pestName;
  final String cropType;
  final String cropStage;
  final String intervention;
  final double? area;
  final String areaUnit;
  final Timestamp timestamp;
  final String userId;
  final bool isDeleted;
  final String? amount;

  PestIntervention({
    this.id,
    required this.pestName,
    required this.cropType,
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
      'pestName': pestName,
      'cropType': cropType,
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

  factory PestIntervention.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data()!;
    return PestIntervention(
      id: snapshot.id,
      pestName: data['pestName'] as String? ?? 'Unknown',
      cropType: data['cropType'] as String? ?? 'Unknown',
      cropStage: data['cropStage'] as String? ?? 'Unknown',
      intervention: data['intervention'] as String? ?? '',
      area: data['area'] as double?,
      areaUnit:
          data['areaUnit'] as String? ?? 'Acres', // Updated default to Acres
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      userId: data['userId'] as String? ?? 'Unknown',
      isDeleted: data['isDeleted'] as bool? ?? false,
      amount: data['amount'] as String?,
    );
  }

  factory PestIntervention.fromMap(Map<String, dynamic> map, String docId) {
    return PestIntervention(
      id: docId,
      pestName: map['pestName'] as String,
      cropType: map['cropType'] as String,
      cropStage: map['cropStage'] as String,
      intervention: map['intervention'] as String,
      area: map['area'] as double?,
      areaUnit: map['areaUnit'] as String,
      timestamp: map['timestamp'] as Timestamp,
      userId: map['userId'] as String,
      isDeleted: map['isDeleted'] as bool,
      amount: map['amount'] as String?,
    );
  }
}
