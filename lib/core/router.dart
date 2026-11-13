import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/budget_planner_service.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/stock_service.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/cart_view_model.dart';
import '../viewmodels/common/order_view_model.dart';
import '../viewmodels/shop_map_view_model.dart';
import '../viewmodels/staff/alerts_view_model.dart';
import '../viewmodels/staff/counter_sale_view_model.dart';
import '../viewmodels/staff/dashboard_view_model.dart';
import '../viewmodels/staff/more_view_model.dart';
import '../viewmodels/staff/orders_queue_view_model.dart';
import '../viewmodels/staff/product_form_view_model.dart';
import '../viewmodels/staff/products_view_model.dart';
import '../viewmodels/staff/qr_label_view_model.dart';
import '../viewmodels/staff/reports_view_model.dart';
import '../viewmodels/staff/staff_accounts_view_model.dart';
import '../viewmodels/staff/stock_view_model.dart';
import '../viewmodels/student/budget_planner_view_model.dart';
import '../viewmodels/student/checkout_view_model.dart';
import '../viewmodels/student/green_points_view_model.dart';
import '../viewmodels/student/home_view_model.dart';
import '../viewmodels/student/my_orders_view_model.dart';
import '../viewmodels/student/product_detail_view_model.dart';
import '../viewmodels/student/product_list_view_model.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/profile_missing_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/common/change_password_screen.dart';
import '../screens/common/edit_profile_screen.dart';
import '../screens/common/profile_screen.dart';
import '../screens/common/receipt_screen.dart';
import '../screens/common/scanner_page.dart';
import '../screens/common/settings_screen.dart';
import '../screens/common/shop_map_screen.dart';
import '../screens/staff/alerts_screen.dart';
import '../screens/staff/counter_sale_screen.dart';
import '../screens/staff/dashboard_screen.dart';
import '../screens/staff/more_screen.dart';
import '../screens/staff/orders_queue_screen.dart';
import '../screens/staff/product_form_screen.dart';
import '../screens/staff/products_screen.dart';
import '../screens/staff/qr_label_screen.dart';
import '../screens/staff/reports_screen.dart';
import '../screens/staff/staff_accounts_screen.dart';
import '../screens/staff/staff_shell.dart';
import '../screens/staff/stock_screen.dart';
import '../screens/student/budget_planner_screen.dart';
import '../screens/student/cart_screen.dart';
import '../screens/student/green_points_screen.dart';
import '../screens/student/home_screen.dart';
import '../screens/student/my_orders_screen.dart';
import '../screens/student/order_detail_screen.dart';
import '../screens/student/product_detail_screen.dart';
import '../screens/student/product_list_screen.dart';
import '../screens/student/scan_screen.dart';
import '../screens/student/student_shell.dart';

const _authPages = {'/login', '/register', '/forgot-password'};

/// Pages both roles may open.
bool _isShared(String loc) =>
    loc.startsWith('/receipt/') ||
    loc.startsWith('/account/') ||
    loc == '/settings' ||
    loc == '/shop' ||
    loc == '/scanner';

/// Keeps the opening animation on screen until it has finished playing.
class SplashGate extends ChangeNotifier {
  bool _done = false;
  bool get done => _done;

  void finish() {
    if (_done) return;
    _done = true;
    notifyListeners();
  }
}

/// Fade instead of the default slide (splash -> login).
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 600),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );

/// MVVM wiring: a page (View) together with its ViewModel. The ViewModel
/// gets the services provided at the top of the app (`c.read<...>()`) and
/// is disposed with the page, so its live Firestore streams stop too.
Widget _mvvm<T extends ChangeNotifier>(
  T Function(BuildContext c) create,
  Widget view,
) => ChangeNotifierProvider<T>(create: create, child: view);

