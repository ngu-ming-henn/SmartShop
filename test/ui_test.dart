import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartshop/core/theme.dart';
import 'package:smartshop/l10n/strings.dart';
import 'package:smartshop/models/product.dart';
import 'package:smartshop/screens/student/budget_planner_screen.dart';
import 'package:smartshop/services/budget_planner_service.dart';
import 'package:smartshop/services/product_service.dart';
import 'package:smartshop/viewmodels/cart_view_model.dart';
import 'package:smartshop/viewmodels/student/budget_planner_view_model.dart';
import 'package:smartshop/widgets/deal_widgets.dart';
import 'package:smartshop/widgets/password_strength.dart';
import 'package:smartshop/widgets/product_widgets.dart';
import 'package:smartshop/widgets/user_avatar.dart';

Product item(String name, String category, int priceSen, {int? deal}) =>
    Product(
      barcode: name,
      name: name,
      category: category,
      priceSen: priceSen,
      saveFoodPriceSen: deal,
      stock: 10,
      lowStockThreshold: 5,
    );

Widget app(
  Widget child, {
  String language = 'en',
  Brightness brightness = Brightness.light,
}) => ChangeNotifierProvider(
  create: (_) => CartViewModel(),
  child: MaterialApp(
    theme: buildAppTheme(useGoogleFonts: false, brightness: brightness),
    locale: Locale(language),
    supportedLocales: AppStrings.supportedLocales,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: child,
  ),
);

/// The planner screen is only tapped here, nothing is loaded from Firebase.
class _NoProducts implements ProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// The Budget Planner View with its ViewModel, as the router builds it.
Widget planner() => ChangeNotifierProvider(
  create: (c) => BudgetPlannerViewModel(
    BudgetPlannerService(),
    _NoProducts(),
    c.read<CartViewModel>(),
    'student-1',
  ),
  child: const BudgetPlannerScreen(),
);

void main() {
  group('home: 3 categories + hot deal advert', () {
    final featured = [
      item('White Bread Loaf', 'Food', 390, deal: 270),
      item('Milo Ais (cup)', 'Drinks', 300),
    ];

    testWidgets('shows 3 categories, "More" opens the rest', (tester) async {
      await tester.pumpWidget(
        app(Scaffold(body: CategoriesAndDeal(featured: featured))),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);
      expect(find.text('Stationery'), findsNothing);
      expect(find.text('+2 more'), findsOneWidget);

      await tester.tap(find.text('+2 more'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Stationery'), findsOneWidget);
      expect(find.text('Others'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);
    });

    testWidgets('the advert cycles through real products', (tester) async {
      await tester.pumpWidget(
        app(Scaffold(body: CategoriesAndDeal(featured: featured))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('White Bread Loaf'), findsOneWidget);
      expect(find.textContaining('HOT DEAL'), findsOneWidget);
      expect(find.text('RM 2.70'), findsOneWidget); // Save Food price

      await tester.pump(const Duration(milliseconds: 3300));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Milo Ais (cup)'), findsOneWidget);
      expect(find.textContaining('TOP PICK'), findsOneWidget);
    });

    testWidgets('works in Malay and dark mode', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(body: CategoriesAndDeal(featured: featured)),
          language: 'ms',
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Makanan'), findsOneWidget);
      expect(find.text('+2 lagi'), findsOneWidget);
      expect(find.textContaining('TAWARAN HEBAT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AI Budget Planner screen', () {
    testWidgets('pick any categories and personalise', (tester) async {
      await tester.pumpWidget(app(planner()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('What do you need?'), findsOneWidget);
      expect(find.text('Personalise (optional)'), findsOneWidget);
      for (final c in ['Food', 'Drinks', 'Snacks', 'Stationery', 'Others']) {
        expect(find.widgetWithText(FilterChip, c), findsOneWidget);
      }
      FilterChip chip(String c) =>
          tester.widget<FilterChip>(find.widgetWithText(FilterChip, c));
      expect(chip('Food').selected, isTrue);
      expect(chip('Stationery').selected, isFalse);

      await tester.tap(find.widgetWithText(FilterChip, 'Stationery'));
      await tester.pump();
      expect(chip('Stationery').selected, isTrue);

      // Quick pick "Snack" = drinks + snacks only
      await tester.tap(find.widgetWithText(TextButton, 'Snack'));
      await tester.pump();
      expect(chip('Food').selected, isFalse);
      expect(chip('Drinks').selected, isTrue);
      expect(chip('Stationery').selected, isFalse);
    });

    testWidgets('shows Malay text', (tester) async {
      await tester.pumpWidget(app(planner(), language: 'ms'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Apa yang anda perlukan?'), findsOneWidget);
      expect(find.text('Cadangkan untuk saya'), findsOneWidget);
    });
  });

  testWidgets('360° product picture turns and can be dragged', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Center(
            child: Product360(
              product: item('Milo Ais (cup)', 'Drinks', 300),
              size: 120,
              interactive: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(Product360), const Offset(160, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('🥤'), findsOneWidget); // only the front face
    // Thin layers stacked in depth give it thickness from the side.
    final layers = find.descendant(
      of: find.byType(Product360),
      matching: find.byType(Transform),
    );
    expect(layers.evaluate().length, greaterThanOrEqualTo(6));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3)); // starts turning again
  });

  testWidgets('profile avatar shows initials without a photo', (tester) async {
    expect(initialsOf('Ngu Ming Henn'), 'NM');
    expect(initialsOf('  '), '?');
    await tester.pumpWidget(
      app(const Scaffold(body: UserAvatar(name: 'Test1', photo: null))),
    );
    expect(find.text('T'), findsOneWidget);
  });

  testWidgets('password strength line in dark mode', (tester) async {
    final controller = TextEditingController(text: 'Smart@2026');
    await tester.pumpWidget(
      app(
        Scaffold(body: PasswordStrengthMeter(controller: controller)),
        brightness: Brightness.dark,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Strong'), findsOneWidget);
  });
}
