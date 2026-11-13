import 'product.dart';

// The AI Budget Planner's data: a suggested combo, the meal quick picks
// and the wishes a student types ("chocolate, no spicy").

/// A suggested set of items within the budget.
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
