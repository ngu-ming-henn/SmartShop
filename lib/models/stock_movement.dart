import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/utils/firestore_helpers.dart';
import '../l10n/strings.dart';

/// A document in `stock_movements/{id}`: every stock change is logged.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.source,
    required this.byUserId,
    this.expiryDate,
    this.stockAfter,
    this.orderId,
    this.createdAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String type; // see MovementType
  final int quantity; // +24 or -2
  final String source; // see MovementSource
  final String byUserId;
  final DateTime? expiryDate; // for stock_in
  final int? stockAfter; // known when written inside a transaction
  final String? orderId;
  final DateTime? createdAt;

  factory StockMovement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return StockMovement(
      id: doc.id,
      productId: d['productId'] as String? ?? '',
      productName: d['productName'] as String? ?? '',
      type: d['type'] as String? ?? MovementType.adjustment,
      quantity: readInt(d['quantity']),
      source: d['source'] as String? ?? MovementSource.manual,
      byUserId: d['byUserId'] as String? ?? '',
      expiryDate: readDate(d['expiryDate']),
      stockAfter: readIntOrNull(d['stockAfter']),
      orderId: d['orderId'] as String?,
      createdAt: readDate(d['createdAt']),
    );
  }

  /// Fields for a new movement document.
  static Map<String, dynamic> newMap({
    required String productId,
    required String productName,
    required String type,
    required int quantity,
    required String source,
    required String byUserId,
    DateTime? expiryDate,
    int? stockAfter,
    String? orderId,
  }) => {
    'productId': productId,
    'productName': productName,
    'type': type,
    'quantity': quantity,
    'source': source,
    'expiryDate': toTimestamp(expiryDate),
    'byUserId': byUserId,
    'stockAfter': ?stockAfter,
    'orderId': ?orderId,
    'createdAt': FieldValue.serverTimestamp(),
  };

  String get typeLabel => AppStrings.tr(switch (type) {
    MovementType.stockIn => 'Stock in',
    MovementType.sale => 'Counter sale',
    MovementType.order => 'Pre-order',
    MovementType.orderCancel => 'Order cancelled',
    MovementType.expired => 'Expired',
    MovementType.damaged => 'Damaged',
    _ => 'Adjustment',
  });
}
