import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/utils/errors.dart';
import '../core/utils/firestore_helpers.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

class StockService {
  StockService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');
  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stock_movements');

  /// Adds stock with `FieldValue.increment`, so it also works offline
  /// (queued and synced later). Returns false if the write is queued offline.
  ///
  /// `expiryDate` on the product is the *nearest* expiry date, so a new batch
  /// only replaces it when it expires sooner, or when the old batch is gone.
  Future<bool> stockIn({
    required Product product,
    required int quantity,
    required String staffId,
    DateTime? expiryDate,
    String source = MovementSource.barcode,
  }) async {
    if (quantity <= 0) {
      throw const AppException('Quantity must be more than 0.');
    }
    final oldBatchGone = product.stock <= 0;
    final replaceExpiry =
        expiryDate != null &&
        (oldBatchGone ||
            product.expiryDate == null ||
            expiryDate.isBefore(product.expiryDate!));

    final batch = _db.batch()
      ..update(_products.doc(product.barcode), {
        'stock': FieldValue.increment(quantity),
        if (replaceExpiry) 'expiryDate': Timestamp.fromDate(expiryDate),
        // The Save Food deal was for the old batch; fresh stock is full price.
        if (oldBatchGone && product.isOnSaveFood) 'saveFoodPriceSen': null,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(
        _movements.doc(),
        StockMovement.newMap(
          productId: product.barcode,
          productName: product.name,
          type: MovementType.stockIn,
          quantity: quantity,
          source: source,
          byUserId: staffId,
          expiryDate: expiryDate,
        ),
      );
    return waitForSync(batch.commit());
  }

  /// Reduces stock inside a transaction so two staff can never
  /// remove the last item at the same time. Throws if not enough stock.
  /// Needs a connection (Firestore transactions do not run offline).
  Future<void> stockOut({
    required String productId,
    required int quantity,
    required String staffId,
    required String type, // 'expired' | 'damaged' | 'adjustment'
    String source = MovementSource.manual,
  }) async {
    if (quantity <= 0) {
      throw const AppException('Quantity must be more than 0.');
    }
    final productRef = _products.doc(productId);
    final movementRef = _movements.doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(productRef);
      if (!snap.exists) throw const AppException('Product not found.');
      final data = snap.data()!;
      final current = readInt(data['stock']);
      if (current < quantity) {
        throw AppException('Not enough stock (only {left} left).', {
          'left': current,
        });
      }
      tx.update(productRef, {
        'stock': current - quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        movementRef,
        StockMovement.newMap(
          productId: productId,
          productName: data['name'] as String? ?? productId,
          type: type,
          quantity: -quantity,
          source: source,
          byUserId: staffId,
          stockAfter: current - quantity,
        ),
      );
    });
  }

  Stream<List<StockMovement>> watchRecentMovements({int limit = 30}) =>
      _movements
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(StockMovement.fromDoc).toList());

  Stream<List<StockMovement>> watchMovementsSince(DateTime since) => _movements
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .snapshots()
      .map((s) => s.docs.map(StockMovement.fromDoc).toList());
}
