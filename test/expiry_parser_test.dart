import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/services/expiry_scan_service.dart';

void main() {
  // Tests from the design document (section 8.5)
  test('takes the date after EXP, not MFG', () {
    expect(
      parseExpiryDate('MFG 12/05/2026 EXP 12/11/2026'),
      DateTime(2026, 11, 12),
    );
  });
  test('reads Malay month names', () {
    expect(parseExpiryDate('TARIKH LUPUT: 05 OGOS 2027'), DateTime(2027, 8, 5));
  });
  test('month/year only means last day of month', () {
    expect(parseExpiryDate('BB 11/2026'), DateTime(2026, 11, 30));
  });
  test('no date returns null', () {
    expect(parseExpiryDate('MILO 400G'), isNull);
  });

  // Extra formats from the table in section 8.3
  group('date formats', () {
    test('dashes and two-digit year', () {
      expect(parseExpiryDate('EXP 12-11-26'), DateTime(2026, 11, 12));
    });
    test('dots', () {
      expect(parseExpiryDate('EXP 12.11.2026'), DateTime(2026, 11, 12));
    });
    test('year first', () {
      expect(parseExpiryDate('EXP 2026-11-12'), DateTime(2026, 11, 12));
      expect(parseExpiryDate('EXP 2026.11.12'), DateTime(2026, 11, 12));
    });
    test('English month names, with and without spaces', () {
      expect(
        parseExpiryDate('BEST BEFORE 12 NOV 2026'),
        DateTime(2026, 11, 12),
      );
      expect(parseExpiryDate('EXP 12NOV26'), DateTime(2026, 11, 12));
      expect(parseExpiryDate('USE BY 12-NOV-2026'), DateTime(2026, 11, 12));
    });
    test('Malay short month DIS', () {
      expect(parseExpiryDate('LUPUT 12 DIS 26'), DateTime(2026, 12, 12));
    });
    test('December month/year rolls to 31 Dec', () {
      expect(parseExpiryDate('EXP 12/2026'), DateTime(2026, 12, 31));
    });
    test('lowercase OCR text', () {
      expect(parseExpiryDate('exp: 01/03/2027'), DateTime(2027, 3, 1));
    });
  });

  group('choosing the right date', () {
    test('no keyword: takes the latest date (manufacture is earlier)', () {
      expect(parseExpiryDate('12/05/2026\n12/11/2026'), DateTime(2026, 11, 12));
    });
    test('keyword on a later line still wins', () {
      expect(
        parseExpiryDate('PRODUCT OF MALAYSIA\nMFD 01/01/2027\nEXP 01/06/2026'),
        DateTime(2026, 6, 1),
      );
    });
    test('rejects impossible dates like 31/02', () {
      expect(parseExpiryDate('EXP 31/02/2026'), isNull);
    });
    test('keyword without a date falls back to any date', () {
      expect(
        parseExpiryDate('12/11/2026 BEST BEFORE END OF'),
        DateTime(2026, 11, 12),
      );
    });
  });
}
