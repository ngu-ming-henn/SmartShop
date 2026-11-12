import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/common.dart';
import '../../widgets/receipt_view.dart';

/// Digital receipt after pickup or a counter sale (students and staff).
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final Stream<Order?> _order = context.read<OrderService>().watchOrder(
    widget.orderId,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Digital receipt'))),
      body: StreamBuilder<Order?>(
        stream: _order,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!);
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final order = snap.data;
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
