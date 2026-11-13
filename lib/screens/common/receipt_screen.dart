import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../viewmodels/common/order_view_model.dart';
import '../../widgets/common.dart';
import '../../widgets/receipt_view.dart';

/// Digital receipt after pickup or a counter sale (students and staff),
/// from [OrderViewModel].
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderViewModel>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Digital receipt'))),
      body: Builder(
        builder: (context) {
          if (vm.error != null) return ErrorView(error: vm.error!);
          if (vm.loading) return const LoadingView();
          final order = vm.order;
          if (order == null) {
            return EmptyState(
              icon: Icons.search_off,
              title: context.tr('Receipt not found'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [ReceiptView(order: order)],
          );
        },
      ),
    );
  }
}
