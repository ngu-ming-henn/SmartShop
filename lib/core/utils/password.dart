import '../../l10n/strings.dart';

/// Password rules for new accounts: at least 8 characters with a lowercase
/// letter, a number and a symbol such as @.
typedef PasswordRule = ({
  String label,
  String missing,
  bool Function(String) test,
});

final passwordRules = <PasswordRule>[
  (
    label: 'At least 8 characters',
    missing: 'Needs at least 8 characters',
    test: (p) => p.length >= 8,
  ),
  (
    label: 'A lowercase letter (a-z)',
    missing: 'Needs a lowercase letter (a-z)',
    test: (p) => p.contains(RegExp('[a-z]')),
  ),
  (
    label: 'A number (0-9)',
    missing: 'Needs a number (0-9)',
    test: (p) => p.contains(RegExp('[0-9]')),
  ),
  (
    label: r'A symbol, e.g. @ # $ !',
    missing: r'Needs a symbol, e.g. @ # $ !',
    test: (p) => p.contains(RegExp(r'[^A-Za-z0-9\s]')),
  ),
];

enum PasswordStrength { none, weak, fair, good, strong }

/// Weak / Fair until every rule is met; Good when it is; Strong with an
/// uppercase letter or 12+ characters as well.
PasswordStrength passwordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.none;
  final met = passwordRules.where((r) => r.test(password)).length;
  if (met < passwordRules.length) {
    return met <= 2 ? PasswordStrength.weak : PasswordStrength.fair;
  }
  final hasUpper = password.contains(RegExp('[A-Z]'));
  return hasUpper || password.length >= 12
      ? PasswordStrength.strong
      : PasswordStrength.good;
}

/// Form validator for a new password: names the first rule not met.
String? validateNewPassword(String? value) {
  for (final rule in passwordRules) {
    if (!rule.test(value ?? '')) return AppStrings.tr(rule.missing);
  }
  return null;
}
