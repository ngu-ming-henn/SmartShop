import 'dart:async';

import '../../core/constants.dart';
import '../../core/utils/format.dart';
import '../../models/order.dart';
import '../../models/stock_movement.dart';
import '../../services/order_service.dart';
import '../../services/stock_service.dart';
import '../view_model.dart';

/// Reports: sales and stock movements of the last 7 or 30 days (live),
/// turned into a [Report]. Switching the period keeps the old report on
/// screen (dimmed) until the new numbers arrive.
class ReportsViewModel extends ViewModel {
  ReportsViewModel(this._orders, this._stock) {
    _subscribe();
  }

  final OrderService _orders;
  final StockService _stock;
  StreamSubscription<List<Order>>? _orderSub;
  StreamSubscription<List<StockMovement>>? _moveSub;
  List<Order>? _orderList;
  List<StockMovement>? _moves;

  int days = 7;
  late DateTime since;

  /// The last finished report; null until the first one is ready.
  Report? report;

  /// A new period is loading.
  bool refreshing = false;

  bool get loading => report == null && error == null;

  void showDays(int value) {
    if (value == days) return;
    days = value;
    refreshing = true;
    _subscribe();
    notify();
  }

  void _subscribe() {
    _orderSub?.cancel();
    _moveSub?.cancel();
    _orderList = null;
    _moves = null;
    final today = dateOnly(DateTime.now());
    since = DateTime(today.year, today.month, today.day - (days - 1));
    _orderSub = _orders.watchOrdersSince(since).listen((list) {
      _orderList = list;
      _rebuild();
    }, onError: _failed);
    _moveSub = _stock.watchMovementsSince(since).listen((list) {
      _moves = list;
      _rebuild();
    }, onError: _failed);
  }

  void _rebuild() {
    if (_orderList == null || _moves == null) return;
    report = Report.build(
      orders: _orderList!,
      movements: _moves!,
      since: since,
      days: days,
    );
    refreshing = false;
    error = null;
    notify();
  }

  void _failed(Object e) {
    error = e;
    notify();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _moveSub?.cancel();
    super.dispose();
  }
}

/// All numbers for one period, computed once per snapshot.
class Report {
  Report({
    required this.dailySales,
    required this.salesSen,
    required this.orderCount,
    required this.preorderCount,
    required this.topProducts,
    required this.itemsSaved,
    required this.itemsExpired,
    required this.receiptsAvoided,
    required this.bagsAvoided,
    required this.preorderNoBagCount,
    required this.outOfStockEvents,
    required this.queueMinutesSaved,
  });

  final List<({DateTime day, int sen, int orders})> dailySales;
  final int salesSen;
  final int orderCount;
  final int preorderCount;
  final List<({String name, int qty})> topProducts;
  final int itemsSaved;
  final int itemsExpired;
  final int receiptsAvoided;
  final int bagsAvoided;
  final int preorderNoBagCount;
  final int outOfStockEvents;
  final int queueMinutesSaved;

  /// MOV: at least 20% of transactions through pre-order.
  int get preorderSharePct =>
      orderCount == 0 ? 0 : (preorderCount * 100 / orderCount).round();

  /// MOV: at least 50% of pre-orders without a plastic bag.
  int get preorderNoBagPct => preorderCount == 0
      ? 0
      : (preorderNoBagCount * 100 / preorderCount).round();

  factory Report.build({
    required List<Order> orders,
    required List<StockMovement> movements,
    required DateTime since,
    required int days,
  }) {
    // Only collected orders are sales (money taken at the counter).
    final sold = orders.where((o) => o.isCollected).toList();

    final senByDay = List.filled(days, 0);
    final ordersByDay = List.filled(days, 0);
    for (final o in sold) {
      final i = daysUntil(o.sortTime, from: since);
      if (i >= 0 && i < days) {
        senByDay[i] += o.totalSen;
        ordersByDay[i]++;
      }
    }

    final qtyByProduct = <String, ({String name, int qty})>{};
    for (final o in sold) {
      for (final item in o.items) {
        final prev = qtyByProduct[item.productId];
        qtyByProduct[item.productId] = (
          name: item.name,
          qty: (prev?.qty ?? 0) + item.qty,
        );
      }
    }
    final top = qtyByProduct.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));

    final preorders = sold.where((o) => o.isPreorder).length;
    return Report(
      dailySales: [
        for (var i = 0; i < days; i++)
          (
            day: DateTime(since.year, since.month, since.day + i),
            sen: senByDay[i],
            orders: ordersByDay[i],
          ),
      ],
      salesSen: sold.fold(0, (sum, o) => sum + o.totalSen),
      orderCount: sold.length,
      preorderCount: preorders,
      topProducts: top.take(5).toList(),
      itemsSaved: sold.fold(0, (sum, o) => sum + o.saveFoodItemCount),
      itemsExpired: movements
          .where((m) => m.type == MovementType.expired)
          .fold(0, (sum, m) => sum + m.quantity.abs()),
      receiptsAvoided: sold.where((o) => o.userId != null).length,
      bagsAvoided: sold.where((o) => o.noPlasticBag).length,
      preorderNoBagCount: sold
          .where((o) => o.isPreorder && o.noPlasticBag)
          .length,
      outOfStockEvents: movements
          .where((m) => m.quantity < 0 && m.stockAfter == 0)
          .length,
      queueMinutesSaved: preorders * AppRules.minutesSavedPerPreorder,
    );
  }
}
