import 'dart:async';
import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/models/inventory_model.dart';
import 'package:coffeecore/screens/Farm%20Management/services/inventory_service.dart';

/// Inventory items + transactions for the selected farm.
class InventoryProvider with ChangeNotifier {
  final String farmId;
  final InventoryService _service;

  InventoryProvider({required this.farmId, InventoryService? service})
      : _service = service ?? InventoryService() {
    _subscribe();
  }

  List<InventoryItem> _items = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<InventoryItem>>? _sub;

  List<InventoryItem> get items => _items;
  List<InventoryItem> get lowStockItems =>
      _items.where((i) => i.isLowStock).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _subscribe() {
    _sub = _service.itemsForFarm(farmId).listen((items) {
      _items = items;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<String> addItem(InventoryItem item) => _service.addItem(item);

  Future<void> deleteItem(String itemId) => _service.deleteItem(itemId);

  Future<void> recordTransaction({
    required InventoryItem item,
    required InventoryTransactionType type,
    required double quantity,
    String? relatedActivityId,
  }) {
    return _service.recordTransaction(
      item: item,
      type: type,
      quantity: quantity,
      relatedActivityId: relatedActivityId,
    );
  }

  Stream<List<InventoryTransaction>> transactionsForItem(String itemId) =>
      _service.transactionsForItem(itemId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
