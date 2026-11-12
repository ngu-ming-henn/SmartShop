import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../l10n/strings.dart';
import '../../widgets/scanner_view.dart';

/// Student scans a barcode -> Product Detail (price, stock, Save Food deal).
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Scan product'))),
      body: ScannerView(
        hint: context.tr('Scan a barcode or SmartShop QR label'),
        onCode: (code) async {
          await context.push(productPath(code)); // open Product Detail
        },
      ),
    );
  }
}
