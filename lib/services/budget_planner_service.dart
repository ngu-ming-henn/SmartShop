import 'dart:math';

// cloud_firestore has its own `Order` (index definitions); ours is the model.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../core/constants.dart';
import '../models/budget_plan.dart';
import '../models/order.dart';
import '../models/product.dart';

export '../models/budget_plan.dart';

/// ✨ AI Budget Planner (design doc 8.1): a recommender (scores each product
/// from the student's history, popularity, Save Food deals and what they
/// typed) plus an optimization search for the best combos within the
/// budget. Runs on the phone, no paid AI service.
class BudgetPlannerService {
  /// [db] is only used by [myPurchaseCounts], so [suggest] can be unit
  /// tested without Firebase.
  BudgetPlannerService({this.db});

  final FirebaseFirestore? db;

  /// Food + drink + snack, the guide's default meal.
  static const defaultSlots = ['Food', 'Drinks', 'Snacks'];

  /// The student may pick any category (at most 1 item from each).
  static const allSlots = productCategories;
  static const candidatesPerSlot = 8;

  /// How many of each product this student has collected before.
  Future<Map<String, int>> myPurchaseCounts(String uid) async {
    final snap = await (db ?? FirebaseFirestore.instance)
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: OrderStatus.collected)
        .get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      for (final item in Order.fromDoc(doc).items) {
        counts[item.productId] = (counts[item.productId] ?? 0) + item.qty;
      }
    }
    return counts;
  }

  /// [products]: active products loaded from Firestore.
  /// [myCounts]: result of [myPurchaseCounts] (empty for new users).
  /// [slots]: the categories to use, e.g. [MealType.slots].
  /// [wishes]: what the student typed (liked items score higher, avoided
  /// items are left out).
  List<Combo> suggest({
    required int budgetSen,
    required List<Product> products,
    Map<String, int> myCounts = const {},
    List<String> slots = defaultSlots,
    Wishes wishes = Wishes.none,
    int howMany = 3,
  }) {
    double scoreOf(Product p) =>
        1 +
        3 * log(1 + (myCounts[p.barcode] ?? 0)) +
        log(1 + p.soldCount) +
        (p.isOnSaveFood ? 2 : 0) +
        // What the student typed outweighs popularity and history.
        (wishes.likes(p) ? 10 : 0);

    // 1. Best affordable, in-stock candidates for each slot (null = skip
    //    slot). Fewer per slot when many categories are picked.
    final perSlot = slots.length > 3 ? 6 : candidatesPerSlot;
    final bySlot = <List<Product?>>[
      for (final slot in slots)
        [
          null,
          ...(products
                  .where(
                    (p) =>
                        p.category == slot &&
                        p.stock > 0 &&
                        p.effectivePriceSen <= budgetSen &&
                        !wishes.avoids(p),
                  )
                  .toList()
                ..sort((a, b) => scoreOf(b).compareTo(scoreOf(a))))
              .take(perSlot),
        ],
    ];

    // 2. Try every combination (at most 1 item per category), dropping
    //    partial combos as soon as they go over budget.
    var partial = <(List<Product>, int)>[(const [], 0)];
    for (final options in bySlot) {
      partial = [
        for (final (items, total) in partial)
          for (final p in options)
            if (p == null)
              (items, total)
            else if (total + p.effectivePriceSen <= budgetSen)
              ([...items, p], total + p.effectivePriceSen),
      ];
    }
    final combos = [
      for (final (items, _) in partial)
        if (items.isNotEmpty)
          Combo(items, items.map(scoreOf).reduce((a, b) => a + b)),
    ];

    // 3. Highest score first; if equal, cheaper first
    combos.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.totalSen.compareTo(b.totalSen);
    });

    // 4. Top combos, each starting with a different item (variety)
    final result = <Combo>[];
    final usedFirstItems = <String>{};
    for (final combo in combos) {
      if (result.length == howMany) break;
      if (usedFirstItems.add(combo.items.first.barcode)) result.add(combo);
    }
    return result;
  }
}
