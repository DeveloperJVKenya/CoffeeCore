import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:coffeecore/models/farmer_deduction.dart';
import 'package:coffeecore/models/farmer_payout.dart';
import 'package:coffeecore/models/farmer_produce.dart';
import 'package:coffeecore/models/farmer_settlement.dart';

/// Firestore access for the farmer settlement ledger: a farmer's coffee
/// submissions (with the price snapshotted at recording time — see
/// FarmerProduce), cooperative-side deductions (input supplies, transport,
/// processing costs), and payout records, combined into a live
/// [FarmerSettlement]. Every total is computed on read from the three
/// source collections, never stored — the same fix applied to
/// ProduceScreen's `latestTotalAmount` staleness bug applies here from the
/// start: a denormalized running balance would drift the moment any one of
/// the three source streams changed without the others re-syncing it.
class FarmerSettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  CollectionReference<Map<String, dynamic>> _submissionsRef(
          String coopId, String userId) =>
      _firestore
          .collection('${coopId}_FarmerProduce')
          .doc(userId)
          .collection('submissions');

  CollectionReference<Map<String, dynamic>> _deductionsRef(
          String coopId, String userId) =>
      _firestore
          .collection('${coopId}_FarmerDeductions')
          .doc(userId)
          .collection('entries');

  CollectionReference<Map<String, dynamic>> _payoutsRef(
          String coopId, String userId) =>
      _firestore
          .collection('${coopId}_FarmerPayouts')
          .doc(userId)
          .collection('entries');

  Stream<List<FarmerProduce>> submissionsForFarmer(
      String coopId, String userId) {
    return _submissionsRef(coopId, userId).snapshots().map(
        (snap) => snap.docs.map((d) => FarmerProduce.fromDocument(d)).toList());
  }

  Stream<List<FarmerDeduction>> deductionsForFarmer(
      String coopId, String userId) {
    return _deductionsRef(coopId, userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FarmerDeduction.fromDocument(d)).toList());
  }

  Stream<List<FarmerPayout>> payoutsForFarmer(String coopId, String userId) {
    return _payoutsRef(coopId, userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FarmerPayout.fromDocument(d)).toList());
  }

  /// [userData] supplies the display name/contact fallback (from the
  /// `{coop}_users` doc) for a farmer with no submissions yet.
  Stream<FarmerSettlement> settlementForFarmer(
    String coopId,
    String userId,
    Map<String, String?> userData,
  ) {
    return CombineLatestStream.combine3(
      submissionsForFarmer(coopId, userId),
      deductionsForFarmer(coopId, userId),
      payoutsForFarmer(coopId, userId),
      (List<FarmerProduce> submissions, List<FarmerDeduction> deductions,
          List<FarmerPayout> payouts) {
        final grossEarned =
            submissions.fold<double>(0.0, (t, s) => t + s.grossValue);
        final totalDeductions =
            deductions.fold<double>(0.0, (t, d) => t + d.amount);
        final totalPaidOut = payouts.fold<double>(0.0, (t, p) => t + p.amount);
        final unpriced = submissions.where((s) => s.pricePerKg <= 0).length;

        final farmerName = submissions.isNotEmpty
            ? submissions.first.farmerName
            : (userData['fullName'] ?? '-');
        final contact = submissions.isNotEmpty
            ? submissions.first.contact
            : (userData['phoneNumber'] ?? '-');

        return FarmerSettlement(
          userId: userId,
          farmerName: farmerName,
          contact: contact,
          grossEarned: grossEarned,
          totalDeductions: totalDeductions,
          totalPaidOut: totalPaidOut,
          unpricedSubmissionCount: unpriced,
        );
      },
    );
  }

  /// Re-subscribes to a fresh combine whenever the cooperative's user list
  /// changes, mirroring `_produceDataStreamForCoop` in produce_screen.dart
  /// so membership changes and per-farmer data changes both propagate live.
  Stream<List<FarmerSettlement>> settlementForCoop(String coopId) {
    return _firestore
        .collection('${coopId}_users')
        .snapshots()
        .switchMap((userSnapshot) {
      if (userSnapshot.docs.isEmpty) {
        return Stream<List<FarmerSettlement>>.value(const []);
      }
      return CombineLatestStream.list(
        userSnapshot.docs.map((doc) {
          final data = doc.data();
          final userData = {
            'fullName': data['fullName']?.toString(),
            'phoneNumber': data['phoneNumber']?.toString(),
          };
          return settlementForFarmer(coopId, doc.id, userData);
        }),
      );
    });
  }

  Future<void> addDeduction(String coopId, FarmerDeduction deduction) async {
    try {
      await _deductionsRef(coopId, deduction.userId).add(deduction.toMap());
    } catch (e, st) {
      _log.e('FarmerSettlementService.addDeduction: Error – $e',
          stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteDeduction(
      String coopId, String userId, String deductionId) async {
    try {
      await _deductionsRef(coopId, userId).doc(deductionId).delete();
    } catch (e, st) {
      _log.e('FarmerSettlementService.deleteDeduction: Error – $e',
          stackTrace: st);
      rethrow;
    }
  }

  Future<void> addPayout(String coopId, FarmerPayout payout) async {
    try {
      await _payoutsRef(coopId, payout.userId).add(payout.toMap());
    } catch (e, st) {
      _log.e('FarmerSettlementService.addPayout: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> deletePayout(
      String coopId, String userId, String payoutId) async {
    try {
      await _payoutsRef(coopId, userId).doc(payoutId).delete();
    } catch (e, st) {
      _log.e('FarmerSettlementService.deletePayout: Error – $e',
          stackTrace: st);
      rethrow;
    }
  }
}
