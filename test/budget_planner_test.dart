import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/models/product.dart';
import 'package:smartshop/services/budget_planner_service.dart';

Product item(
  String id,
  String category,
  int priceSen, {
  int stock = 10,
  int? saveFoodPriceSen,
  int soldCount = 0,
}) => Product(
  barcode: id,
  name: id,
  category: category,
  priceSen: priceSen,
  stock: stock,
  lowStockThreshold: 5,
  saveFoodPriceSen: saveFoodPriceSen,
  soldCount: soldCount,
);

void main() {
  final planner = BudgetPlannerService();

  // Tests from the design document (section 8.1.5)
  test('stays within budget and skips out-of-stock items', () {
    final combos = planner.suggest(
      budgetSen: 1000,
      products: [
        item('nasi', 'Food', 400),
        item('milo', 'Drinks', 300),
        item('kuih', 'Snacks', 150),
        item('mee', 'Food', 500, stock: 0),
      ],
    );
    expect(combos, isNotEmpty);
    for (final c in combos) {
      expect(c.totalSen, lessThanOrEqualTo(1000));
      expect(c.items.map((p) => p.barcode), isNot(contains('mee')));
    }
    // Best suggestion is a full meal: food + drink + snack = RM8.50
    expect(combos.first.items.length, 3);
    expect(combos.first.totalSen, 850);
  });

  test('prefers a Save Food item', () {
    final combos = planner.suggest(
      budgetSen: 150,
      products: [
        item('bun', 'Food', 150),
        item('roti', 'Food', 300, saveFoodPriceSen: 150),
      ],
    );
    expect(combos.first.items.single.barcode, 'roti');
  });

  test("prefers the student's favourite", () {
    final combos = planner.suggest(
      budgetSen: 400,
      products: [item('nasi', 'Food', 400), item('mee', 'Food', 400)],
      myCounts: {'mee': 5},
    );
    expect(combos.first.items.single.barcode, 'mee');
  });

  test('returns nothing when the budget is too small', () {
    final combos = planner.suggest(
      budgetSen: 100,
      products: [item('nasi', 'Food', 400)],
    );
    expect(combos, isEmpty);
  });

  // Extra checks for the app
  test('popular items win for new users', () {
    final combos = planner.suggest(
      budgetSen: 400,
      products: [
        item('nasi', 'Food', 400),
        item('mee', 'Food', 400, soldCount: 300),
      ],
    );
    expect(combos.first.items.single.barcode, 'mee');
  });

  test('at most 3 combos, each starting with a different item', () {
    final combos = planner.suggest(
      budgetSen: 2000,
      products: [
        for (var i = 0; i < 5; i++) item('food$i', 'Food', 300),
        item('milo', 'Drinks', 300),
        item('kuih', 'Snacks', 150),
      ],
    );
    expect(combos.length, 3);
    expect(combos.map((c) => c.items.first.barcode).toSet().length, 3);
  });

  test('ignores Stationery and Others', () {
    final combos = planner.suggest(
      budgetSen: 1000,
      products: [item('pen', 'Stationery', 150), item('tissue', 'Others', 150)],
    );
    expect(combos, isEmpty);
  });

  test('works for any category, e.g. stationery for class', () {
    final combos = planner.suggest(
      budgetSen: 500,
      slots: ['Stationery', 'Others'],
      products: [
        item('pen', 'Stationery', 150),
        item('tissue', 'Others', 150),
        item('nasi', 'Food', 300),
      ],
    );
    expect(combos.first.items.map((p) => p.barcode), ['pen', 'tissue']);
  });

  test('what the student likes goes first', () {
    final combos = planner.suggest(
      budgetSen: 400,
      products: [
        item('Nasi Lemak', 'Food', 400, soldCount: 500),
        item('Maggi Curry Cup', 'Food', 280),
      ],
      wishes: Wishes.parse('I want noodles please'),
    );
    expect(combos.first.items.single.name, 'Maggi Curry Cup');
  });

  test('"no ..." leaves things out, in English or Malay', () {
    final products = [
      item('Curry Puff', 'Food', 150),
      item('Roti Kaya', 'Food', 180),
    ];
    for (final text in ['no spicy', 'tak nak pedas']) {
      final combos = planner.suggest(
        budgetSen: 1000,
        products: products,
        wishes: Wishes.parse(text),
      );
      for (final c in combos) {
        expect(c.items.map((p) => p.name), isNot(contains('Curry Puff')));
      }
    }
  });

  test('reads likes and dislikes from free text', () {
    final w = Wishes.parse('Tak nak pedas, nak coklat dan milo');
    expect(w.avoid, ['pedas']);
    expect(w.prefer, ['coklat', 'milo']);
    expect(Wishes.parse('').isEmpty, isTrue);
  });

  test('meal type picks the categories (Snack = drink + snack, no food)', () {
    final combos = planner.suggest(
      budgetSen: 1000,
      slots: MealType.snack.slots,
      products: [
        item('nasi', 'Food', 400),
        item('milo', 'Drinks', 300),
        item('kuih', 'Snacks', 150),
      ],
    );
    expect(combos.first.items.map((p) => p.barcode), ['milo', 'kuih']);
    for (final c in combos) {
      expect(c.items.map((p) => p.category), isNot(contains('Food')));
    }
  });
}
