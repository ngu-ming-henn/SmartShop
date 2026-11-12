import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/theme.dart';
import 'package:smartshop/models/product.dart';
import 'package:smartshop/widgets/product_widgets.dart';

Product product({int stock = 25, int? saveFoodPriceSen}) => Product(
  barcode: '2000000000017',
  name: 'Kuih Lapis',
  category: 'Food',
  priceSen: 150,
  saveFoodPriceSen: saveFoodPriceSen,
  stock: stock,
  lowStockThreshold: 5,
);

Widget wrap(Widget child) => MaterialApp(
  theme: buildAppTheme(useGoogleFonts: false),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('stock badge shows clear stock status', (tester) async {
    await tester.pumpWidget(wrap(StockBadge(product: product(stock: 25))));
    expect(find.text('In stock (25)'), findsOneWidget);

    await tester.pumpWidget(wrap(StockBadge(product: product(stock: 3))));
    expect(find.text('Low stock (3)'), findsOneWidget);

    await tester.pumpWidget(wrap(StockBadge(product: product(stock: 0))));
    expect(find.text('Out of stock'), findsOneWidget);
  });

  testWidgets('product tile shows Save Food price and badge', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ProductTile(
          product: product(saveFoodPriceSen: 100),
          onTap: () => tapped = true,
        ),
      ),
    );
    expect(find.text('Kuih Lapis'), findsOneWidget);
    expect(find.text('RM 1.00'), findsOneWidget); // deal price
    expect(find.text('RM 1.50'), findsOneWidget); // struck-through normal price
    expect(find.text('SAVE FOOD'), findsOneWidget);
    await tester.tap(find.text('Kuih Lapis'));
    expect(tapped, isTrue);
  });

  testWidgets('quantity stepper respects min and max', (tester) async {
    var value = 1;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => QtyStepper(
            value: value,
            max: 2,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(value, 2);
    await tester.tap(find.byTooltip('More')); // disabled at max
    await tester.pump();
    expect(value, 2);
  });
}
