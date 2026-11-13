import '../../models/product.dart';
import '../../services/product_service.dart';
import '../view_model.dart';

/// QR label for one product without a barcode (live name and price).
class QrLabelViewModel extends ViewModel {
  QrLabelViewModel(ProductService products, String code) {
    follow(products.watchProduct(code), (p) {
      product = p;
      _loaded = true;
    });
  }

  bool _loaded = false;
  Product? product;

  bool get loading => !_loaded && error == null;
}
