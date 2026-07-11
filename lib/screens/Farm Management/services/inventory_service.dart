import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Farm%20Management/models/inventory_model.dart';

/// Firestore CRUD for `InventoryItems`/`InventoryTransactions`.
class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _log = Logger(printer: PrettyPrinter());

  static const String _itemsCollection = 'InventoryItems';
  static const String _txCollection = 'InventoryTransactions';

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<InventoryItem>> itemsForFarm(String farmId) {
    if (_uid == null) return Stream.value([]);
    return _firestore
        .collection(_itemsCollection)
        .where('farmId', isEqualTo: farmId)
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => InventoryItem.fromFirestore(d)).toList())
        .handleError((Object e, StackTrace st) {
      _log.e('InventoryService.itemsForFarm: Stream error – $e',
          stackTrace: st);
      return <InventoryItem>[];
    });
  }

  Stream<List<InventoryTransaction>> transactionsForItem(String itemId) {
    if (_uid == null) return Stream.value([]);
    return _firestore
        .collection(_txCollection)
        .where('itemId', isEqualTo: itemId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => InventoryTransaction.fromFirestore(d))
            .toList())
        .handleError((Object e, StackTrace st) {
      _log.e('InventoryService.transactionsForItem: Stream error – $e',
          stackTrace: st);
      return <InventoryTransaction>[];
    });
  }

  Future<String> addItem(InventoryItem item) async {
    try {
      final ref =
          await _firestore.collection(_itemsCollection).add(item.toFirestore());
      return ref.id;
    } catch (e, st) {
      _log.e('InventoryService.addItem: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _firestore.collection(_itemsCollection).doc(itemId).delete();
    } catch (e, st) {
      _log.e('InventoryService.deleteItem: Error – $e', stackTrace: st);
      rethrow;
    }
  }

  /// Records a stock movement and updates the parent item's
  /// `quantityOnHand` in a single batch write.
  Future<void> recordTransaction({
    required InventoryItem item,
    required InventoryTransactionType type,
    required double quantity,
    String? relatedActivityId,
  }) async {
    if (item.id == null || _uid == null) {
      throw StateError(
          'InventoryService.recordTransaction: missing item.id or auth');
    }
    try {
      final now = DateTime.now();
      final tx = InventoryTransaction(
        farmId: item.farmId,
        itemId: item.id!,
        userId: _uid!,
        type: type,
        quantity: quantity,
        date: now,
        relatedActivityId: relatedActivityId,
        createdAt: now,
      );
      final newQuantity = type == InventoryTransactionType.stockIn
          ? item.quantityOnHand + quantity
          : item.quantityOnHand - quantity;

      final batch = _firestore.batch();
      final txRef = _firestore.collection(_txCollection).doc();
      batch.set(txRef, tx.toFirestore());
      final itemRef = _firestore.collection(_itemsCollection).doc(item.id);
      batch.update(itemRef, {
        'quantityOnHand': newQuantity,
        'updatedAt': Timestamp.fromDate(now),
      });
      await batch.commit();
      _log.i(
          'InventoryService.recordTransaction: ${type.label} $quantity ${item.unit} for ${item.name}');
    } catch (e, st) {
      _log.e('InventoryService.recordTransaction: Error – $e', stackTrace: st);
      rethrow;
    }
  }
}
