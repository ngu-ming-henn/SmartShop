import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/strings.dart';
import '../../widgets/brand.dart';
import '../../widgets/motion.dart';

/// About the app. Language, light / dark mode and notifications are on
/// the Profile screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('About SmartShop'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeSlideIn(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SmartShopLogo(size: 36, shadow: false),
                        const SizedBox(width: 10),
                        Text(
                          context.tr('About SmartShop'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'A mobile pre-order and QR code pickup app for UTS '
                        'Koperasi. Check live price and stock, pre-order to '
                        'skip the queue, collect with a QR code, and save '
                        'paper and plastic with digital receipts.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Supports SDG 11 — Sustainable Cities and Communities.',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Near expiry: within {days} days · {points} points = RM1',
                        {
                          'days': AppRules.nearExpiryDays,
                          'points': AppRules.pointsPerRinggitVoucher,
                        },
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Team Sustainable Smart Campus · Version {version}',
                        {'version': '1.0.0'},
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const UtsCrest(size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr(
                              'Built for UTS Koperasi, University of '
                              'Technology Sarawak',
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
