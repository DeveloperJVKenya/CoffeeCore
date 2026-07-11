import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanStatus { active, paidOff, defaulted }

extension LoanStatusX on LoanStatus {
  String get label {
    switch (this) {
      case LoanStatus.active:
        return 'Active';
      case LoanStatus.paidOff:
        return 'Paid Off';
      case LoanStatus.defaulted:
        return 'Defaulted';
    }
  }

  String get storageValue => name;

  static LoanStatus fromStorage(String? value) {
    return LoanStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => LoanStatus.active,
    );
  }
}

/// A single repayment against a loan.
class RepaymentEntry {
  final double amount;
  final DateTime date;
  final double remainingBalanceAfter;

  const RepaymentEntry({
    required this.amount,
    required this.date,
    required this.remainingBalanceAfter,
  });

  factory RepaymentEntry.fromMap(Map<String, dynamic> map) {
    return RepaymentEntry(
      amount: (map['amount'] as num? ?? 0).toDouble(),
      date: map['date'] != null
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      remainingBalanceAfter:
          (map['remainingBalanceAfter'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'remainingBalanceAfter': remainingBalanceAfter,
      };
}

/// A loan taken against a farm cycle. Interest/balance math is ported
/// verbatim from the old `data_manager.dart` (`updateLoanCalculations`):
/// interest = principal * interestRate / 100; totalRepayment = principal +
/// interest; remainingBalance = totalRepayment - sum(repayments).
class LoanRecord {
  final String? id;
  final String farmId;
  final String cycleId;
  final String userId;
  final String source;
  final double principal;
  final double interestRate; // percent, e.g. 12 for 12%
  final DateTime startDate;
  final LoanStatus status;
  final List<RepaymentEntry> repayments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LoanRecord({
    this.id,
    required this.farmId,
    required this.cycleId,
    required this.userId,
    required this.source,
    required this.principal,
    required this.interestRate,
    required this.startDate,
    this.status = LoanStatus.active,
    this.repayments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  double get interest => principal * interestRate / 100;

  double get totalRepayment => principal + interest;

  double get amountPaid =>
      repayments.fold<double>(0.0, (total, r) => total + r.amount);

  double get remainingBalance => totalRepayment - amountPaid;

  bool get isPaidOff => remainingBalance <= 0.005;

  factory LoanRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawRepayments = (data['repayments'] as List<dynamic>? ?? []);
    return LoanRecord(
      id: doc.id,
      farmId: data['farmId'] as String? ?? '',
      cycleId: data['cycleId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      source: data['source'] as String? ?? '',
      principal: (data['principal'] as num? ?? 0).toDouble(),
      interestRate: (data['interestRate'] as num? ?? 0).toDouble(),
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      status: LoanStatusX.fromStorage(data['status'] as String?),
      repayments: rawRepayments
          .map((e) => RepaymentEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
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
      'cycleId': cycleId,
      'userId': userId,
      'source': source,
      'principal': principal,
      'interestRate': interestRate,
      'startDate': Timestamp.fromDate(startDate),
      'status': status.storageValue,
      'repayments': repayments.map((r) => r.toMap()).toList(),
      'balance': remainingBalance,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LoanRecord copyWith({
    LoanStatus? status,
    List<RepaymentEntry>? repayments,
    DateTime? updatedAt,
  }) {
    return LoanRecord(
      id: id,
      farmId: farmId,
      cycleId: cycleId,
      userId: userId,
      source: source,
      principal: principal,
      interestRate: interestRate,
      startDate: startDate,
      status: status ?? this.status,
      repayments: repayments ?? this.repayments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
