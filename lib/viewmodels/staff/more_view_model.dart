import '../../services/product_service.dart';
import '../../services/sample_data.dart';
import '../view_model.dart';

/// Staff "More" tab: loading the demo catalogue. (Profile, language and
/// log out use the app-wide AuthViewModel / SettingsViewModel.)
class MoreViewModel extends ViewModel {
  MoreViewModel(this._products, this._staffId);

  final ProductService _products;
  final String _staffId;

  int get sampleProductCount => buildSampleProducts(DateTime.now()).length;

  /// Adds the sample products that are missing and fills in missing
  /// descriptions. Existing stock and prices are kept.
  Future<({int added, int described})> loadSampleProducts() =>
      run(() => _products.seedSampleProducts(_staffId));
}
