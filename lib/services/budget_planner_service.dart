import 'dart:math';

// cloud_firestore has its own `Order` (index definitions); ours is the model.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../core/constants.dart';
import '../models/order.dart';
import '../models/product.dart';

class Combo {
  final List<Product> items;
  final double score;
  const Combo(this.items, this.score);

  int get totalSen => items.fold(0, (total, p) => total + p.effectivePriceSen);
}

/// Quick picks that choose the categories for a meal.
enum MealType {
  breakfast('Breakfast', ['Food', 'Drinks']),
  lunch('Lunch', ['Food', 'Drinks', 'Snacks']),
  snack('Snack', ['Drinks', 'Snacks']);

  const MealType(this.label, this.slots);
  final String label;
  final List<String> slots;
}

/// What the student typed to personalise the plan, e.g.
/// "chocolate, milo, no spicy" or "tak nak pedas, nak coklat".
/// Liked words lift matching items; "no / without / tak / tanpa" words
/// remove them.
class Wishes {
  const Wishes({this.prefer = const [], this.avoid = const []});

  final List<String> prefer;
  final List<String> avoid;

  static const none = Wishes();

  bool get isEmpty => prefer.isEmpty && avoid.isEmpty;

  static const _negators = {
    'no', 'not', 'without', 'avoid', 'dont', 'tanpa', 'tak', 'tidak',
    'bukan', 'jangan', 'x', //
  };
  static const _fillers = {
    'i', 'a', 'an', 'the', 'and', 'or', 'with', 'some', 'something', 'want',
    'need', 'like', 'feel', 'please', 'for', 'to', 'me', 'any', 'eat',
    'drink', 'nak', 'mahu', 'mau', 'saya', 'yang', 'dan', 'atau', 'perlu',
    'makan', 'minum', 'sikit', 'ada', //
  };

  /// Words that stand for several products (English and Malay).
  static const _synonyms = <String, List<String>>{
    'sweet': ['chocolate', 'muffin', 'kaya', 'oreo', 'milo', 'biscuit'],
    'manis': ['chocolate', 'muffin', 'kaya', 'oreo', 'milo', 'biscuit'],
    'spicy': ['curry', 'kari', 'sambal', 'nasi lemak', 'maggi', 'mi goreng'],
    'pedas': ['curry', 'kari', 'sambal', 'nasi lemak', 'maggi', 'mi goreng'],
    'coffee': ['coffee', 'nescafe', 'kopi'],
    'kopi': ['coffee', 'nescafe', 'kopi'],
    'tea': ['teh', 'tea'],
    'teh': ['teh', 'tea'],
    'noodle': ['noodle', 'mee', 'mi goreng', 'maggi', 'indomie'],
    'noodles': ['noodle', 'mee', 'mi goreng', 'maggi', 'indomie'],
    'mee': ['noodle', 'mee', 'mi goreng', 'maggi', 'indomie'],
    'bread': ['bread', 'roti', 'bun'],
    'roti': ['bread', 'roti', 'bun'],
    'rice': ['nasi'],
    'nasi': ['nasi'],
    'water': ['water'],
    'air': ['water'],
    'milk': ['milk'],
    'susu': ['milk'],
    'chocolate': ['chocolate', 'milo', 'oreo'],
    'coklat': ['chocolate', 'milo', 'oreo'],
    'cold': ['ais', 'cola', '100plus', 'water', 'can'],
    'sejuk': ['ais', 'cola', '100plus', 'water', 'can'],
    'healthy': ['water', 'yogurt', 'milk', 'sandwich'],
    'sihat': ['water', 'yogurt', 'milk', 'sandwich'],
  };

  factory Wishes.parse(String text) {
    final words = text
        .toLowerCase()
        .replaceAll("'", '')
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty);
    final prefer = <String>[];
    final avoid = <String>[];
    var negate = false;
    for (final w in words) {
      if (_negators.contains(w)) {
        negate = true;
      } else if (_fillers.contains(w) || w.length < 3) {
        continue;
      } else {
        (negate ? avoid : prefer).add(w);
        negate = false;
      }
    }
    return Wishes(prefer: prefer, avoid: avoid);
  }

  bool likes(Product p) => _matches(p, prefer);
  bool avoids(Product p) => _matches(p, avoid);

  static bool _matches(Product p, List<String> words) {
    final name = p.name.toLowerCase();
    return words.any((w) => (_synonyms[w] ?? [w]).any(name.contains));
  }
}

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
