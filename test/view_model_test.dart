import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/constants.dart';
import 'package:smartshop/models/order.dart';
import 'package:smartshop/models/product.dart';
import 'package:smartshop/services/order_service.dart';
import 'package:smartshop/services/product_service.dart';
import 'package:smartshop/viewmodels/staff/dashboard_view_model.dart';
import 'package:smartshop/viewmodels/staff/orders_queue_view_model.dart';
import 'package:smartshop/viewmodels/student/product_list_view_model.dart';

// MVVM pays off here: ViewModels are tested with fake services, without a
// phone, a screen or Firebase.

/// Live product list the test controls.
class FakeProducts implements ProductService {
  final all = StreamController<List<Product>>.broadcast();

  @override
  Stream<List<Product>> watchAllProducts() => all.stream;

  @override
  Stream<List<Product>> watchActiveProducts() =>
      all.stream.map((l) => l.where((p) => p.isActive).toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Live orders the test controls; records staff actions.
class FakeOrders implements OrderService {
  final queue = StreamController<List<Order>>.broadcast();
  final today = StreamController<List<Order>>.broadcast();
  final accepted = <String>[];
  Completer<void>? holdAccept;

  @override
  Stream<List<Order>> watchQueue() => queue.stream;

  @override
  Stream<List<Order>> watchOrdersSince(DateTime since) => today.stream;

  @override
  Future<void> acceptAndPack(String orderId, {required String staffId}) async {
    await holdAccept?.future;
    accepted.add('$orderId by $staffId');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product product(
  String name, {
  int stock = 10,
  String category = 'Food',
  bool active = true,
  DateTime? expiry,
}) => Product(
  barcode: name,
  name: name,
  category: category,
  priceSen: 300,
  stock: stock,
  lowStockThreshold: 5,
  expiryDate: expiry,
  isActive: active,
);

Order order(String id, String status, {int totalSen = 500}) => Order(
  id: id,
  type: OrderType.preorder,
  userId: 'student-1',
  customerName: 'Test1',
  items: const [],
  totalSen: totalSen,
  status: status,
  noPlasticBag: true,
  pickupCode: 'ABC234',
  pointsEarned: 5,
  createdAt: DateTime(2026, 11, 13, 9),
  collectedAt: status == OrderStatus.collected
      ? DateTime(2026, 11, 13, 10)
      : null,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('dashboard turns live data into the numbers on screen', () async {
    final products = FakeProducts();
    final orders = FakeOrders();
    final vm = DashboardViewModel(
      products,
      orders,
      'staff-1',
      now: DateTime(2026, 11, 13, 12),
    );
    var redraws = 0;
    vm.addListener(() => redraws++);
    expect(vm.loadingSales, isTrue);

    products.all.add([
      product('Bread', stock: 2), // low stock
      product('Milk', expiry: DateTime(2026, 11, 14)), // near expiry
      product('Pen', category: 'Stationery'),
      product('Old', stock: 0, active: false), // hidden: not counted
    ]);
    orders.queue.add([
      order('a', OrderStatus.pending),
      order('b', OrderStatus.pending),
      order('c', OrderStatus.ready),
    ]);
    orders.today.add([
      order('d', OrderStatus.collected, totalSen: 1200),
      order('e', OrderStatus.collected, totalSen: 350),
      order('f', OrderStatus.cancelled, totalSen: 900), // not a sale
    ]);
    await settle();

    expect(vm.lowStockCount, 1);
    expect(vm.nearExpiryCount, 1);
    expect(vm.pendingCount, 2);
    expect(vm.readyCount, 1);
    expect(vm.todaySales.map((o) => o.id), ['d', 'e']);
    expect(vm.salesTodaySen, 1550);
    expect(vm.shopIsEmpty, isFalse);
    expect(redraws, 3); // the View redraws on every live update

    // A new order arrives: the dashboard updates by itself.
    orders.queue.add([
      order('a', OrderStatus.pending),
      order('b', OrderStatus.pending),
      order('g', OrderStatus.pending),
      order('c', OrderStatus.ready),
    ]);
    await settle();
    expect(vm.pendingCount, 3);
    vm.dispose();
  });

  test('empty shop is offered the sample products', () async {
    final products = FakeProducts();
    final vm = DashboardViewModel(products, FakeOrders(), 'staff-1');
    products.all.add(const []);
    await settle();
    expect(vm.shopIsEmpty, isTrue);
    vm.dispose();
  });

  test('orders queue shows a spinner only on the order being packed', () async {
    final orders = FakeOrders()..holdAccept = Completer<void>();
    final vm = OrdersQueueViewModel(orders, 'staff-1');
    orders.queue.add([
      order('a', OrderStatus.pending),
      order('b', OrderStatus.pending),
    ]);
    await settle();
    expect(vm.pending, hasLength(2));

    final packing = vm.accept(vm.pending.first);
    expect(vm.isBusy('a'), isTrue);
    expect(vm.isBusy('b'), isFalse);
    orders.holdAccept!.complete();
    await packing;
    expect(vm.isBusy('a'), isFalse);
    expect(orders.accepted, ['a by staff-1']);
    vm.dispose();
  });

  test('product list filters by search, category and stock', () async {
    final products = FakeProducts();
    final vm = ProductListViewModel(products, initialCategory: 'Food');
    expect(vm.items, isNull); // loading
    products.all.add([
      product('Maggi Kari'),
      product('Milo', category: 'Drinks'),
      product('Bread', stock: 0),
    ]);
    await settle();
    expect(vm.items!.map((p) => p.name), ['Maggi Kari', 'Bread']);

    vm.showInStockOnly(true);
    expect(vm.items!.map((p) => p.name), ['Maggi Kari']);

    vm.showCategory(null);
    vm.search('mil');
    expect(vm.items!.map((p) => p.name), ['Milo']);
    vm.dispose();
  });
}
