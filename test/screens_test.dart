import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartshop/core/constants.dart';
import 'package:smartshop/core/theme.dart';
import 'package:smartshop/l10n/strings.dart';
import 'package:smartshop/models/app_user.dart';
import 'package:smartshop/models/order.dart';
import 'package:smartshop/models/product.dart';
import 'package:smartshop/models/stock_movement.dart';
import 'package:smartshop/screens/common/receipt_screen.dart';
import 'package:smartshop/screens/staff/alerts_screen.dart';
import 'package:smartshop/screens/staff/dashboard_screen.dart';
import 'package:smartshop/screens/staff/more_screen.dart';
import 'package:smartshop/screens/staff/orders_queue_screen.dart';
import 'package:smartshop/screens/staff/product_form_screen.dart';
import 'package:smartshop/screens/staff/products_screen.dart';
import 'package:smartshop/screens/staff/qr_label_screen.dart';
import 'package:smartshop/screens/staff/reports_screen.dart';
import 'package:smartshop/screens/staff/staff_accounts_screen.dart';
import 'package:smartshop/screens/staff/stock_screen.dart';
import 'package:smartshop/screens/student/cart_screen.dart';
import 'package:smartshop/screens/student/green_points_screen.dart';
import 'package:smartshop/screens/student/home_screen.dart';
import 'package:smartshop/screens/student/my_orders_screen.dart';
import 'package:smartshop/screens/student/order_detail_screen.dart';
import 'package:smartshop/screens/student/product_detail_screen.dart';
import 'package:smartshop/screens/student/product_list_screen.dart';
import 'package:smartshop/services/auth_service.dart';
import 'package:smartshop/services/expiry_scan_service.dart';
import 'package:smartshop/services/order_service.dart';
import 'package:smartshop/services/product_service.dart';
import 'package:smartshop/services/stock_service.dart';
import 'package:smartshop/viewmodels/auth_view_model.dart';
import 'package:smartshop/viewmodels/cart_view_model.dart';
import 'package:smartshop/viewmodels/common/order_view_model.dart';
import 'package:smartshop/viewmodels/settings_view_model.dart';
import 'package:smartshop/viewmodels/staff/alerts_view_model.dart';
import 'package:smartshop/viewmodels/staff/dashboard_view_model.dart';
import 'package:smartshop/viewmodels/staff/more_view_model.dart';
import 'package:smartshop/viewmodels/staff/orders_queue_view_model.dart';
import 'package:smartshop/viewmodels/staff/product_form_view_model.dart';
import 'package:smartshop/viewmodels/staff/products_view_model.dart';
import 'package:smartshop/viewmodels/staff/qr_label_view_model.dart';
import 'package:smartshop/viewmodels/staff/reports_view_model.dart';
import 'package:smartshop/viewmodels/staff/staff_accounts_view_model.dart';
import 'package:smartshop/viewmodels/staff/stock_view_model.dart';
import 'package:smartshop/viewmodels/student/checkout_view_model.dart';
import 'package:smartshop/viewmodels/student/green_points_view_model.dart';
import 'package:smartshop/viewmodels/student/home_view_model.dart';
import 'package:smartshop/viewmodels/student/my_orders_view_model.dart';
import 'package:smartshop/viewmodels/student/product_detail_view_model.dart';
import 'package:smartshop/viewmodels/student/product_list_view_model.dart';

// Every screen is opened the way the router builds it (View + ViewModel)
// over fake services: catches a missing ViewModel or a ViewModel that
// redraws while the page is still being built.

final maggi = Product(
  barcode: 'SK-000009',
  name: 'Maggi Kari',
  category: 'Food',
  priceSen: 1000,
  stock: 3,
  lowStockThreshold: 5,
  expiryDate: DateTime.now().add(const Duration(days: 2)),
  description: 'Spicy curry noodles.',
);

final ready = Order(
  id: 'order-1',
  type: OrderType.preorder,
  userId: 'student-1',
  customerName: 'Test1',
  items: const [
    OrderItem(
      productId: 'SK-000009',
      name: 'Maggi Kari',
      unitPriceSen: 1000,
      qty: 1,
      isSaveFood: false,
    ),
  ],
  totalSen: 1000,
  status: OrderStatus.ready,
  noPlasticBag: true,
  pickupCode: 'ABC234',
  pointsEarned: 5,
  createdAt: DateTime.now(),
);

