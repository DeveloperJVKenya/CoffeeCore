import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Farm%20Management/models/loan_model.dart';

/// Firestore CRUD for the `Loans` collection. Interest/balance calculations
/// live on [LoanRecord] itself (ported from `data_manager.dart`'s
/// `updateLoanCalculations`), this service persists repayments and status.
class LoanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _collection = 'Loans';

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<LoanRecord>> loansForCycle(String farmId, String cycleId) {
    if (_uid == null) return Stream.value([]);
    return _firestore
        .collection(_collection)
        .where('farmId', isEqualTo: farmId)
        .where('cycleId', isEqualTo: cycleId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => LoanRecord.fromFirestore(d)).toList())
        .handleError((Object e, StackTrace st) {
      _log.e('LoanService.loansForCycle: Stream error – $e', stackTrace: st);
      return <LoanRecord>[];
    });
  }

  Future<String> addLoan(LoanRecord loan) async {
    try {
      final ref =
          await _firestore.collection(_collection).add(loan.toFirestore());
      _log.i('LoanService.addLoan: Added loan ${ref.id}');
      return ref.id;
    } catch (e, st) {
      _log.e('LoanService.addLoan: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  /// Records a repayment against [loan], mirroring
  /// `data_manager.dart`'s `recordPayment`: appends to the repayments list
  /// and recomputes the remaining balance, marking the loan paid off once
  /// the balance reaches zero.
  Future<void> recordRepayment(LoanRecord loan, double amount) async {
    if (loan.id == null) {
      throw ArgumentError('LoanService.recordRepayment: loan.id is null');
    }
    try {
      final newRepayment = RepaymentEntry(
        amount: amount,
        date: DateTime.now(),
        remainingBalanceAfter: loan.remainingBalance - amount,
      );
      final updatedRepayments = [newRepayment, ...loan.repayments];
      final newBalance = loan.totalRepayment -
          updatedRepayments.fold<double>(0.0, (t, r) => t + r.amount);

      await _firestore.collection(_collection).doc(loan.id).update({
        'repayments': updatedRepayments.map((r) => r.toMap()).toList(),
        'balance': newBalance,
        'status': newBalance <= 0.005
            ? LoanStatus.paidOff.storageValue
            : loan.status.storageValue,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _log.i(
          'LoanService.recordRepayment: Loan ${loan.id} repaid $amount, balance now $newBalance');
    } catch (e, st) {
      _log.e('LoanService.recordRepayment: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteLoan(String loanId) async {
    try {
      await _firestore.collection(_collection).doc(loanId).delete();
    } catch (e, st) {
      _log.e('LoanService.deleteLoan: Error – $e', stackTrace: st);
      rethrow;
    }
  }
}
