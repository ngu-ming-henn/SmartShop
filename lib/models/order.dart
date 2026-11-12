import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/utils/firestore_helpers.dart';

/// One line in `orders/{id}.items`.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.unitPriceSen,
    required this.qty,
    required this.isSaveFood,
  });

  final String productId;
  final String name;
  final int unitPriceSen;
  final int qty;
  final bool isSaveFood;

  int get lineTotalSen => unitPriceSen * qty;

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
    productId: m['productId'] as String? ?? '',
    name: m['name'] as String? ?? '',
    unitPriceSen: readInt(m['unitPriceSen']),
    qty: readInt(m['qty'], 1),
    isSaveFood: m['isSaveFood'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'unitPriceSen': unitPriceSen,
    'qty': qty,
    'isSaveFood': isSaveFood,
  };
}

int totalOf(Iterable<OrderItem> items) =>
    items.fold(0, (total, i) => total + i.lineTotalSen);

int saveFoodCountOf(Iterable<OrderItem> items) =>
    items.where((i) => i.isSaveFood).fold(0, (total, i) => total + i.qty);

/// A document in `orders/{orderId}`: a pre-order or a counter sale.
/// A collected order is the digital receipt.
class Order {
  const Order({
    required this.id,
    required this.type,
    required this.userId,
    required this.customerName,
    required this.items,
    required this.totalSen,
    required this.status,
    required this.noPlasticBag,
    required this.pickupCode,
    required this.pointsEarned,
    this.handledBy,
    this.cancelReason,
    this.createdAt,
    this.readyAt,
    this.collectedAt,
  });

  final String id;
  final String type; // 'preorder' | 'counter'
  final String? userId; // null = anonymous counter sale
  final String? customerName;
  final List<OrderItem> items;
  final int totalSen;
  final String status; // 'pending' | 'ready' | 'collected' | 'cancelled'
  final bool noPlasticBag;
  final String? pickupCode;
  final int pointsEarned;
  final String? handledBy;
  final String? cancelReason; // see CancelReason, set by staff only
  final DateTime? createdAt; // null while the server timestamp is pending
  final DateTime? readyAt;
  final DateTime? collectedAt;

  bool get isPreorder => type == OrderType.preorder;
  bool get isPending => status == OrderStatus.pending;
  bool get isReady => status == OrderStatus.ready;
  bool get isCollected => status == OrderStatus.collected;
  bool get isCancelled => status == OrderStatus.cancelled;
  bool get wasNotCollected =>
      isCancelled && cancelReason == CancelReason.notCollected;

  int get itemCount => items.fold(0, (total, i) => total + i.qty);
  int get saveFoodItemCount => saveFoodCountOf(items);

  /// For sorting: a pending server timestamp means "just now".
  DateTime get sortTime => createdAt ?? DateTime.now();

  /// Business rule 7.4: collect on the same day before the koperasi closes.
  /// An order packed after closing time can be collected the next day.
  DateTime? get pickupDeadline {
    final ready = readyAt;
    if (ready == null) return null;
    final closing = DateTime(
      ready.year,
      ready.month,
      ready.day,
      AppRules.closingHour,
    );
    return ready.isBefore(closing)
        ? closing
        : DateTime(
            ready.year,
            ready.month,
            ready.day + 1,
            AppRules.closingHour,
          );
  }

  /// READY but not collected before [pickupDeadline] (S6).
  bool isUncollected({DateTime? now}) {
    final deadline = pickupDeadline;
    return isReady &&
        deadline != null &&
        !(now ?? DateTime.now()).isBefore(deadline);
  }

  factory Order.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawItems = d['items'] as List<dynamic>? ?? const [];
    return Order(
      id: doc.id,
      type: d['type'] as String? ?? OrderType.preorder,
      userId: d['userId'] as String?,
      customerName: d['customerName'] as String?,
      items: [
        for (final i in rawItems)
          if (i is Map) OrderItem.fromMap(Map<String, dynamic>.from(i)),
      ],
      totalSen: readInt(d['totalSen']),
      status: d['status'] as String? ?? OrderStatus.pending,
      noPlasticBag: d['noPlasticBag'] as bool? ?? false,
      pickupCode: d['pickupCode'] as String?,
      pointsEarned: readInt(d['pointsEarned']),
      handledBy: d['handledBy'] as String?,
      cancelReason: d['cancelReason'] as String?,
      createdAt: readDate(d['createdAt']),
      readyAt: readDate(d['readyAt']),
      collectedAt: readDate(d['collectedAt']),
    );
  }
}
