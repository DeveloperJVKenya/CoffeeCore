import 'dart:async';
import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/cost_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/revenue_model.dart';
import 'package:coffeecore/screens/Farm%20Management/models/loan_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/finance_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/loan_service.dart';
import 'package:coffeecore/screens/Farm%20Management/services/farm_cycle_service.dart';

/// Costs/revenue/loans for the selected farm + cycle, with derived P&L.
/// Depends on the active cycle id via `updateCycle`.
class FarmFinanceProvider with ChangeNotifier {
  final String farmId;
  final FinanceService _financeService;
  final LoanService _loanService;
  final FarmCycleService _cycleService;

  FarmFinanceProvider({
    required this.farmId,
    FinanceService? financeService,
    LoanService? loanService,
    FarmCycleService? cycleService,
  })  : _financeService = financeService ?? FinanceService(),
        _loanService = loanService ?? LoanService(),
        _cycleService = cycleService ?? FarmCycleService();

  String? _cycleId;
  List<CostEntry> _costs = [];
  List<RevenueEntry> _revenues = [];
  List<LoanRecord> _loans = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<CostEntry>>? _costSub;
  StreamSubscription<List<RevenueEntry>>? _revenueSub;
  StreamSubscription<List<LoanRecord>>? _loanSub;

  List<CostEntry> get costs => _costs;
  List<RevenueEntry> get revenues => _revenues;
  List<LoanRecord> get loans => _loans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ProfitLossSummary get profitLoss =>
      _financeService.computeProfitLoss(_costs, _revenues);

  void updateCycle(String? cycleId) {
    if (_cycleId == cycleId) return;
    _cycleId = cycleId;
    _costSub?.cancel();
    _revenueSub?.cancel();
    _loanSub?.cancel();
    if (cycleId == null) {
      _costs = [];
      _revenues = [];
      _loans = [];
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    _costSub = _financeService.costsForCycle(farmId, cycleId).listen((v) {
      _costs = v;
      _isLoading = false;
      _syncRollups();
      notifyListeners();
    }, onError: (Object e) {
      _error = e.toString();
      notifyListeners();
    });
    _revenueSub = _financeService.revenueForCycle(farmId, cycleId).listen((v) {
      _revenues = v;
      _syncRollups();
      notifyListeners();
    }, onError: (Object e) {
      _error = e.toString();
      notifyListeners();
    });
    _loanSub = _loanService.loansForCycle(farmId, cycleId).listen((v) {
      _loans = v;
      notifyListeners();
    }, onError: (Object e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  void _syncRollups() {
    final id = _cycleId;
    if (id == null) return;
    final summary = profitLoss;
    _cycleService.updateRollups(
      cycleId: id,
      totalCost: summary.totalCost,
      totalRevenue: summary.totalRevenue,
    );
  }

  Future<void> addCost(CostEntry entry) => _financeService.addCost(entry);

  Future<void> deleteCost(String costId) => _financeService.deleteCost(costId);

  Future<void> addRevenue(RevenueEntry entry) =>
      _financeService.addRevenue(entry);

  Future<void> deleteRevenue(String revenueId) =>
      _financeService.deleteRevenue(revenueId);

  Future<void> addLoan(LoanRecord loan) => _loanService.addLoan(loan);

  Future<void> recordRepayment(LoanRecord loan, double amount) =>
      _loanService.recordRepayment(loan, amount);

  Future<void> deleteLoan(String loanId) => _loanService.deleteLoan(loanId);

  @override
  void dispose() {
    _costSub?.cancel();
    _revenueSub?.cancel();
    _loanSub?.cancel();
    super.dispose();
  }
}
