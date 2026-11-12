/// Business rules from the design document (section 7.4).
/// Agree the final values with the koperasi before release.
class AppRules {
  AppRules._();

  /// A product is "near expiry" when it expires within this many days.
  static const nearExpiryDays = 3;

  /// Default for new products: low stock when `stock <= lowStockThreshold`.
  static const defaultLowStockThreshold = 5;

  /// Green points for an order collected without a plastic bag.
  static const pointsNoPlasticBag = 5;

  /// Green points for every Save Food unit bought.
  static const pointsPerSaveFoodItem = 10;

  /// Redemption: this many points = RM1 voucher.
  static const pointsPerRinggitVoucher = 100;

  /// Estimated shopping time saved by one pre-order (sustainability report).
  static const minutesSavedPerPreorder = 5;

  /// Suggested Save Food discount shown to staff (30% off).
  static const suggestedSaveFoodDiscount = 0.30;

  /// Pickup window: a READY order must be collected the same day before
  /// the koperasi closes at this hour (24h clock).
  static const closingHour = 18;

  /// Opening time shown on the map screen (agree with the koperasi).
  static const openingHour = 8;
}

/// Where the koperasi is: the "UCTS COOP SHOP" under the stairs at the
/// Academic Resources Centre (position from Google Street View). Google Maps
/// has no pin for it yet, so the app shows its own.
class ShopLocation {
  ShopLocation._();
  static const latitude = 2.341336;
  static const longitude = 111.846039;
  static const name = 'UTS Koperasi (UCTS Coop Shop)';
  static const address =
      'Academic Resources Centre, University of Technology Sarawak, Sibu';

  /// Google Maps directions to the pin (works even without a listing).
  static const directionsUrl =
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

  /// Street View facing the shop entrance.
  static const streetViewUrl =
      'https://www.google.com/maps/@?api=1&map_action=pano'
      '&viewpoint=$latitude,$longitude&heading=290';

  static bool isOpen(DateTime now) =>
      now.hour >= AppRules.openingHour && now.hour < AppRules.closingHour;
}

/// Product categories shown as chips on the student home screen.
/// The AI Budget Planner builds combos from the first three.
const productCategories = <String>[
  'Food',
  'Drinks',
  'Snacks',
  'Stationery',
  'Others',
];

/// Prefix of the member QR code shown on the student profile.
/// Staff scan it at the counter to link a sale to the student.
const memberQrPrefix = 'SKUSER:';

/// Prefix for products without a manufacturer barcode (printed as QR labels).
const shortCodePrefix = 'SK-';

class UserRoles {
  UserRoles._();
  static const student = 'student';
  static const staff = 'staff';
}

class OrderStatus {
  OrderStatus._();
  static const pending = 'pending';
  static const ready = 'ready';
  static const collected = 'collected';
  static const cancelled = 'cancelled';
}

class OrderType {
  OrderType._();
  static const preorder = 'preorder';
  static const counter = 'counter';
}

class CancelReason {
  CancelReason._();

  /// Staff tapped "Cancel uncollected" after the pickup window.
  static const notCollected = 'not_collected';
}

class MovementType {
  MovementType._();
  static const stockIn = 'stock_in';
  static const sale = 'sale';
  static const order = 'order';
  static const orderCancel = 'order_cancel';
  static const expired = 'expired';
  static const damaged = 'damaged';
  static const adjustment = 'adjustment';
}

class MovementSource {
  MovementSource._();
  static const barcode = 'barcode';
  static const qr = 'qr';
  static const manual = 'manual';
  static const csv = 'csv';
  static const order = 'order';
}
