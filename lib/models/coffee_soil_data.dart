import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a single coffee-soil analysis record stored in Firestore.
///
/// Fields are derived from every access site in [CoffeeSoilSummaryPage].
/// The [copyWith] method resolves the `undefined_method` diagnostic at line 955.
class CoffeeSoilData {
  // ── Identity ──────────────────────────────────────────────────────────────
  final String plotId;
  final String userId;
  final Timestamp timestamp;
  final bool isDeleted;

  // ── Agronomic metadata ────────────────────────────────────────────────────
  final String? soilType;

  /// Growth stage – displayed without a null check in the card, so it carries
  /// a non-nullable type with a sensible default in [fromMap].
  final String stage;

  final int plantDensity;
  final bool saveWithRecommendations;
  final bool notificationTriggered;

  // ── Nutrient readings (all nullable – a reading may be partial) ───────────
  final double? ph;
  final double? nitrogen;
  final double? phosphorus;
  final double? potassium;
  final double? magnesium;
  final double? calcium;
  final double? zinc;
  final double? boron;

  // ── Intervention ──────────────────────────────────────────────────────────
  final String? interventionMethod;
  final String? interventionQuantity;
  final String? interventionUnit;
  final Timestamp? interventionFollowUpDate;

  // ── AI outputs ────────────────────────────────────────────────────────────
  final Map<String, dynamic>? recommendations;

  // ─────────────────────────────────────────────────────────────────────────
  // Constructor
  // ─────────────────────────────────────────────────────────────────────────

  const CoffeeSoilData({
    required this.plotId,
    required this.userId,
    required this.timestamp,
    this.isDeleted = false,
    this.soilType,
    this.stage = 'Establishment/Seedling',
    this.plantDensity = 0,
    this.saveWithRecommendations = false,
    this.notificationTriggered = false,
    this.ph,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.magnesium,
    this.calcium,
    this.zinc,
    this.boron,
    this.interventionMethod,
    this.interventionQuantity,
    this.interventionUnit,
    this.interventionFollowUpDate,
    this.recommendations,
  });

