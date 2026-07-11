import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Farm%20Management/models/farm_cycle_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cycle_stage.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cost_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/revenue_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/loan_model.dart';

/// Reads legacy `FarmData/{uid}/Cycles/{cycleName}` documents (written by
/// the old `data_manager.dart`) and converts each into the new typed
/// `FarmCycles`/`CostEntries`/`RevenueEntries`/`Loans` schema, attached to a
/// farmId chosen by the user. Old data is left in place (not deleted) as a
/// safety net, and `FarmData/{uid}.migrated = true` is set so the one-time
/// prompt does not repeat.
class LegacyMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  String? get _uid => _auth.currentUser?.uid;

  /// Returns true if legacy data exists and hasn't already been migrated.
  Future<bool> hasUnmigratedLegacyData() async {
    if (_uid == null) return false;
    try {
      final userDoc = await _firestore.collection('FarmData').doc(_uid).get();
      if (!userDoc.exists) return false;
      final data = userDoc.data();
      if (data?['migrated'] == true) return false;
      final cycles = await _firestore
          .collection('FarmData')
          .doc(_uid)
          .collection('Cycles')
          .limit(1)
          .get();
      return cycles.docs.isNotEmpty;
    } catch (e, st) {
      _log.e('LegacyMigrationService.hasUnmigratedLegacyData: Error – $e',
          stackTrace: st);
      return false;
    }
  }

  Future<List<String>> legacyCycleNames() async {
    if (_uid == null) return [];
    try {
      final snap = await _firestore
          .collection('FarmData')
          .doc(_uid)
          .collection('Cycles')
          .get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e, st) {
      _log.e('LegacyMigrationService.legacyCycleNames: Error – $e',
          stackTrace: st);
      return [];
    }
  }

  /// Converts every legacy cycle document into the new schema, all attached
  /// to [targetFarmId]. Returns the number of cycles migrated.
  Future<int> migrateAllCycles(String targetFarmId) async {
    if (_uid == null) {
      throw StateError(
          'LegacyMigrationService.migrateAllCycles: No authenticated user');
    }
    int migrated = 0;
    try {
      final cyclesSnap = await _firestore
          .collection('FarmData')
          .doc(_uid)
          .collection('Cycles')
          .get();

      for (final cycleDoc in cyclesSnap.docs) {
        final data = cycleDoc.data();
        final now = DateTime.now();
        final year = int.tryParse((data['year'] ?? '').toString()) ?? now.year;

        final labour =
            List<Map<String, dynamic>>.from(data['labourActivities'] ?? []);
        final mechanical =
            List<Map<String, dynamic>>.from(data['mechanicalCosts'] ?? []);
        final input = List<Map<String, dynamic>>.from(data['inputCosts'] ?? []);
        final misc =
            List<Map<String, dynamic>>.from(data['miscellaneousCosts'] ?? []);
        final revenues =
            List<Map<String, dynamic>>.from(data['revenues'] ?? []);
        final loanData = Map<String, dynamic>.from(data['loanData'] ?? {});

        final totalCost = (data['totalProductionCost'] as num? ?? 0).toDouble();
        final totalRevenue = revenues.fold<double>(
            0.0, (t, r) => t + (double.tryParse(r['amount'].toString()) ?? 0));

        final newCycle = FarmCycle(
          farmId: targetFarmId,
          userId: _uid!,
          name: cycleDoc.id,
          year: year,
          currentStage: CycleStage.postHarvest,
          startDate: now,
          status: CycleStatus.archived,
          totalCost: totalCost,
          totalRevenue: totalRevenue,
          profitLoss: totalRevenue - totalCost,
          createdAt: now,
          updatedAt: now,
        );
        final cycleRef = await _firestore
            .collection('FarmCycles')
            .add(newCycle.toFirestore());
        final newCycleId = cycleRef.id;

        final batch = _firestore.batch();
        for (final item in [...labour, ...mechanical, ...input, ...misc]) {
          final costRef = _firestore.collection('CostEntries').doc();
          final description = (item['activity'] ??
                  item['equipment'] ??
                  item['input'] ??
                  item['description'] ??
                  '')
              .toString();
          final category = labour.contains(item)
              ? CostCategory.labour
              : mechanical.contains(item)
                  ? CostCategory.mechanical
                  : input.contains(item)
                      ? CostCategory.input
                      : CostCategory.miscellaneous;
          final entry = CostEntry(
            farmId: targetFarmId,
            cycleId: newCycleId,
            userId: _uid!,
            category: category,
            description: description,
            amount: double.tryParse(item['cost'].toString()) ?? 0,
            date: DateTime.tryParse(item['date']?.toString() ?? '') ?? now,
            createdAt: now,
          );
          batch.set(costRef, entry.toFirestore());
        }
        for (final item in revenues) {
          final revRef = _firestore.collection('RevenueEntries').doc();
          final amount = double.tryParse(item['amount'].toString()) ?? 0;
          final entry = RevenueEntry(
            farmId: targetFarmId,
            cycleId: newCycleId,
            userId: _uid!,
            variety: (item['coffeeVariety'] ?? 'Unknown').toString(),
            kg: double.tryParse(item['yield']?.toString() ?? '') ?? 0,
            pricePerKg: 0,
            amount: amount,
            date: DateTime.tryParse(item['date']?.toString() ?? '') ?? now,
            createdAt: now,
          );
          batch.set(revRef, entry.toFirestore());
        }
        final loanAmount = (loanData['loanAmount'] as num? ?? 0).toDouble();
        if (loanAmount > 0) {
          final loanRef = _firestore.collection('Loans').doc();
          final loan = LoanRecord(
            farmId: targetFarmId,
            cycleId: newCycleId,
            userId: _uid!,
            source: (loanData['loanSource'] ?? 'Legacy loan').toString(),
            principal: loanAmount,
            interestRate: (loanData['interestRate'] as num? ?? 0).toDouble(),
            startDate: now,
            status: LoanStatus.active,
            createdAt: now,
            updatedAt: now,
          );
          batch.set(loanRef, loan.toFirestore());
        }
        await batch.commit();
        migrated++;
      }

      await _firestore.collection('FarmData').doc(_uid).set(
        {'migrated': true, 'migratedAt': Timestamp.fromDate(DateTime.now())},
        SetOptions(merge: true),
      );
      _log.i(
          'LegacyMigrationService.migrateAllCycles: Migrated $migrated cycle(s) to farm $targetFarmId');
      return migrated;
    } catch (e, st) {
      _log.e('LegacyMigrationService.migrateAllCycles: Error – $e',
          stackTrace: st);
      rethrow;
    }
  }

  Future<void> dismissMigrationPrompt() async {
    if (_uid == null) return;
    try {
      await _firestore.collection('FarmData').doc(_uid).set(
        {'migrated': true, 'migratedAt': Timestamp.fromDate(DateTime.now())},
        SetOptions(merge: true),
      );
    } catch (e, st) {
      _log.e('LegacyMigrationService.dismissMigrationPrompt: Error – $e',
          stackTrace: st);
    }
  }
}
