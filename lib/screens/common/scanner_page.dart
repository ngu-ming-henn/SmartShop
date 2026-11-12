import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';

import '../../widgets/scanner_view.dart';

/// Full-screen scanner that returns the code: `await context.push<String>(...)`.
class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key, required this.title, this.hint});
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ScannerView(
        hint: hint ?? context.tr('Point the camera at a barcode or QR code'),
        onCode: (code) async => context.pop(code),
      ),
    );
  }
}

/// Opens [ScannerPage] and returns the scanned code (or null).
Future<String?> scanCode(BuildContext context, {String? title, String? hint}) {
  final query = {'title': title ?? context.tr('Scan'), 'hint': ?hint};
  return context.push<String>(
    Uri(path: '/scanner', queryParameters: query).toString(),
  );
}