/// go_router with role-based redirects: students -> /home, staff -> /staff.
GoRouter createRouter(AuthViewModel auth, SplashGate splash) {
  String uid() => auth.user?.uid ?? '';
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([auth, splash]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!splash.done) return loc == '/splash' ? null : '/splash';
      switch (auth.status) {
        case AuthStatus.unknown:
        case AuthStatus.loadingProfile:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.signedOut:
          return _authPages.contains(loc) ? null : '/login';
        case AuthStatus.profileMissing:
          return loc == '/profile-missing' ? null : '/profile-missing';
        case AuthStatus.signedIn:
          final isStaff = auth.isStaff;
          final home = isStaff ? '/staff' : '/home';
          if (_authPages.contains(loc) ||
              loc == '/splash' ||
              loc == '/profile-missing') {
            return home;
          }
          if (_isShared(loc)) return null;
          final staffRoute = loc == '/staff' || loc.startsWith('/staff/');
          if (isStaff && !staffRoute) return '/staff';
          if (!isStaff && staffRoute) return '/home';
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => _fadePage(state, SplashScreen(gate: splash)),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/profile-missing',
        builder: (_, _) => const ProfileMissingScreen(),
      ),

      // ------------------------------------------------------------ student
      ShellRoute(
        builder: (context, state, child) =>
            StudentShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => _mvvm(
              (c) => HomeViewModel(
                c.read<ProductService>(),
                c.read<OrderService>(),
                uid(),
              ),
              const StudentHomeScreen(),
            ),
          ),
          GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
          GoRoute(
            path: '/orders',
            builder: (_, _) => _mvvm(
              (c) => MyOrdersViewModel(c.read<OrderService>(), uid()),
              const MyOrdersScreen(),
            ),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/product/:code',
        builder: (_, state) => _mvvm(
          (c) => ProductDetailViewModel(
            c.read<ProductService>(),
            c.read<CartViewModel>(),
            state.pathParameters['code']!,
          ),
          const ProductDetailScreen(),
        ),
      ),
      GoRoute(
        path: '/products',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return _mvvm(
            (c) => ProductListViewModel(
              c.read<ProductService>(),
              initialCategory: q['category'],
              query: q['q'],
              saveFoodOnly: q['saveFood'] == '1',
            ),
            const ProductListScreen(),
          );
        },
      ),
      GoRoute(
        path: '/cart',
        builder: (_, _) => _mvvm(
          (c) => CheckoutViewModel(
            c.read<OrderService>(),
            c.read<CartViewModel>(),
            auth,
          ),
          const CartScreen(),
        ),
      ),
      GoRoute(
        path: '/planner',
        builder: (_, _) => _mvvm(
          (c) => BudgetPlannerViewModel(
            c.read<BudgetPlannerService>(),
            c.read<ProductService>(),
            c.read<CartViewModel>(),
            uid(),
          ),
          const BudgetPlannerScreen(),
        ),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) => _mvvm(
          (c) => OrderViewModel(
            c.read<OrderService>(),
            state.pathParameters['id']!,
          ),
          const OrderDetailScreen(),
        ),
      ),
      GoRoute(
        path: '/points',
        builder: (_, _) => _mvvm(
          (c) => GreenPointsViewModel(c.read<OrderService>(), uid()),
          const GreenPointsScreen(),
        ),
      ),

      // ------------------------------------------------------------- shared
      GoRoute(
        path: '/receipt/:id',
        builder: (_, state) => _mvvm(
          (c) => OrderViewModel(
            c.read<OrderService>(),
            state.pathParameters['id']!,
          ),
          const ReceiptScreen(),
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/shop',
        builder: (_, _) => _mvvm(
          (_) => ShopMapViewModel(GpsLocationSource()),
          const ShopMapScreen(),
        ),
      ),
      GoRoute(
        path: '/account/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/account/password',
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/scanner',
        builder: (_, state) => ScannerPage(
          title: state.uri.queryParameters['title'] ?? 'Scan',
          hint: state.uri.queryParameters['hint'],
        ),
      ),

      // -------------------------------------------------------------- staff
      ShellRoute(
        builder: (context, state, child) =>
            StaffShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/staff',
            builder: (_, _) => _mvvm(
              (c) => DashboardViewModel(
                c.read<ProductService>(),
                c.read<OrderService>(),
                uid(),
              ),
              const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/staff/stock',
            builder: (_, state) => _mvvm(
              (c) => StockViewModel(
                c.read<ProductService>(),
                c.read<StockService>(),
                uid(),
              ),
              StockScreen(initialCode: state.uri.queryParameters['code']),
            ),
          ),
          GoRoute(
            path: '/staff/orders',
            builder: (_, _) => _mvvm(
              (c) => OrdersQueueViewModel(c.read<OrderService>(), uid()),
              const OrdersQueueScreen(),
            ),
          ),
          GoRoute(
            path: '/staff/reports',
            builder: (_, _) => _mvvm(
              (c) => ReportsViewModel(
                c.read<OrderService>(),
                c.read<StockService>(),
              ),
              const ReportsScreen(),
            ),
          ),
          GoRoute(
            path: '/staff/more',
            builder: (_, _) => _mvvm(
              (c) => MoreViewModel(c.read<ProductService>(), uid()),
              const MoreScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/staff/products',
        builder: (_, _) => _mvvm(
          (c) => ProductsViewModel(c.read<ProductService>()),
          const ProductsScreen(),
        ),
      ),
      GoRoute(
        path: '/staff/product-new',
        builder: (_, state) => _mvvm(
          (c) => ProductFormViewModel(
            c.read<ProductService>(),
            uid(),
            newBarcode: state.uri.queryParameters['barcode'],
          ),
          const ProductFormScreen(),
        ),
      ),
      GoRoute(
        path: '/staff/product/:code',
        builder: (_, state) => _mvvm(
          (c) => ProductFormViewModel(
            c.read<ProductService>(),
            uid(),
            editBarcode: state.pathParameters['code'],
          ),
          const ProductFormScreen(),
        ),
      ),
      GoRoute(
        path: '/staff/counter',
        builder: (_, _) => _mvvm(
          (c) => CounterSaleViewModel(
            c.read<AuthService>(),
            c.read<ProductService>(),
            c.read<OrderService>(),
            uid(),
          ),
          const CounterSaleScreen(),
        ),
      ),
      GoRoute(
        path: '/staff/alerts',
        builder: (_, state) => _mvvm(
          (c) => AlertsViewModel(
            c.read<ProductService>(),
            c.read<StockService>(),
            uid(),
          ),
          AlertsScreen(
            initialTab: state.uri.queryParameters['tab'] == 'expiry' ? 1 : 0,
          ),
        ),
      ),
      GoRoute(
        path: '/staff/label/:code',
        builder: (_, state) => _mvvm(
          (c) => QrLabelViewModel(
            c.read<ProductService>(),
            state.pathParameters['code']!,
          ),
          const QrLabelScreen(),
        ),
      ),
      GoRoute(path: '/staff/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/staff/accounts',
        builder: (_, _) => _mvvm(
          (c) => StaffAccountsViewModel(c.read<AuthService>(), uid()),
          const StaffAccountsScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
}

/// Path-safe product code (barcodes from QR labels may contain any text).
String productPath(String code) => '/product/${Uri.encodeComponent(code)}';
