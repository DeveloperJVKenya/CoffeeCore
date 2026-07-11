import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cost_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/revenue_model.dart';

/// Summary of a cycle's profit/loss position, computed the same way as the
/// old `data_manager.dart` (`calculateTotalProductionCost` /
/// `_calculateProfitLoss`): totalCost = sum(all cost entries), totalRevenue
/// = sum(all revenue entries), profitLoss = totalRevenue - totalCost.
class ProfitLossSummary {
  final double totalCost;
  final double totalRevenue;
  final double profitLoss;
  final Map<CostCategory, double> costByCategory;

  const ProfitLossSummary({
    required this.totalCost,
    required this.totalRevenue,
    required this.profitLoss,
    required this.costByCategory,
  });

  static const ProfitLossSummary empty = ProfitLossSummary(
    totalCost: 0,
    totalRevenue: 0,
    profitLoss: 0,
    costByCategory: {},
  );
}

/// Firestore CRUD for `CostEntries`/`RevenueEntries`, plus P&L aggregation
/// ported from `data_manager.dart`.
class FinanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _costsCollection = 'CostEntries';
  static const String _revenueCollection = 'RevenueEntries';

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<CostEntry>> costsForCycle(String farmId, String cycleId) {
    if (_uid == null) return Stream.value([]);
    return _firestore
        .collection(_costsCollection)
        .where('farmId', isEqualTo: farmId)
        .where('cycleId', isEqualTo: cycleId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
            (snap) => snap.docs.map((d) => CostEntry.fromFirestore(d)).toList())
        .handleError((Object e, StackTrace st) {
      _log.e('FinanceService.costsForCycle: Stream error – $e', stackTrace: st);
      return <CostEntry>[];
    });
  }

  Stream<List<RevenueEntry>> revenueForCycle(String farmId, String cycleId) {
    if (_uid == null) return Stream.value([]);
    return _firestore
        .collection(_revenueCollection)
        .where('farmId', isEqualTo: farmId)
        .where('cycleId', isEqualTo: cycleId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => RevenueEntry.fromFirestore(d)).toList())
        .handleError((Object e, StackTrace st) {
      _log.e('FinanceService.revenueForCycle: Stream error – $e',
          stackTrace: st);
      return <RevenueEntry>[];
    });
  }

  Future<String> addCost(CostEntry entry) async {
    try {
      final ref = await _firestore
          .collection(_costsCollection)
          .add(entry.toFirestore());
      return ref.id;
    } catch (e, st) {
      _log.e('FinanceService.addCost: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteCost(String costId) async {
    try {
      await _firestore.collection(_costsCollection).doc(costId).delete();
    } catch (e, st) {
      _log.e('FinanceService.deleteCost: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<String> addRevenue(RevenueEntry entry) async {
    try {
      final ref = await _firestore
          .collection(_revenueCollection)
          .add(entry.toFirestore());
      return ref.id;
    } catch (e, st) {
      _log.e('FinanceService.addRevenue: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteRevenue(String revenueId) async {
    try {
      await _firestore.collection(_revenueCollection).doc(revenueId).delete();
    } catch (e, st) {
      _log.e('FinanceService.deleteRevenue: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  /// Ported from `data_manager.dart`'s `calculateTotalProductionCost` +
  /// `_calculateProfitLoss`: sum all cost entries (grouped by category for
  /// the pie chart), sum all revenue entries, profitLoss = revenue - cost.
  ProfitLossSummary computeProfitLoss(
      List<CostEntry> costs, List<RevenueEntry> revenues) {
    final Map<CostCategory, double> byCategory = {};
    double totalCost = 0;
    for (final c in costs) {
      totalCost += c.amount;
      byCategory[c.category] = (byCategory[c.category] ?? 0) + c.amount;
    }
    final double totalRevenue =
        revenues.fold<double>(0.0, (total, r) => total + r.amount);
    return ProfitLossSummary(
      totalCost: totalCost,
      totalRevenue: totalRevenue,
      profitLoss: totalRevenue - totalCost,
      costByCategory: byCategory,
    );
  }
}
