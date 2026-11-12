// cloud_firestore has its own `Order` (index definitions); ours is the model.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../core/constants.dart';
import '../core/utils/codes.dart';
import '../core/utils/errors.dart';
import '../core/utils/firestore_helpers.dart';
import '../core/utils/points.dart';
import '../l10n/strings.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

/// Result of placing a pre-order: [synced] is false when the order was
/// saved offline and will be sent when the connection returns.
typedef PlaceOrderResult = ({String orderId, bool synced});

class OrderService {
  OrderService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');
  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stock_movements');

  // ---------------------------------------------------------------- reading

  Stream<Order?> watchOrder(String id) => _orders
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Order.fromDoc(d) : null);

  /// Student "My Orders". Must filter by userId or the rules reject it.
  /// Sorted on the phone, so no composite index is needed.
  Stream<List<Order>> watchMyOrders(String uid) => _orders
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(Order.fromDoc).toList()
              ..sort((a, b) => b.sortTime.compareTo(a.sortTime)),
      );

  /// Staff queue: pre-orders waiting to be packed or collected, oldest first.
  Stream<List<Order>> watchQueue() => _orders
      .where('status', whereIn: [OrderStatus.pending, OrderStatus.ready])
      .snapshots()
      .map(
        (s) =>
            s.docs.map(Order.fromDoc).toList()
              ..sort((a, b) => a.sortTime.compareTo(b.sortTime)),
      );

  /// Orders created since [since], for the dashboard and reports.
  Stream<List<Order>> watchOrdersSince(DateTime since) => _orders
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .snapshots()
      .map((s) => s.docs.map(Order.fromDoc).toList());

  Future<Order?> findByPickupCode(String code) async {
    final snap = await _orders
        .where('pickupCode', isEqualTo: code.trim().toUpperCase())
        .limit(5)
        .get();
    final orders = snap.docs.map(Order.fromDoc).toList();
    if (orders.isEmpty) return null;
    // A code is unique in practice; prefer the one that is still active.
    return orders.firstWhere(
      (o) => o.isReady || o.isPending,
      orElse: () => orders.first,
    );
  }

  // ------------------------------------------------------------- pre-orders

  /// Student places a pre-order ("Pay at counter"). Stock is NOT deducted
  /// yet; that happens when staff tap "Accept & pack".
  Future<PlaceOrderResult> placePreorder({
    required AppUser user,
    required List<OrderItem> items,
    required bool noPlasticBag,
  }) async {
    if (items.isEmpty) throw const AppException('Your cart is empty.');
    final ref = _orders.doc();
    final write = ref.set({
      'type': OrderType.preorder,
      'userId': user.uid,
      'customerName': user.name,
      'items': [for (final i in items) i.toMap()],
      'totalSen': totalOf(items),
      'status': OrderStatus.pending,
      'noPlasticBag': noPlasticBag,
      'pickupCode': generatePickupCode(),
      'pointsEarned': calculateGreenPoints(
        noPlasticBag: noPlasticBag,
        saveFoodItemCount: saveFoodCountOf(items),
      ),
      'handledBy': null,
      'createdAt': FieldValue.serverTimestamp(),
      'readyAt': null,
      'collectedAt': null,
    });
    final synced = await waitForSync(
      write,
      timeout: const Duration(seconds: 8),
    );
    return (orderId: ref.id, synced: synced);
  }

  /// Staff: deducts stock for every item inside one transaction and marks
  /// the order READY. Prices and points are recalculated from the current
  /// product data, because the app total from the student is never trusted.
  Future<void> acceptAndPack(String orderId, {required String staffId}) async {
    final orderRef = _orders.doc(orderId);
    await _db.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) throw const AppException('Order not found.');
      final order = Order.fromDoc(orderSnap);
      if (!order.isPending) {
        throw AppException('This order is already {status}.', {
          'status': AppStrings.tr(order.status),
        });
      }

      final products = await _readProducts(tx, order.items);
      _checkStock(products, order.items);

      final repriced = [
        for (final item in order.items)
          _priceItem(products[item.productId]!, item.qty),
      ];
      _deductStock(
        tx,
        products,
        order.items,
        staffId: staffId,
        type: MovementType.order,
        orderId: orderId,
      );

      tx.update(orderRef, {
        'status': OrderStatus.ready,
        'items': [for (final i in repriced) i.toMap()],
        'totalSen': totalOf(repriced),
        'pointsEarned': calculateGreenPoints(
          noPlasticBag: order.noPlasticBag,
          saveFoodItemCount: saveFoodCountOf(repriced),
        ),
        'handledBy': staffId,
        'readyAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Staff scanned the pickup QR: READY -> COLLECTED, green points added.
  Future<void> markCollected(String orderId, {required String staffId}) async {
    final orderRef = _orders.doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw const AppException('Order not found.');
      final order = Order.fromDoc(snap);
      if (!order.isReady) throw AppException(notReadyMessage(order));
      tx.update(orderRef, {
        'status': OrderStatus.collected,
        'handledBy': staffId,
        'collectedAt': FieldValue.serverTimestamp(),
      });
      if (order.userId != null && order.pointsEarned > 0) {
        tx.update(_db.collection('users').doc(order.userId), {
          'greenPoints': FieldValue.increment(order.pointsEarned),
        });
      }
    });
  }

  /// Student cancels their own PENDING order (only `status` may change,
  /// see the security rules).
  Future<void> cancelPending(String orderId) =>
      _orders.doc(orderId).update({'status': OrderStatus.cancelled});

  /// TC19: shown when staff scan a pickup QR that is not READY.
  static String notReadyMessage(Order order) => order.isPending
      ? AppStrings.tr('Order not ready for pickup. Tap "Accept & pack" first.')
      : AppStrings.tr('Order not ready for pickup (already {status}).', {
          'status': AppStrings.tr(order.status),
        });

  /// S6: staff tap "Cancel uncollected" when the koperasi closes. Every
  /// READY order past the pickup window is cancelled and its stock restored.
  /// Returns how many orders were cancelled.
  Future<int> cancelUncollected({required String staffId}) async {
    final snap = await _orders
        .where('status', isEqualTo: OrderStatus.ready)
        .get();
    var cancelled = 0;
    for (final order in snap.docs.map(Order.fromDoc)) {
      if (!order.isUncollected()) continue;
      try {
        await cancelByStaff(
          order.id,
          staffId: staffId,
          reason: CancelReason.notCollected,
        );
        cancelled++;
      } on AppException {
        // Collected or cancelled at the same moment: nothing to do.
      }
    }
    return cancelled;
  }

  /// Staff cancel/reject. If stock was already deducted (READY), it is
  /// restored with `order_cancel` movements.
  Future<void> cancelByStaff(
    String orderId, {
    required String staffId,
    String? reason,
  }) async {
    final orderRef = _orders.doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw const AppException('Order not found.');
      final order = Order.fromDoc(snap);
      if (order.isCollected || order.isCancelled) {
        throw AppException('This order is already {status}.', {
          'status': AppStrings.tr(order.status),
        });
      }
      if (order.isReady) {
        final qty = _qtyByProduct(order.items);
        final refs = {for (final id in qty.keys) id: _products.doc(id)};
        final snaps = {
          for (final e in refs.entries) e.key: await tx.get(e.value),
        };
        for (final e in qty.entries) {
          final productSnap = snaps[e.key]!;
          if (!productSnap.exists) {
            continue; // product deleted: nothing to restore
          }
          final current = readInt(productSnap.data()!['stock']);
          tx.update(refs[e.key]!, {
            'stock': current + e.value,
            // Counted as sold at "Accept & pack"; it never left the shop.
            'soldCount': FieldValue.increment(-e.value),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(
            _movements.doc(),
            StockMovement.newMap(
              productId: e.key,
              productName: productSnap.data()!['name'] as String? ?? e.key,
              type: MovementType.orderCancel,
              quantity: e.value,
              source: MovementSource.order,
              byUserId: staffId,
              stockAfter: current + e.value,
              orderId: orderId,
            ),
          );
        }
      }
      tx.update(orderRef, {
        'status': OrderStatus.cancelled,
        'handledBy': staffId,
        'cancelReason': ?reason,
      });
    });
  }

  // ----------------------------------------------------------- counter sale

  /// Walk-in sale: stock is deducted in a transaction and the order is
  /// saved as 'counter' / 'collected' (= digital receipt). If the student's
  /// member QR was scanned, the receipt and points go to them.
  Future<String> counterSale({
    required List<OrderItem> requested,
    required String staffId,
    required bool noPlasticBag,
    AppUser? member,
  }) async {
    if (requested.isEmpty) throw const AppException('No items scanned.');
    final orderRef = _orders.doc();
    await _db.runTransaction((tx) async {
      final products = await _readProducts(tx, requested);
      _checkStock(products, requested);
      final items = [
        for (final r in requested) _priceItem(products[r.productId]!, r.qty),
      ];
      _deductStock(
        tx,
        products,
        requested,
        staffId: staffId,
        type: MovementType.sale,
        orderId: orderRef.id,
      );

      final points = member == null
          ? 0
          : calculateGreenPoints(
              noPlasticBag: noPlasticBag,
              saveFoodItemCount: saveFoodCountOf(items),
            );
      tx.set(orderRef, {
        'type': OrderType.counter,
        'userId': member?.uid,
        'customerName': member?.name,
        'items': [for (final i in items) i.toMap()],
        'totalSen': totalOf(items),
        'status': OrderStatus.collected,
        'noPlasticBag': noPlasticBag,
        'pickupCode': null,
        'pointsEarned': points,
        'handledBy': staffId,
        'createdAt': FieldValue.serverTimestamp(),
        'readyAt': null,
        'collectedAt': FieldValue.serverTimestamp(),
      });
      if (member != null && points > 0) {
        tx.update(_db.collection('users').doc(member.uid), {
          'greenPoints': FieldValue.increment(points),
        });
      }
    });
    return orderRef.id;
  }

  // ---------------------------------------------------------------- helpers

  Map<String, int> _qtyByProduct(List<OrderItem> items) {
    final qty = <String, int>{};
    for (final i in items) {
      qty[i.productId] = (qty[i.productId] ?? 0) + i.qty;
    }
    return qty;
  }

  /// Transactions must do all reads before any write.
  Future<Map<String, Product>> _readProducts(
    Transaction tx,
    List<OrderItem> items,
  ) async {
    final result = <String, Product>{};
    for (final id in _qtyByProduct(items).keys) {
      final snap = await tx.get(_products.doc(id));
      if (!snap.exists) {
        final name = items.firstWhere((i) => i.productId == id).name;
        throw AppException('{name} is no longer sold.', {'name': name});
      }
      result[id] = Product.fromDoc(snap);
    }
    return result;
  }

  void _checkStock(Map<String, Product> products, List<OrderItem> items) {
    for (final e in _qtyByProduct(items).entries) {
      final p = products[e.key]!;
      if (!p.isActive) {
        throw AppException('{name} is not available.', {'name': p.name});
      }
      if (p.stock < e.value) {
        throw p.stock <= 0
            ? AppException('{name} is out of stock.', {'name': p.name})
            : AppException('Not enough stock for {name} (only {left} left).', {
                'name': p.name,
                'left': p.stock,
              });
      }
    }
  }

  OrderItem _priceItem(Product p, int qty) => OrderItem(
    productId: p.barcode,
    name: p.name,
    unitPriceSen: p.effectivePriceSen,
    qty: qty,
    isSaveFood: p.isOnSaveFood,
  );

  void _deductStock(
    Transaction tx,
    Map<String, Product> products,
    List<OrderItem> items, {
    required String staffId,
    required String type,
    required String orderId,
  }) {
    for (final e in _qtyByProduct(items).entries) {
      final p = products[e.key]!;
      final after = p.stock - e.value;
      tx.update(_products.doc(e.key), {
        'stock': after,
        // Real sales: the AI Budget Planner's popularity score
        'soldCount': FieldValue.increment(e.value),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        _movements.doc(),
        StockMovement.newMap(
          productId: p.barcode,
          productName: p.name,
          type: type,
          quantity: -e.value,
          source: type == MovementType.sale
              ? MovementSource.barcode
              : MovementSource.order,
          byUserId: staffId,
          stockAfter: after,
          orderId: orderId,
        ),
      );
    }
  }
}
