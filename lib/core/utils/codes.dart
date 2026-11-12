import 'dart:math';

import '../constants.dart';

final _random = Random.secure();

/// No 0/O or 1/I so the code is easy to read out at the counter.
const _pickupAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Random 6-character pickup code, shown to staff as a QR code.
String generatePickupCode() => List.generate(
  6,
  (_) => _pickupAlphabet[_random.nextInt(_pickupAlphabet.length)],
).join();

/// Code for items without a barcode, e.g. "SK-000123" (printed as a QR label).
String generateShortProductCode() =>
    '$shortCodePrefix${_random.nextInt(1000000).toString().padLeft(6, '0')}';

/// Adds the EAN-13 check digit to a 12-digit code.
String ean13(String first12) {
  assert(first12.length == 12);
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final digit = int.parse(first12[i]);
    sum += i.isEven ? digit : digit * 3;
  }
  return '$first12${(10 - sum % 10) % 10}';
}

/// Firestore document IDs cannot contain "/" and must not be "." or "..".
bool isValidProductCode(String code) =>
    code.isNotEmpty &&
    code.length <= 64 &&
    !code.contains('/') &&
    code != '.' &&
    code != '..' &&
    !code.startsWith('__');
