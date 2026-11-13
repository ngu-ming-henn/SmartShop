import 'package:flutter/foundation.dart';

import '../core/utils/points.dart';
import '../models/order.dart';
import '../models/product.dart';

class CartLine {
  CartLine(this.product, this.qty);

  Product product;
  int qty;

  int get unitPriceSen => product.effectivePriceSen;
  int get lineTotalSen => unitPriceSen * qty;
  bool get isSaveFood => product.isOnSaveFood;

  OrderItem toOrderItem() => OrderItem(
    productId: product.barcode,
    name: product.name,
    unitPriceSen: unitPriceSen,
    qty: qty,
    isSaveFood: isSaveFood,
  );
}

/// The student's cart. Staff "Counter Sale" uses its own instance.
class CartViewModel extends ChangeNotifier {
  final Map<String, CartLine> _lines = {};

  /// On by default: a gentle nudge towards the greener choice.
  bool _noPlasticBag = true;

  List<CartLine> get lines => List.unmodifiable(_lines.values);
  bool get isEmpty => _lines.isEmpty;
  bool get noPlasticBag => _noPlasticBag;

  int get itemCount => _lines.values.fold(0, (sum, l) => sum + l.qty);
  int get totalSen => _lines.values.fold(0, (sum, l) => sum + l.lineTotalSen);
  int get saveFoodItemCount =>
      _lines.values.where((l) => l.isSaveFood).fold(0, (sum, l) => sum + l.qty);
  int get saveFoodSavingsSen => _lines.values.fold(
    0,
    (sum, l) => sum + l.product.saveFoodSavingSen * l.qty,
  );

  int get pointsPreview => calculateGreenPoints(
    noPlasticBag: _noPlasticBag,
    saveFoodItemCount: saveFoodItemCount,
  );

  List<OrderItem> toOrderItems() => [
    for (final l in _lines.values) l.toOrderItem(),
  ];

  int qtyOf(String productId) => _lines[productId]?.qty ?? 0;

  /// Adds [qty] units, never more than the stock shown.
  /// Returns false if nothing could be added.
  bool add(Product product, {int qty = 1}) {
    final line = _lines[product.barcode];
    final current = line?.qty ?? 0;
    final next = (current + qty).clamp(0, product.stock);
    if (next <= current) return false;
    if (line == null) {
      _lines[product.barcode] = CartLine(product, next);
    } else {
      line
        ..product = product
        ..qty = next;
    }
    notifyListeners();
    return true;
  }

  void setQty(String productId, int qty) {
    final line = _lines[productId];
    if (line == null) return;
    if (qty <= 0) {
      _lines.remove(productId);
    } else {
      line.qty = qty.clamp(1, line.product.stock < 1 ? 1 : line.product.stock);
    }
    notifyListeners();
  }

  void remove(String productId) {
    if (_lines.remove(productId) != null) notifyListeners();
  }

  void setNoPlasticBag(bool value) {
    _noPlasticBag = value;
    notifyListeners();
  }

  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    _noPlasticBag = true;
    notifyListeners();
  }
}
