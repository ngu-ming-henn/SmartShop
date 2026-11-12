import '../constants.dart';

/// Green points (design doc 7.4): +5 per order with no plastic bag,
/// +10 per Save Food item.
int calculateGreenPoints({
  required bool noPlasticBag,
  required int saveFoodItemCount,
}) =>
    (noPlasticBag ? AppRules.pointsNoPlasticBag : 0) +
    saveFoodItemCount * AppRules.pointsPerSaveFoodItem;

/// Voucher value of a points balance in sen (100 points = RM1).
int voucherValueSen(int points) =>
    (points ~/ AppRules.pointsPerRinggitVoucher) * 100;

/// Suggested Save Food price: 30% off, rounded down to 10 sen.
int suggestedSaveFoodPriceSen(int priceSen) {
  final discounted = (priceSen * (1 - AppRules.suggestedSaveFoodDiscount))
      .floor();
  return (discounted ~/ 10) * 10;
}
