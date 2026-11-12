import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/utils/format.dart';
import 'package:smartshop/core/utils/password.dart';
import 'package:smartshop/l10n/malay.dart';
import 'package:smartshop/l10n/strings.dart';

void main() {
  tearDown(() => AppStrings.language = AppStrings.english);

  test('English stays English, Malay is looked up', () {
    expect(AppStrings.translate('en', 'Log out'), 'Log out');
    expect(AppStrings.translate('ms', 'Log out'), 'Log keluar');
    expect(AppStrings.translate('ms', 'Not in the list'), 'Not in the list');
  });

  test('placeholders are filled in both languages', () {
    expect(
      AppStrings.translate('ms', 'Added {qty} × {name} to cart', {
        'qty': 2,
        'name': 'Milo',
      }),
      '2 × Milo ditambah ke troli',
    );
    expect(
      AppStrings.translate('en', 'Order {no} is READY', {'no': 'A7K2Q9'}),
      'Order A7K2Q9 is READY',
    );
  });

  test('messages outside widgets follow the chosen language', () {
    AppStrings.language = AppStrings.malay;
    expect(validateNewPassword('abc'), 'Perlu sekurang-kurangnya 8 aksara');
    expect(
      expiryLabel(DateTime(2026, 11, 12), from: DateTime(2026, 11, 9)),
      'Tamat tempoh dalam 3 hari',
    );
  });

  test('every text in tr(...) has a Malay translation', () {
    // tr('single literal' ...) calls; texts built from several pieces are
    // covered by the review script instead.
    final call = RegExp(r"\btr\(\s*'((?:[^'\\\n]|\\.)*)'\s*[,)]");
    final missing = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('malay.dart')) continue;
      for (final m in call.allMatches(file.readAsStringSync())) {
        final key = m[1]!
            .replaceAll(r"\'", "'")
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\$', r'$');
        if (!RegExp('[A-Za-z]').hasMatch(key)) continue;
        if (!malayStrings.containsKey(key)) missing.add(key);
      }
    }
    expect(missing, isEmpty, reason: 'Add these to lib/l10n/malay.dart');
  });
}
