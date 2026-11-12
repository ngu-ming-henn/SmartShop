import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/constants.dart';
import 'package:smartshop/core/utils/codes.dart';
import 'package:smartshop/core/utils/format.dart';
import 'package:smartshop/core/utils/points.dart';
import 'package:smartshop/models/order.dart';
import 'package:smartshop/models/product.dart';
import 'package:smartshop/providers/cart_provider.dart';
import 'package:smartshop/services/order_service.dart';
import 'package:smartshop/services/sample_data.dart';

Product product({
  String barcode = '2000000000017',
  int priceSen = 1850,
  int? saveFoodPriceSen,
  int stock = 25,
  int threshold = 5,
  DateTime? expiryDate,
}) => Product(
  barcode: barcode,
  name: 'Milo Can 400g',
  category: 'Drinks',
  priceSen: priceSen,
  saveFoodPriceSen: saveFoodPriceSen,
  stock: stock,
  lowStockThreshold: threshold,
  expiryDate: expiryDate,
);

void main() {
  group('money in sen', () {
    test('formats RM', () {
      expect(formatRM(1850), 'RM 18.50');
      expect(formatRM(5), 'RM 0.05');
      expect(formatRM(123456), 'RM 1,234.56');
    });
    test('parses input without rounding errors', () {
      expect(parseRMToSen('18.50'), 1850);
      expect(parseRMToSen('18.5'), 1850);
      expect(parseRMToSen('RM 0.10'), 10);
      expect(parseRMToSen('2'), 200);
      expect(parseRMToSen('1,200.00'), 120000);
      expect(parseRMToSen('abc'), isNull);
      expect(parseRMToSen('1.234'), isNull);
    });
  });

  group('stock status (rule: stock <= lowStockThreshold)', () {
    test('in stock / low / out', () {
      expect(product(stock: 25).stockStatus, StockStatus.inStock);
      expect(product(stock: 5).stockStatus, StockStatus.low); // TC09
      expect(product(stock: 0).stockStatus, StockStatus.out);
      expect(product(stock: 0).needsRestock, isTrue);
      expect(product(stock: 6).needsRestock, isFalse);
    });
  });

  group('expiry (rule: within 3 days)', () {
    final now = DateTime(2026, 11, 9, 15, 30);
    test('near expiry within 3 days, including today', () {
      expect(
        product(expiryDate: DateTime(2026, 11, 9)).isNearExpiry(now: now),
        isTrue,
      );
      expect(
        product(expiryDate: DateTime(2026, 11, 12)).isNearExpiry(now: now),
        isTrue,
      ); // TC10
      expect(
        product(expiryDate: DateTime(2026, 11, 13)).isNearExpiry(now: now),
        isFalse,
      );
    });
    test('expired items need a write-off, not a deal', () {
      final p = product(expiryDate: DateTime(2026, 11, 8));
      expect(p.isExpired(now: now), isTrue);
      expect(p.isNearExpiry(now: now), isFalse);
      expect(p.needsExpiryAction(now: now), isTrue);
    });
    test('no stock means no expiry alert', () {
      expect(
        product(
          stock: 0,
          expiryDate: DateTime(2026, 11, 10),
        ).needsExpiryAction(now: now),
        isFalse,
      );
    });
    test('labels', () {
      expect(expiryLabel(DateTime(2026, 11, 9), from: now), 'Expires today');
      expect(
        expiryLabel(DateTime(2026, 11, 12), from: now),
        'Expires in 3 days',
      );
      expect(
        expiryLabel(DateTime(2026, 11, 7), from: now),
        'Expired 2 days ago',
      );
    });
  });

  group('Save Food', () {
    test('effective price and saving', () {
      final p = product(priceSen: 1850, saveFoodPriceSen: 1200);
      expect(p.isOnSaveFood, isTrue);
      expect(p.effectivePriceSen, 1200);
      expect(p.saveFoodSavingSen, 650);
      expect(product().effectivePriceSen, 1850);
    });
    test('suggested price is 30% off, rounded down to 10 sen', () {
      expect(suggestedSaveFoodPriceSen(390), 270);
      expect(suggestedSaveFoodPriceSen(1850), 1290);
    });
  });

  group('green points (+5 no bag, +10 per Save Food item)', () {
    test('order with no plastic bag earns 5 (TC11)', () {
      expect(calculateGreenPoints(noPlasticBag: true, saveFoodItemCount: 0), 5);
    });
    test('Save Food items add 10 each', () {
      expect(
        calculateGreenPoints(noPlasticBag: false, saveFoodItemCount: 2),
        20,
      );
      expect(
        calculateGreenPoints(noPlasticBag: true, saveFoodItemCount: 3),
        35,
      );
    });
    test('voucher value: 100 points = RM1', () {
      expect(voucherValueSen(250), 200);
      expect(voucherValueSen(99), 0);
    });
    test('counts Save Food quantities in order items', () {
      const items = [
        OrderItem(
          productId: 'a',
          name: 'Bread',
          unitPriceSen: 200,
          qty: 2,
          isSaveFood: true,
        ),
        OrderItem(
          productId: 'b',
          name: 'Pen',
          unitPriceSen: 150,
          qty: 3,
          isSaveFood: false,
        ),
      ];
      expect(saveFoodCountOf(items), 2);
      expect(totalOf(items), 850);
    });
  });

  group('cart', () {
    test('never holds more than the stock shown (TC06 guard)', () {
      final cart = CartProvider();
      final p = product(stock: 2);
      expect(cart.add(p, qty: 3), isTrue);
      expect(cart.qtyOf(p.barcode), 2);
      expect(cart.add(p), isFalse);
    });
    test('totals, savings and points preview', () {
      final cart = CartProvider()
        ..add(
          product(barcode: 'bread', priceSen: 390, saveFoodPriceSen: 270),
          qty: 2,
        )
        ..add(product(barcode: 'pen', priceSen: 150), qty: 1);
      expect(cart.itemCount, 3);
      expect(cart.totalSen, 690);
      expect(cart.saveFoodSavingsSen, 240);
      expect(cart.pointsPreview, 25); // no bag (default on) + 2 Save Food items
      cart.setNoPlasticBag(false);
      expect(cart.pointsPreview, 20);
    });
    test('quantity 0 removes the line', () {
      final cart = CartProvider()..add(product());
      cart.setQty(product().barcode, 0);
      expect(cart.isEmpty, isTrue);
    });
  });

  group('codes', () {
    test('pickup codes are 6 unambiguous characters', () {
      for (var i = 0; i < 50; i++) {
        expect(generatePickupCode(), matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
      }
    });
    test('short codes for items without a barcode', () {
      expect(generateShortProductCode(), matches(RegExp(r'^SK-\d{6}$')));
    });
    test('EAN-13 check digit', () {
      expect(ean13('400638133393'), '4006381333931');
    });
    test('codes that cannot be Firestore document IDs are rejected', () {
      expect(isValidProductCode('9556001234567'), isTrue);
      expect(isValidProductCode('https://example.com/x'), isFalse);
      expect(isValidProductCode(''), isFalse);
    });
    test('sample barcodes are unique and valid', () {
      final codes = buildSampleProducts(DateTime(2026, 11, 9))
          .map((p) => p.barcode)
          .toList();
      expect(codes.toSet().length, codes.length);
      expect(codes.every(isValidProductCode), isTrue);
    });
    test('sample products only use the 5 categories', () {
      final categories = buildSampleProducts(DateTime(2026, 11, 9))
          .map((p) => p.category)
          .toSet();
      expect(productCategories, containsAll(categories));
    });
  });

  group('pickup window (rule: same day before closing)', () {
    Order order(String status, {DateTime? readyAt, String? cancelReason}) =>
        Order(
          id: 'A7K2Q9XX',
          type: OrderType.preorder,
          userId: 'student',
          customerName: 'Ahmad',
          items: const [],
          totalSen: 700,
          status: status,
          noPlasticBag: true,
          pickupCode: 'A7K2Q9',
          pointsEarned: 5,
          readyAt: readyAt,
          cancelReason: cancelReason,
        );
    final readyAt = DateTime(2026, 11, 9, 10, 15);
    final closing = DateTime(2026, 11, 9, AppRules.closingHour);

    test('can be collected until closing time', () {
      final o = order(OrderStatus.ready, readyAt: readyAt);
      expect(o.pickupDeadline, closing);
      expect(
        o.isUncollected(now: closing.subtract(const Duration(minutes: 1))),
        isFalse,
      );
    });
    test('uncollected after closing and on later days (TC18)', () {
      final o = order(OrderStatus.ready, readyAt: readyAt);
      expect(o.isUncollected(now: closing), isTrue);
      expect(o.isUncollected(now: DateTime(2026, 11, 10, 9)), isTrue);
    });
    test('packed after closing: collect the next day', () {
      final o = order(
        OrderStatus.ready,
        readyAt: DateTime(2026, 11, 9, AppRules.closingHour, 30),
      );
      expect(o.pickupDeadline, DateTime(2026, 11, 10, AppRules.closingHour));
      expect(o.isUncollected(now: DateTime(2026, 11, 9, 23)), isFalse);
    });
    test('only READY orders can be uncollected', () {
      final later = DateTime(2026, 11, 12);
      for (final status in [
        OrderStatus.pending,
        OrderStatus.collected,
        OrderStatus.cancelled,
      ]) {
        expect(
          order(status, readyAt: readyAt).isUncollected(now: later),
          isFalse,
        );
      }
    });
    test('scanning a cancelled order says not ready for pickup (TC19)', () {
      final o = order(
        OrderStatus.cancelled,
        readyAt: readyAt,
        cancelReason: CancelReason.notCollected,
      );
      expect(o.wasNotCollected, isTrue);
      expect(OrderService.notReadyMessage(o), contains('not ready for pickup'));
    });
  });
}
