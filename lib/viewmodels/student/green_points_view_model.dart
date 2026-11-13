import '../../models/order.dart';
import '../../services/order_service.dart';
import '../view_model.dart';

/// Green points: the student's points history and personal impact, from
/// their collected orders (live).
class GreenPointsViewModel extends ViewModel {
  GreenPointsViewModel(OrderService orders, String uid) {
    follow(orders.watchMyOrders(uid), (list) => _orders = list);
  }

  List<Order>? _orders;

  bool get loading => _orders == null && error == null;

  List<Order> get _collected =>
      (_orders ?? const <Order>[]).where((o) => o.isCollected).toList();

  /// Collected orders that earned points, newest first.
  List<Order> get history =>
      _collected.where((o) => o.pointsEarned > 0).toList();

  int get plasticBagsSaved => _collected.where((o) => o.noPlasticBag).length;

  int get foodItemsSaved =>
      _collected.fold(0, (sum, o) => sum + o.saveFoodItemCount);

  /// Each collected order has a digital receipt instead of paper.
  int get paperReceiptsSaved => _collected.length;
}
