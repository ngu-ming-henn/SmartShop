import 'package:flutter/material.dart' show ChangeNotifier, Locale, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../services/notification_service.dart';

/// Small settings saved on the phone with shared_preferences:
/// language, light / dark mode and notifications.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._prefs) {
    NotificationService.instance.enabled = notificationsEnabled;
    AppStrings.language = language;
  }

  final SharedPreferences _prefs;
  static const _notificationsKey = 'notificationsEnabled';
  static const _languageKey = 'language';
  static const _themeKey = 'themeMode';

  bool get notificationsEnabled => _prefs.getBool(_notificationsKey) ?? true;

  /// 'en' or 'ms'.
  String get language => _prefs.getString(_languageKey) == AppStrings.malay
      ? AppStrings.malay
      : AppStrings.english;

  Locale get locale => Locale(language);

  ThemeMode get themeMode => switch (_prefs.getString(_themeKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_notificationsKey, value);
    NotificationService.instance.enabled = value;
    if (value) await NotificationService.instance.requestPermission();
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    await _prefs.setString(_languageKey, value);
    AppStrings.language = language;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    await _prefs.setString(_themeKey, value.name);
    notifyListeners();
  }
}
