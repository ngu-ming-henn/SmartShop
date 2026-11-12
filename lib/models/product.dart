import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/utils/firestore_helpers.dart';
import '../core/utils/format.dart';

enum StockStatus { inStock, low, out }

/// A document in `products/{barcode}`.
class Product {
  const Product({
    required this.barcode,
    required this.name,
    required this.category,
    required this.priceSen,
    required this.stock,
    required this.lowStockThreshold,
    this.saveFoodPriceSen,
    this.soldCount = 0,
    this.expiryDate,
    this.imageUrl,
    this.isActive = true,
    this.updatedAt,
  });

  final String barcode; // Firestore document ID
  final String name;
  final String category;
  final int priceSen; // RM18.50 -> 1850
  final int? saveFoodPriceSen; // null = no Save Food deal
  final int stock;
  final int soldCount; // total units sold (AI Budget Planner popularity)
  final int lowStockThreshold;
  final DateTime? expiryDate; // nearest expiry date
  final String? imageUrl;
  final bool isActive;
  final DateTime? updatedAt;

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= lowStockThreshold;
  bool get isOnSaveFood => saveFoodPriceSen != null;

  /// Business rule 7.4: low stock when `stock <= lowStockThreshold`
  /// (includes out of stock).
  bool get needsRestock => stock <= lowStockThreshold;

  /// Without a code from a manufacturer, e.g. "SK-000123".
  bool get hasShortCode => barcode.startsWith(shortCodePrefix);

  int get effectivePriceSen => saveFoodPriceSen ?? priceSen;
  int get saveFoodSavingSen =>
      isOnSaveFood ? (priceSen - saveFoodPriceSen!).clamp(0, priceSen) : 0;

  StockStatus get stockStatus => isOutOfStock
      ? StockStatus.out
      : isLowStock
      ? StockStatus.low
      : StockStatus.inStock;

  int? daysToExpiry({DateTime? now}) =>
      expiryDate == null ? null : daysUntil(expiryDate!, from: now);

  bool isExpired({DateTime? now}) {
    final days = daysToExpiry(now: now);
    return days != null && days < 0;
  }

  /// Business rule 7.4: expiry date within 3 days (and not yet expired).
  bool isNearExpiry({DateTime? now}) {
    final days = daysToExpiry(now: now);
    return days != null && days >= 0 && days <= AppRules.nearExpiryDays;
  }

  /// Shows in the staff "Near expiry" alerts: still has stock and is
  /// near expiry or already expired (needs a write-off).
  bool needsExpiryAction({DateTime? now}) =>
      stock > 0 && (isNearExpiry(now: now) || isExpired(now: now));

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final imageUrl = (d['imageUrl'] as String?)?.trim();
    return Product(
      barcode: doc.id,
      name: d['name'] as String? ?? doc.id,
      category: d['category'] as String? ?? 'Others',
      priceSen: readInt(d['priceSen']),
      saveFoodPriceSen: readIntOrNull(d['saveFoodPriceSen']),
      stock: readInt(d['stock']),
      soldCount: readInt(d['soldCount']),
      lowStockThreshold: readInt(
        d['lowStockThreshold'],
        AppRules.defaultLowStockThreshold,
      ),
      expiryDate: readDate(d['expiryDate']),
      imageUrl: imageUrl == null || imageUrl.isEmpty ? null : imageUrl,
      isActive: d['isActive'] as bool? ?? true,
      updatedAt: readDate(d['updatedAt']),
    );
  }

  /// All fields except `stock` and `soldCount`, which only change through
  /// StockService / OrderService so that every change is logged in
  /// `stock_movements`.
  Map<String, dynamic> toDetailsMap() => {
    'name': name,
    'category': category,
    'priceSen': priceSen,
    'saveFoodPriceSen': saveFoodPriceSen,
    'lowStockThreshold': lowStockThreshold,
    'expiryDate': toTimestamp(expiryDate),
    'imageUrl': imageUrl,
    'isActive': isActive,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toNewMap() => {
    ...toDetailsMap(),
    'stock': stock,
    'soldCount': soldCount,
  };
}
