import '../../models/order.dart';
import '../../services/order_service.dart';
import '../view_model.dart';

/// One order, live: the student's order page (pickup QR, status) and the
/// digital receipt. Students may cancel it while it is still pending.
class OrderViewModel extends ViewModel {
  OrderViewModel(this._orders, this.orderId) {
    follow(_orders.watchOrder(orderId), (o) {
      _order = o;
      _loaded = true;
    });
  }

  final OrderService _orders;
  final String orderId;
  Order? _order;
  bool _loaded = false;

  bool get loading => !_loaded && error == null;

  /// Null when it does not exist (or is not yours).
  Order? get order => _order;

  Future<void> cancel() => run(() => _orders.cancelPending(orderId));
}
