import '../../core/constants.dart';
import '../../services/budget_planner_service.dart';
import '../../services/product_service.dart';
import '../cart_view_model.dart';
import '../view_model.dart';

/// ✨ AI Budget Planner: the categories the student needs, their wishes,
/// and the 3 suggested combos; a combo goes into the cart.
class BudgetPlannerViewModel extends ViewModel {
  BudgetPlannerViewModel(this._planner, this._products, this._cart, this._uid);

  final BudgetPlannerService _planner;
  final ProductService _products;
  final CartViewModel _cart;
  final String _uid;

  final Set<String> _categories = {...BudgetPlannerService.defaultSlots};

  /// Null until the student asks for suggestions.
  List<Combo>? combos;

  /// The wishes the shown combos were made for (hearts on liked items).
  Wishes usedWishes = Wishes.none;

  bool isPicked(String category) => _categories.contains(category);
  bool get hasCategories => _categories.isNotEmpty;

  void pick(String category, bool on) {
    on ? _categories.add(category) : _categories.remove(category);
    notify();
  }

  /// Quick pick: Breakfast, Lunch or Snack choose the categories.
  void pickMeal(MealType meal) {
    _categories
      ..clear()
      ..addAll(meal.slots);
    notify();
  }

  /// Builds the combos from what is in stock now, the student's own past
  /// purchases and popular items.
  Future<void> suggest({required int budgetSen, required String wishes}) =>
      run(() async {
        final parsed = Wishes.parse(wishes);
        final products = await _products.getActiveProducts();
        final myCounts = await _planner.myPurchaseCounts(_uid);
        usedWishes = parsed;
        combos = _planner.suggest(
          budgetSen: budgetSen,
          products: products,
          myCounts: myCounts,
          // Keep the category order of the app (Food, Drinks, ...).
          slots: [
            for (final c in productCategories)
              if (_categories.contains(c)) c,
          ],
          wishes: parsed,
        );
      });

  bool get cartHasItems => !_cart.isEmpty;

  /// Puts the combo in the cart (after emptying it when [replaceCart]).
  void addToCart(Combo combo, {required bool replaceCart}) {
    if (replaceCart) _cart.clear();
    for (final p in combo.items) {
      _cart.add(p);
    }
  }
}