class FakeProducts implements ProductService {
  @override
  Stream<List<Product>> watchAllProducts() => Stream.value([maggi]);
  @override
  Stream<List<Product>> watchActiveProducts() => Stream.value([maggi]);
  @override
  Stream<Product?> watchProduct(String barcode) => Stream.value(maggi);
  @override
  Future<Product?> findByBarcode(String code) async => maggi;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeOrders implements OrderService {
  @override
  Stream<List<Order>> watchQueue() => Stream.value([ready]);
  @override
  Stream<List<Order>> watchOrdersSince(DateTime since) => Stream.value([ready]);
  @override
  Stream<List<Order>> watchMyOrders(String uid) => Stream.value([ready]);
  @override
  Stream<Order?> watchOrder(String id) => Stream.value(ready);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeStock implements StockService {
  @override
  Stream<List<StockMovement>> watchRecentMovements({int limit = 30}) =>
      Stream.value(const []);
  @override
  Stream<List<StockMovement>> watchMovementsSince(DateTime since) =>
      Stream.value(const []);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeAuth implements AuthService {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
  @override
  Stream<List<AppUser>> watchStaff() => Stream.value(const []);
  @override
  Stream<List<String>> watchStaffInvites() => Stream.value(['new@uts.edu.my']);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeExpiry implements ExpiryScanService {
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final products = FakeProducts();
final orders = FakeOrders();
final stock = FakeStock();

/// Opens [view] with its ViewModel, like `_mvvm` in core/router.dart.
Future<void> open<T extends ChangeNotifier>(
  WidgetTester tester,
  T Function(BuildContext c) create,
  Widget view,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsViewModel(prefs)),
        ChangeNotifierProvider(create: (_) => AuthViewModel(FakeAuth())),
        ChangeNotifierProvider(create: (_) => CartViewModel()),
      ],
      child: MaterialApp(
        theme: buildAppTheme(useGoogleFonts: false),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ChangeNotifierProvider<T>(create: create, child: view),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason: error is FlutterError ? error.toStringDeep() : '$error',
  );
  await tester.pumpWidget(const SizedBox()); // close: stop timers, streams
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('student screens open with their ViewModel', () {
    testWidgets('Home', (t) async {
      await open(
        t,
        (_) => HomeViewModel(products, orders, 'student-1'),
        const StudentHomeScreen(),
      );
    });
    testWidgets('Product list', (t) async {
      await open(
        t,
        (_) => ProductListViewModel(products),
        const ProductListScreen(),
      );
    });
    testWidgets('Product page', (t) async {
      await open(
        t,
        (c) => ProductDetailViewModel(
          products,
          c.read<CartViewModel>(),
          maggi.barcode,
        ),
        const ProductDetailScreen(),
      );
    });
    testWidgets('Cart', (t) async {
      await open(
        t,
        (c) => CheckoutViewModel(
          orders,
          c.read<CartViewModel>(),
          c.read<AuthViewModel>(),
        ),
        const CartScreen(),
      );
    });
    testWidgets('My orders, order page, receipt, points', (t) async {
      await open(
        t,
        (_) => MyOrdersViewModel(orders, 'student-1'),
        const MyOrdersScreen(),
      );
      await open(
        t,
        (_) => OrderViewModel(orders, ready.id),
        const OrderDetailScreen(),
      );
      await open(
        t,
        (_) => OrderViewModel(orders, ready.id),
        const ReceiptScreen(),
      );
      await open(
        t,
        (_) => GreenPointsViewModel(orders, 'student-1'),
        const GreenPointsScreen(),
      );
    });
  });

  group('staff screens open with their ViewModel', () {
    testWidgets('Dashboard', (t) async {
      await open(
        t,
        (_) => DashboardViewModel(products, orders, 'staff-1'),
        const DashboardScreen(),
      );
    });
    testWidgets('Orders queue', (t) async {
      await open(
        t,
        (_) => OrdersQueueViewModel(orders, 'staff-1'),
        const OrdersQueueScreen(),
      );
    });
    testWidgets('Products, new and edit form', (t) async {
      await open(t, (_) => ProductsViewModel(products), const ProductsScreen());
      await open(
        t,
        (_) => ProductFormViewModel(
          products,
          'staff-1',
          newBarcode: '9556001234567',
          expiryScanner: FakeExpiry(),
        ),
        const ProductFormScreen(),
      );
      await open(
        t,
        (_) => ProductFormViewModel(
          products,
          'staff-1',
          editBarcode: maggi.barcode,
          expiryScanner: FakeExpiry(),
        ),
        const ProductFormScreen(),
      );
    });
    testWidgets('Stock', (t) async {
      await open(
        t,
        (_) => StockViewModel(
          products,
          stock,
          'staff-1',
          expiryScanner: FakeExpiry(),
        ),
        const StockScreen(),
      );
    });
    testWidgets('Alerts', (t) async {
      await open(
        t,
        (_) => AlertsViewModel(products, stock, 'staff-1'),
        const AlertsScreen(),
      );
    });
    testWidgets('QR label', (t) async {
      await open(
        t,
        (_) => QrLabelViewModel(products, maggi.barcode),
        const QrLabelScreen(),
      );
    });
    testWidgets('Reports, More, Staff accounts', (t) async {
      await open(
        t,
        (_) => ReportsViewModel(orders, stock),
        const ReportsScreen(),
      );
      await open(
        t,
        (_) => MoreViewModel(products, 'staff-1'),
        const MoreScreen(),
      );
      await open(
        t,
        (_) => StaffAccountsViewModel(FakeAuth(), 'staff-1'),
        const StaffAccountsScreen(),
      );
    });
  });
}
