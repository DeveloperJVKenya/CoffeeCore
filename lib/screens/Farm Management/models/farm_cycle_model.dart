import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cycle_stage.dart';

/// A single stage transition, kept for history/audit purposes.
class StageHistoryEntry {
  final CycleStage stage;
  final DateTime enteredAt;

  const StageHistoryEntry({required this.stage, required this.enteredAt});

  factory StageHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StageHistoryEntry(
      stage: CycleStageX.fromStorage(map['stage'] as String?),
      enteredAt: map['enteredAt'] != null
          ? (map['enteredAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'stage': stage.storageValue,
        'enteredAt': Timestamp.fromDate(enteredAt),
      };
}

enum CycleStatus { active, completed, archived }

extension CycleStatusX on CycleStatus {
  String get storageValue => name;

  static CycleStatus fromStorage(String? value) {
    return CycleStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => CycleStatus.active,
    );
  }
}

/// A growth/production cycle attached to a specific farm (`farmId`).
/// Replaces the old un-scoped `FarmData/{uid}/Cycles/{cycleName}` docs with
/// a typed, farm-aware record stored in the flat `FarmCycles` collection.
class FarmCycle {
  final String? id;
  final String farmId;
  final String userId;
  final String name;
  final int year;
  final String? varietyPlanted;
  final CycleStage currentStage;
  final List<StageHistoryEntry> stageHistory;
  final DateTime startDate;
  final CycleStatus status;
  final double totalCost;
  final double totalRevenue;
  final double profitLoss;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FarmCycle({
    this.id,
    required this.farmId,
    required this.userId,
    required this.name,
    required this.year,
    this.varietyPlanted,
    this.currentStage = CycleStage.landPrep,
    this.stageHistory = const [],
    required this.startDate,
    this.status = CycleStatus.active,
    this.totalCost = 0,
    this.totalRevenue = 0,
    this.profitLoss = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FarmCycle.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawHistory = (data['stageHistory'] as List<dynamic>? ?? []);
    return FarmCycle(
      id: doc.id,
      farmId: data['farmId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? 'Cycle',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      varietyPlanted: data['varietyPlanted'] as String?,
      currentStage: CycleStageX.fromStorage(data['currentStage'] as String?),
      stageHistory: rawHistory
          .map((e) => StageHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      status: CycleStatusX.fromStorage(data['status'] as String?),
      totalCost: (data['totalCost'] as num? ?? 0).toDouble(),
      totalRevenue: (data['totalRevenue'] as num? ?? 0).toDouble(),
      profitLoss: (data['profitLoss'] as num? ?? 0).toDouble(),
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
      'year': year,
      if (varietyPlanted != null) 'varietyPlanted': varietyPlanted,
      'currentStage': currentStage.storageValue,
      'stageHistory': stageHistory.map((e) => e.toMap()).toList(),
      'startDate': Timestamp.fromDate(startDate),
      'status': status.storageValue,
      'totalCost': totalCost,
      'totalRevenue': totalRevenue,
      'profitLoss': profitLoss,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FarmCycle copyWith({
    String? name,
    int? year,
    String? varietyPlanted,
    CycleStage? currentStage,
    List<StageHistoryEntry>? stageHistory,
    CycleStatus? status,
    double? totalCost,
    double? totalRevenue,
    double? profitLoss,
    DateTime? updatedAt,
  }) {
    return FarmCycle(
      id: id,
      farmId: farmId,
      userId: userId,
      name: name ?? this.name,
      year: year ?? this.year,
      varietyPlanted: varietyPlanted ?? this.varietyPlanted,
      currentStage: currentStage ?? this.currentStage,
      stageHistory: stageHistory ?? this.stageHistory,
      startDate: startDate,
      status: status ?? this.status,
      totalCost: totalCost ?? this.totalCost,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      profitLoss: profitLoss ?? this.profitLoss,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