  // ─────────────────────────────────────────────────────────────────────────
  // copyWith  ← this is the method the compiler was missing
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a new [CoffeeSoilData] with the given fields replaced.
  ///
  /// Nullable fields use the [Object?] sentinel pattern so callers can
  /// explicitly pass `null` to clear a value:
  ///
  /// ```dart
  /// entry.copyWith(interventionMethod: null)  // clears the field
  /// entry.copyWith()                          // returns an identical copy
  /// ```
  CoffeeSoilData copyWith({
    String? plotId,
    String? userId,
    Timestamp? timestamp,
    bool? isDeleted,
    Object? soilType = _sentinel,
    String? stage,
    int? plantDensity,
    bool? saveWithRecommendations,
    bool? notificationTriggered,
    Object? ph = _sentinel,
    Object? nitrogen = _sentinel,
    Object? phosphorus = _sentinel,
    Object? potassium = _sentinel,
    Object? magnesium = _sentinel,
    Object? calcium = _sentinel,
    Object? zinc = _sentinel,
    Object? boron = _sentinel,
    Object? interventionMethod = _sentinel,
    Object? interventionQuantity = _sentinel,
    Object? interventionUnit = _sentinel,
    Object? interventionFollowUpDate = _sentinel,
    Object? recommendations = _sentinel,
  }) {
    return CoffeeSoilData(
      plotId: plotId ?? this.plotId,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      soilType: soilType == _sentinel ? this.soilType : soilType as String?,
      stage: stage ?? this.stage,
      plantDensity: plantDensity ?? this.plantDensity,
      saveWithRecommendations:
          saveWithRecommendations ?? this.saveWithRecommendations,
      notificationTriggered:
          notificationTriggered ?? this.notificationTriggered,
      ph: ph == _sentinel ? this.ph : ph as double?,
      nitrogen: nitrogen == _sentinel ? this.nitrogen : nitrogen as double?,
      phosphorus:
          phosphorus == _sentinel ? this.phosphorus : phosphorus as double?,
      potassium: potassium == _sentinel ? this.potassium : potassium as double?,
      magnesium: magnesium == _sentinel ? this.magnesium : magnesium as double?,
      calcium: calcium == _sentinel ? this.calcium : calcium as double?,
      zinc: zinc == _sentinel ? this.zinc : zinc as double?,
      boron: boron == _sentinel ? this.boron : boron as double?,
      interventionMethod: interventionMethod == _sentinel
          ? this.interventionMethod
          : interventionMethod as String?,
      interventionQuantity: interventionQuantity == _sentinel
          ? this.interventionQuantity
          : interventionQuantity as String?,
      interventionUnit: interventionUnit == _sentinel
          ? this.interventionUnit
          : interventionUnit as String?,
      interventionFollowUpDate: interventionFollowUpDate == _sentinel
          ? this.interventionFollowUpDate
          : interventionFollowUpDate as Timestamp?,
      recommendations: recommendations == _sentinel
          ? this.recommendations
          : recommendations as Map<String, dynamic>?,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Firestore serialisation
  // ─────────────────────────────────────────────────────────────────────────

  factory CoffeeSoilData.fromMap(Map<String, dynamic> map) {
    return CoffeeSoilData(
      plotId: map['plotId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      timestamp: map['timestamp'] as Timestamp? ?? Timestamp.now(),
      isDeleted: map['isDeleted'] as bool? ?? false,
      soilType: map['soilType'] as String?,
      stage: map['stage'] as String? ?? 'Establishment/Seedling',
      plantDensity: (map['plantDensity'] as num?)?.toInt() ?? 0,
      saveWithRecommendations: map['saveWithRecommendations'] as bool? ?? false,
      notificationTriggered: map['notificationTriggered'] as bool? ?? false,
      ph: (map['ph'] as num?)?.toDouble(),
      nitrogen: (map['nitrogen'] as num?)?.toDouble(),
      phosphorus: (map['phosphorus'] as num?)?.toDouble(),
      potassium: (map['potassium'] as num?)?.toDouble(),
      magnesium: (map['magnesium'] as num?)?.toDouble(),
      calcium: (map['calcium'] as num?)?.toDouble(),
      zinc: (map['zinc'] as num?)?.toDouble(),
      boron: (map['boron'] as num?)?.toDouble(),
      interventionMethod: map['interventionMethod'] as String?,
      interventionQuantity: map['interventionQuantity'] as String?,
      interventionUnit: map['interventionUnit'] as String?,
      interventionFollowUpDate: map['interventionFollowUpDate'] as Timestamp?,
      recommendations: map['recommendations'] != null
          ? Map<String, dynamic>.from(map['recommendations'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plotId': plotId,
      'userId': userId,
      'timestamp': timestamp,
      'isDeleted': isDeleted,
      if (soilType != null) 'soilType': soilType,
      'stage': stage,
      'plantDensity': plantDensity,
      'saveWithRecommendations': saveWithRecommendations,
      'notificationTriggered': notificationTriggered,
      if (ph != null) 'ph': ph,
      if (nitrogen != null) 'nitrogen': nitrogen,
      if (phosphorus != null) 'phosphorus': phosphorus,
      if (potassium != null) 'potassium': potassium,
      if (magnesium != null) 'magnesium': magnesium,
      if (calcium != null) 'calcium': calcium,
      if (zinc != null) 'zinc': zinc,
      if (boron != null) 'boron': boron,
      if (interventionMethod != null) 'interventionMethod': interventionMethod,
      if (interventionQuantity != null)
        'interventionQuantity': interventionQuantity,
      if (interventionUnit != null) 'interventionUnit': interventionUnit,
      if (interventionFollowUpDate != null)
        'interventionFollowUpDate': interventionFollowUpDate,
      if (recommendations != null) 'recommendations': recommendations,
    };
  }

  @override
  String toString() => 'CoffeeSoilData(plotId: $plotId, userId: $userId, '
      'timestamp: $timestamp, stage: $stage)';
}

/// Private sentinel used by [CoffeeSoilData.copyWith] to distinguish between
/// "caller did not pass the argument" and "caller explicitly passed null".
const Object _sentinel = Object();
