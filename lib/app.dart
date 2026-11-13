import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'l10n/strings.dart';
import 'viewmodels/auth_view_model.dart';
import 'viewmodels/cart_view_model.dart';
import 'services/notification_watcher.dart';
import 'viewmodels/settings_view_model.dart';
import 'services/auth_service.dart';
import 'services/budget_planner_service.dart';
import 'services/order_service.dart';
import 'services/product_service.dart';
import 'services/stock_service.dart';

class SmartShopApp extends StatefulWidget {
  const SmartShopApp({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<SmartShopApp> createState() => _SmartShopAppState();
}

class _SmartShopAppState extends State<SmartShopApp> {
  final _authService = AuthService();
  final _productService = ProductService();
  final _stockService = StockService();
  final _orderService = OrderService();
  final _budgetPlanner = BudgetPlannerService();
  final _cart = CartViewModel();
  late final AuthViewModel _auth = AuthViewModel(_authService);
  late final SettingsViewModel _settings = SettingsViewModel(widget.prefs);
  final _splash = SplashGate();
  late final GoRouter _router = createRouter(_auth, _splash);
  late final NotificationWatcher _watcher = NotificationWatcher(
    products: _productService,
    orders: _orderService,
  );

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
  }

  /// Start/stop alert listeners and clear the cart when the user changes.
  void _onAuthChanged() {
    final user = _auth.user;
    if (_auth.status == AuthStatus.signedIn && user != null) {
      _watcher.start(user);
    } else {
      _watcher.stop();
      if (_auth.status == AuthStatus.signedOut) _cart.clear();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _watcher.stop();
    _auth.dispose();
    _cart.dispose();
    _settings.dispose();
    _router.dispose();
    _splash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _authService),
        Provider.value(value: _productService),
        Provider.value(value: _stockService),
        Provider.value(value: _orderService),
        Provider.value(value: _budgetPlanner),
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _cart),
        ChangeNotifierProvider.value(value: _settings),
      ],
      // Rebuilds the whole app when the language or light/dark mode changes.
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => MaterialApp.router(
          title: 'UTS SmartShop',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: _settings.themeMode,
          locale: _settings.locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: _router,
        ),
      ),
    );
  }
}
