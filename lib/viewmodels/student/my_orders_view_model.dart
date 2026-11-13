import '../../models/order.dart';
import '../../services/order_service.dart';
import '../view_model.dart';

/// My Orders: the student's orders, live, grouped by status.
class MyOrdersViewModel extends ViewModel {
  MyOrdersViewModel(OrderService orders, String uid) {
    follow(orders.watchMyOrders(uid), (list) => _orders = list);
  }

  List<Order>? _orders;

  bool get loading => _orders == null && error == null;

  List<Order> withStatus(String status) =>
      (_orders ?? const <Order>[]).where((o) => o.status == status).toList();
}
