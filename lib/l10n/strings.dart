import 'package:flutter/widgets.dart';

import 'malay.dart';

/// Two languages: English (the text written in the code) and Bahasa
/// Melayu (lib/l10n/malay.dart). Text with no Malay entry stays English.
///
/// In widgets use `context.tr('Log in')`, so the screen rebuilds when the
/// language changes. `{name}` placeholders are filled from [args]:
/// `context.tr('Hello, {name}', {'name': user.name})`.
class AppStrings {
  AppStrings._();

  static const english = 'en';
  static const malay = 'ms';
  static const supportedLocales = [Locale(english), Locale(malay)];

  /// Current language, for code without a BuildContext (notifications,
  /// error messages). Kept up to date by SettingsViewModel.
  static String language = english;

  static String translate(
    String languageCode,
    String en, [
    Map<String, Object?> args = const {},
  ]) {
    var text = languageCode == malay ? (malayStrings[en] ?? en) : en;
    args.forEach((key, value) => text = text.replaceAll('{$key}', '$value'));
    return text;
  }

  /// Translate into the current [language].
  static String tr(String en, [Map<String, Object?> args = const {}]) =>
      translate(language, en, args);
}

extension Translate on BuildContext {
  String tr(String en, [Map<String, Object?> args = const {}]) =>
      AppStrings.translate(Localizations.localeOf(this).languageCode, en, args);
}
