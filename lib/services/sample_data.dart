import '../core/utils/codes.dart';
import '../models/product.dart';

/// Demo catalogue for testing and the presentation. `sold` is a starting
/// popularity so "Popular now" and the AI Budget Planner have data to use.
///
/// Barcodes use the GS1 "200" prefix, which is reserved for in-store use,
/// so they never clash with real products. Scan a real item and add it from
/// the Products screen to use real barcodes.
List<Product> buildSampleProducts(DateTime now) {
  DateTime inDays(int d) => DateTime(now.year, now.month, now.day + d);
  var n = 0;
  String code() => ean13('200000${(++n).toString().padLeft(6, '0')}');

  Product p(
    String name,
    String category,
    int priceSen,
    int stock, {
    int threshold = 5,
    int? expiresInDays,
    String? barcode,
    int sold = 0,
  }) => Product(
    barcode: barcode ?? code(),
    name: name,
    category: category,
    priceSen: priceSen,
    stock: stock,
    soldCount: sold,
    lowStockThreshold: threshold,
    expiryDate: expiresInDays == null ? null : inDays(expiresInDays),
  );

  return [
    // Drinks
    p('Milo Can 400g', 'Drinks', 1850, 25, expiresInDays: 300, sold: 40),
    p(
      'Mineral Water 500ml',
      'Drinks',
      120,
      60,
      threshold: 12,
      expiresInDays: 365,
      sold: 320,
    ),
    p(
      '100Plus Isotonic 500ml',
      'Drinks',
      280,
      30,
      threshold: 8,
      expiresInDays: 200,
      sold: 150,
    ),
    p('Teh Tarik 3-in-1 (10 sachets)', 'Drinks', 1290, 12, expiresInDays: 240),
    p('Fresh Milk 1L', 'Drinks', 790, 8, expiresInDays: 3, sold: 60),
    p(
      'Milo Ais (cup)',
      'Drinks',
      300,
      20,
      threshold: 6,
      expiresInDays: 0,
      barcode: 'SK-000004',
      sold: 410,
    ),
    // Food (short shelf life: good for Save Food)
    p('White Bread Loaf', 'Food', 390, 10, expiresInDays: 2, sold: 90),
    p(
      'Kuih Lapis',
      'Food',
      100,
      20,
      threshold: 6,
      expiresInDays: 1,
      barcode: 'SK-000001',
      sold: 260,
    ),
    p(
      'Curry Puff',
      'Food',
      120,
      15,
      threshold: 6,
      expiresInDays: 1,
      barcode: 'SK-000002',
      sold: 300,
    ),
    p('Nasi Lemak Bungkus', 'Food', 350, 12, expiresInDays: 0, sold: 450),
    p('Tuna Sandwich', 'Food', 450, 8, expiresInDays: 2, sold: 120),
    p('Strawberry Yogurt Cup', 'Food', 250, 9, expiresInDays: 3, sold: 70),
    // Snacks
    p(
      'Instant Noodle Snack',
      'Snacks',
      100,
      40,
      threshold: 10,
      expiresInDays: 150,
      sold: 200,
    ),
    p('Potato Chips 60g', 'Snacks', 220, 18, expiresInDays: 120, sold: 180),
    p('Chocolate Bar', 'Snacks', 350, 4, expiresInDays: 180, sold: 110),
    p('Cream Crackers', 'Snacks', 420, 14, expiresInDays: 210, sold: 50),
    p('Chocolate Muffin', 'Snacks', 250, 6, expiresInDays: 1, sold: 80),
    // Stationery (no expiry)
    p('A4 Paper 80gsm (500 sheets)', 'Stationery', 1290, 10, threshold: 3),
    p('Blue Ballpoint Pen', 'Stationery', 150, 50, threshold: 10),
    p('Exam Pad', 'Stationery', 300, 3),
    p('Highlighter', 'Stationery', 250, 20),
    p('Correction Tape', 'Stationery', 380, 0),
    p('A5 Notebook', 'Stationery', 450, 15),
    p(
      'Pencil (loose)',
      'Stationery',
      50,
      40,
      threshold: 10,
      barcode: 'SK-000003',
    ),
    // Others (daily items)
    p('Pocket Tissue', 'Others', 150, 30, threshold: 8),
    p('Hand Sanitizer 50ml', 'Others', 590, 7, expiresInDays: 500),
    p('Face Mask (10 pcs)', 'Others', 890, 6),
    p('Foldable Umbrella', 'Others', 1500, 2, threshold: 2),
    // More items (added at the end so the codes above stay the same)
    p('Gardenia Classic Bread', 'Food', 450, 12, expiresInDays: 4, sold: 230),
    p(
      'Roti Kaya (bun)',
      'Food',
      180,
      15,
      threshold: 5,
      expiresInDays: 1,
      barcode: 'SK-000005',
      sold: 210,
    ),
    p(
      'Maggi Curry Cup Noodles',
      'Food',
      280,
      30,
      expiresInDays: 200,
      sold: 380,
    ),
    p('Indomie Mi Goreng', 'Food', 130, 45, threshold: 10, sold: 350),
    p('Chicken Curry Puff', 'Food', 150, 0, expiresInDays: 1, sold: 190),
    p(
      'Teh Ais (cup)',
      'Drinks',
      250,
      20,
      threshold: 6,
      expiresInDays: 0,
      barcode: 'SK-000006',
      sold: 300,
    ),
    p('Coca-Cola Can 320ml', 'Drinks', 250, 36, expiresInDays: 270, sold: 260),
    p('Chocolate Milk 200ml', 'Drinks', 220, 18, expiresInDays: 10, sold: 140),
    p(
      'Nescafe Latte Can 240ml',
      'Drinks',
      330,
      3,
      expiresInDays: 180,
      sold: 95,
    ),
    p('Twisties Cheese 60g', 'Snacks', 220, 25, expiresInDays: 150, sold: 170),
    p('Oreo Original 133g', 'Snacks', 450, 14, expiresInDays: 240, sold: 120),
    p('Peanut Butter Biscuits', 'Snacks', 380, 10, expiresInDays: 200),
    p('Sticky Notes (3 pads)', 'Stationery', 350, 20),
    p('Scientific Calculator', 'Stationery', 4590, 4, threshold: 2, sold: 25),
    p('Scented Candle (Vanilla)', 'Others', 890, 8, threshold: 3, sold: 30),
    p('Tealight Candles (10 pcs)', 'Others', 590, 12, sold: 45),
    p('AA Batteries (4 pcs)', 'Others', 1190, 9, sold: 40),
    p('Toothpaste 100g', 'Others', 650, 11, expiresInDays: 600),
  ];
}
