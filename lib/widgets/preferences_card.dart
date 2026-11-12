import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../providers/settings_provider.dart';

/// Language (English / Bahasa Melayu), light / dark mode and notifications.
class PreferencesCard extends StatelessWidget {
  const PreferencesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    Widget label(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.brand),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label(Icons.translate, context.tr('Language')),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AppStrings.english,
                  label: Text('English'),
                ),
                ButtonSegment(
                  value: AppStrings.malay,
                  label: Text('Bahasa Melayu'),
                ),
              ],
              selected: {settings.language},
              onSelectionChanged: (s) => settings.setLanguage(s.first),
            ),
            const SizedBox(height: 16),
            label(Icons.palette_outlined, context.tr('Appearance')),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined),
                  label: Text(context.tr('Auto')),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(context.tr('Light')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(context.tr('Dark')),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.notifications_outlined,
                color: context.brand,
              ),
              title: Text(context.tr('Notifications')),
              subtitle: Text(context.tr('Order ready and stock alerts')),
              value: settings.notificationsEnabled,
              onChanged: settings.setNotificationsEnabled,
            ),
          ],
        ),
      ),
    );
  }
}
