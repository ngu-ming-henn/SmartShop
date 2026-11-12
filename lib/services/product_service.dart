import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/utils/codes.dart';
import '../core/utils/errors.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import 'sample_data.dart';

class ProductService {
  ProductService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  List<Product> _toSortedList(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map(Product.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Catalogue for students (disabled products are hidden).
  Stream<List<Product>> watchActiveProducts() => _products
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map(_toSortedList);

  /// One-off load of the catalogue (from the phone cache when offline).
  Future<List<Product>> getActiveProducts() async =>
      _toSortedList(await _products.where('isActive', isEqualTo: true).get());

  /// Everything, for staff screens and alerts.
  Stream<List<Product>> watchAllProducts() =>
      _products.snapshots().map(_toSortedList);

  Stream<Product?> watchProduct(String barcode) {
    if (!isValidProductCode(barcode)) return Stream.value(null);
    return _products
        .doc(barcode)
        .snapshots()
        .map((doc) => doc.exists ? Product.fromDoc(doc) : null);
  }

  Future<Product?> findByBarcode(String code) async {
    if (!isValidProductCode(code)) return null;
    final doc = await _products.doc(code).get();
    return doc.exists ? Product.fromDoc(doc) : null;
  }

  /// Creates a product. Opening stock (if any) is logged as a stock-in
  /// movement in the same batch.
  Future<void> createProduct(
    Product product, {
    required String staffId,
    String source = MovementSource.manual,
  }) async {
    if (!isValidProductCode(product.barcode)) {
      throw const AppException(
        'That barcode cannot be used as a product code.',
      );
    }
    final ref = _products.doc(product.barcode);
    if ((await ref.get()).exists) {
      throw AppException('A product with code {code} already exists.', {
        'code': product.barcode,
      });
    }
    final batch = _db.batch()..set(ref, product.toNewMap());
    if (product.stock > 0) {
      batch.set(
        _db.collection('stock_movements').doc(),
        StockMovement.newMap(
          productId: product.barcode,
          productName: product.name,
          type: MovementType.stockIn,
          quantity: product.stock,
          source: source,
          byUserId: staffId,
          expiryDate: product.expiryDate,
          stockAfter: product.stock,
        ),
      );
    }
    await batch.commit();
  }

  /// Updates details only; stock is changed through StockService.
  Future<void> updateProduct(Product product) =>
      _products.doc(product.barcode).update(product.toDetailsMap());

  Future<void> setActive(String barcode, bool active) => _products
      .doc(barcode)
      .update({'isActive': active, 'updatedAt': FieldValue.serverTimestamp()});

  /// Sets (or clears with null) the Save Food price.
  Future<void> setSaveFoodPrice(String barcode, int? priceSen) =>
      _products.doc(barcode).update({
        'saveFoodPriceSen': priceSen,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// A free "SK-000123" code for items without a barcode.
  Future<String> newShortCode() async {
    for (var i = 0; i < 10; i++) {
      final code = generateShortProductCode();
      if (!(await _products.doc(code).get()).exists) return code;
    }
    throw const AppException('Could not generate a free code, try again.');
  }

  /// Adds the demo catalogue (section 14: "create ~50 sample products").
  /// Existing products keep their stock and prices; sample products loaded
  /// before descriptions existed get their description. Returns how many
  /// products were added and how many got a description.
  Future<({int added, int described})> seedSampleProducts(
    String staffId,
  ) async {
    final existing = {
      for (final d in (await _products.get()).docs) d.id: d.data(),
    };
    final batch = _db.batch();
    var added = 0;
    var described = 0;
    for (final p in buildSampleProducts(DateTime.now())) {
      final old = existing[p.barcode];
      if (old != null) {
        // Only fill it in if staff have not renamed or described it.
        final hasText = ((old['description'] as String?) ?? '').trim() != '';
        if (!hasText && old['name'] == p.name && p.description != null) {
          batch.update(_products.doc(p.barcode), {
            'description': p.description,
          });
          described++;
        }
        continue;
      }
      batch.set(_products.doc(p.barcode), p.toNewMap());
      batch.set(
        _db.collection('stock_movements').doc(),
        StockMovement.newMap(
          productId: p.barcode,
          productName: p.name,
          type: MovementType.stockIn,
          quantity: p.stock,
          source: MovementSource.manual,
          byUserId: staffId,
          expiryDate: p.expiryDate,
          stockAfter: p.stock,
        ),
      );
      added++;
    }
    if (added + described > 0) await batch.commit();
    return (added: added, described: described);
  }
}
