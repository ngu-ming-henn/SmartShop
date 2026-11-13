import '../../models/order.dart';
import '../../services/order_service.dart';
import '../view_model.dart';

/// Orders queue: live pending / ready orders and the staff actions on them
/// (accept & pack, collect, reject / cancel, cancel uncollected).
class OrdersQueueViewModel extends ViewModel {
  OrdersQueueViewModel(this._orders, this._staffId) {
    follow(_orders.watchQueue(), (list) => _queue = list);
  }

  final OrderService _orders;
  final String _staffId;
  List<Order>? _queue;
  final _busyIds = <String>{};

  /// True while cancelling all uncollected orders.
  bool cancellingUncollected = false;

  bool get loading => _queue == null && error == null;

  List<Order> get pending =>
      (_queue ?? const <Order>[]).where((o) => o.isPending).toList();

  List<Order> get ready =>
      (_queue ?? const <Order>[]).where((o) => o.isReady).toList();

  /// Ready orders not collected before closing time.
  int get uncollectedCount => ready.where((o) => o.isUncollected()).length;

  bool isBusy(String orderId) => _busyIds.contains(orderId);

  Future<void> _forOrder(String orderId, Future<void> Function() action) async {
    _busyIds.add(orderId);
    notify();
    try {
      await action();
    } finally {
      _busyIds.remove(orderId);
      notify();
    }
  }

  /// Takes the stock off and marks the order READY (the student is told).
  Future<void> accept(Order o) =>
      _forOrder(o.id, () => _orders.acceptAndPack(o.id, staffId: _staffId));

  /// Paid at the counter: READY -> COLLECTED, green points added.
  Future<void> collect(Order o) =>
      _forOrder(o.id, () => _orders.markCollected(o.id, staffId: _staffId));

  /// Reject a pending order or cancel a ready one (stock goes back).
  Future<void> cancel(Order o) =>
      _forOrder(o.id, () => _orders.cancelByStaff(o.id, staffId: _staffId));

  /// The order behind a scanned pickup QR, or null.
  Future<Order?> findByPickupCode(String code) =>
      _orders.findByPickupCode(code);

  /// Why a scanned order cannot be collected yet (in the app language).
  String notReadyMessage(Order o) => OrderService.notReadyMessage(o);

  /// Cancels every uncollected READY order; returns how many.
  Future<int> cancelUncollected() async {
    cancellingUncollected = true;
    notify();
    try {
      return await _orders.cancelUncollected(staffId: _staffId);
    } finally {
      cancellingUncollected = false;
      notify();
    }
  }
}
