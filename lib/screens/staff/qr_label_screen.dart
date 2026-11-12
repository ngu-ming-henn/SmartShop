import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../widgets/common.dart';

/// QR label for items without a barcode (C2): kuih, bread, loose stationery.
/// Screenshot it and print, or show it on a shelf tablet.
class QrLabelScreen extends StatefulWidget {
  const QrLabelScreen({super.key, required this.code});
  final String code;

  @override
  State<QrLabelScreen> createState() => _QrLabelScreenState();
}

class _QrLabelScreenState extends State<QrLabelScreen> {
  late final Stream<Product?> _product = context
      .read<ProductService>()
      .watchProduct(widget.code);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('QR label'))),
      body: StreamBuilder<Product?>(
        stream: _product,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!);
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final p = snap.data;
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
