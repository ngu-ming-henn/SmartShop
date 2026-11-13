import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/staff/qr_label_view_model.dart';
import '../../widgets/common.dart';

/// QR label for items without a barcode (C2): kuih, bread, loose stationery.
/// Screenshot it and print, or show it on a shelf tablet
/// ([QrLabelViewModel]).
class QrLabelScreen extends StatelessWidget {
  const QrLabelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<QrLabelViewModel>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('QR label'))),
      body: Builder(
        builder: (context) {
          if (vm.error != null) return ErrorView(error: vm.error!);
          if (vm.loading) return const LoadingView();
          final p = vm.product;
          if (p == null) {
            return EmptyState(
              icon: Icons.search_off,
              title: context.tr('Product not found'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'UTS SmartShop',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      QrImageView(
                        data: p.barcode,
                        size: 200,
                        backgroundColor: Colors.white,
                        semanticsLabel: context.tr('QR label for {name}', {
                          'name': p.name,
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.name,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formatRM(p.priceSen),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(p.barcode, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(
                  'Take a screenshot and print it, then stick it on the shelf or tray. '
                  'Students and staff scan this QR just like a barcode.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          );
        },
      ),
    );
  }
}
