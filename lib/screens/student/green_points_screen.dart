import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/points.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/common.dart';

/// Points balance, how to earn, history and the student's own impact.
class GreenPointsScreen extends StatefulWidget {
  const GreenPointsScreen({super.key});

  @override
  State<GreenPointsScreen> createState() => _GreenPointsScreenState();
}

class _GreenPointsScreenState extends State<GreenPointsScreen> {
  late final Stream<List<Order>> _orders = context
      .read<OrderService>()
      .watchMyOrders(context.read<AuthProvider>().user!.uid);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = context.select<AuthProvider, int>(
      (a) => a.user?.greenPoints ?? 0,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Green points'))),
      body: StreamBuilder<List<Order>>(
        stream: _orders,
        builder: (context, snap) {
          final collected = (snap.data ?? const <Order>[])
              .where((o) => o.isCollected)
              .toList();
          final history = collected.where((o) => o.pointsEarned > 0).toList();
          final bagsSaved = collected.where((o) => o.noPlasticBag).length;
          final foodSaved = collected.fold(
            0,
            (sum, o) => sum + o.saveFoodItemCount,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: context.eco,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.eco, color: Colors.white, size: 48),
                      Text(
                        '$points',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        context.tr('green points'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(
                          'Voucher value: {value}\n({points} points = RM1, redeem at the counter)',
                          {
                            'value': formatRM(voucherValueSen(points)),
                            'points': AppRules.pointsPerRinggitVoucher,
                          },
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SectionHeader(title: context.tr('Your impact')),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: context.tr('Plastic bags avoided'),
                      value: '$bagsSaved',
                      icon: Icons.shopping_bag_outlined,
                      color: context.eco,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: context.tr('Food items saved'),
                      value: '$foodSaved',
                      icon: Icons.bakery_dining,
                      color: const Color(0xFFB26A00),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: context.tr('Paper receipts saved'),
                      value: '${collected.length}',
                      icon: Icons.receipt_long,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
              SectionHeader(title: context.tr('How to earn')),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.shopping_bag_outlined,
                        color: context.eco,
                      ),
                      title: Text(context.tr('No plastic bag')),
                      trailing: Text(
                        context.tr('+{points} / order', {
                          'points': AppRules.pointsNoPlasticBag,
                        }),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.bakery_dining,
                        color: Color(0xFFB26A00),
                      ),
                      title: Text(context.tr('Buy a Save Food item')),
                      trailing: Text(
                        context.tr('+{points} / item', {
                          'points': AppRules.pointsPerSaveFoodItem,
                        }),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.qr_code_2, color: Color(0xFF1565C0)),
                      title: Text(
                        context.tr('Show your member QR at the counter'),
                      ),
                      subtitle: Text(context.tr('Walk-in purchases count too')),
                    ),
                  ],
                ),
              ),
              SectionHeader(title: context.tr('History')),
              if (snap.connectionState == ConnectionState.waiting)
                const LoadingView()
              else if (history.isEmpty)
                EmptyState(
                  icon: Icons.history,
                  title: context.tr('No points earned yet'),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final o in history)
                        ListTile(
                          onTap: () => context.push('/order/${o.id}'),
                          leading: Icon(Icons.eco, color: context.eco),
                          title: Text(
                            '${context.tr(o.isPreorder ? 'Pre-order' : 'Counter sale')} ${receiptNo(o.id)}',
                          ),
                          subtitle: Text(
                            formatDateTime(o.collectedAt ?? o.sortTime),
                          ),
                          trailing: Text(
                            '+${o.pointsEarned}',
                            style: TextStyle(
                              color: context.eco,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
