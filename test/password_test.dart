import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/utils/password.dart';

void main() {
  group('new password rules (8+ chars, lowercase, number, symbol)', () {
    test('accepts a password that meets every rule', () {
      expect(validateNewPassword('smart@2026'), isNull);
    });
    test('names the first rule that is missing', () {
      expect(validateNewPassword('a@1'), 'Needs at least 8 characters');
      expect(validateNewPassword('SMART@2026'), contains('lowercase'));
      expect(validateNewPassword('smart@shop'), contains('number'));
      expect(validateNewPassword('smartshop2026'), contains('symbol'));
      expect(validateNewPassword(null), 'Needs at least 8 characters');
    });
    test('spaces do not count as a symbol', () {
      expect(validateNewPassword('smart shop 26'), contains('symbol'));
    });
  });

  group('strength line', () {
    test('empty shows nothing', () {
      expect(passwordStrength(''), PasswordStrength.none);
    });
    test('weak or fair until every rule is met', () {
      expect(passwordStrength('abc'), PasswordStrength.weak);
      expect(passwordStrength('abcdefg1'), PasswordStrength.fair);
    });
    test('good when every rule is met, strong with uppercase or 12+', () {
      expect(passwordStrength('smart@2026'), PasswordStrength.good);
      expect(passwordStrength('Smart@2026'), PasswordStrength.strong);
      expect(passwordStrength('smartshop@2026'), PasswordStrength.strong);
    });
  });
}
