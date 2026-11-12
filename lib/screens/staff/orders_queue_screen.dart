import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/common.dart';
import '../../widgets/product_widgets.dart';
import '../common/scanner_page.dart';

/// Orders queue: Accept & pack -> Ready -> scan pickup QR -> Collected;
/// "Cancel uncollected" after closing time.
class OrdersQueueScreen extends StatefulWidget {
  const OrdersQueueScreen({super.key});

  @override
  State<OrdersQueueScreen> createState() => _OrdersQueueScreenState();
}

class _OrdersQueueScreenState extends State<OrdersQueueScreen> {
  late final Stream<List<Order>> _queue = context
      .read<OrderService>()
      .watchQueue();
  final _busy = <String>{};
  bool _cancellingUncollected = false;

  OrderService get _orders => context.read<OrderService>();
  String get _staffId => context.read<AuthProvider>().user!.uid;

  Future<void> _run(
    String orderId,
    Future<void> Function() action, {
    String? done,
  }) async {
    setState(() => _busy.add(orderId));
    try {
      await action();
      if (mounted && done != null) showSnack(context, done);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(orderId));
    }
  }

  Future<void> _accept(Order o) => _run(
    o.id,
    () => _orders.acceptAndPack(o.id, staffId: _staffId),
    done: context.tr('Packed. {name} has been notified.', {
      'name': o.customerName ?? context.tr('The student'),
    }),
  );

  Future<void> _cancel(Order o) async {
    final ok = await confirm(
      context,
      title: context.tr(o.isPending ? 'Reject order?' : 'Cancel order?'),
      message: context.tr(
        o.isReady
            ? 'The packed items go back into stock.'
            : 'The student will see this order as cancelled.',
      ),
      confirmLabel: context.tr(o.isPending ? 'Reject' : 'Cancel order'),
      cancelLabel: context.tr('Keep'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(
      o.id,
      () => _orders.cancelByStaff(o.id, staffId: _staffId),
      done: context.tr('Order cancelled.'),
    );
  }

  Future<void> _collect(Order o) async {
    final ok = await confirm(
      context,
      title: context.tr('Collect {total}', {'total': formatRM(o.totalSen)}),
      message:
          '${o.customerName ?? context.tr('Customer')} · '
          '${context.tr('{count} item(s)', {'count': o.itemCount})}\n'
          '${context.tr('Pickup code {code}', {'code': o.pickupCode ?? '-'})}\n\n'
          '${context.tr('Take payment at the counter, then confirm.')}',
      confirmLabel: context.tr('Paid & collected'),
      cancelLabel: context.tr('Back'),
    );
    if (!ok || !mounted) return;
    await _run(o.id, () => _orders.markCollected(o.id, staffId: _staffId));
    if (mounted) await context.push('/receipt/${o.id}');
  }

  /// Staff scan the pickup QR on the student's phone.
  Future<void> _scanPickup() async {
    final code = await scanCode(
      context,
      title: context.tr('Scan pickup QR'),
      hint: context.tr("Scan the QR on the student's phone"),
    );
    if (code == null || !mounted) return;
    try {
      final order = await _orders.findByPickupCode(code);
      if (!mounted) return;
      if (order == null) {
        showSnack(
          context,
          context.tr('No order with pickup code {code}', {'code': code}),
        );
      } else if (order.isReady) {
        await _collect(order);
      } else {
        showSnack(context, OrderService.notReadyMessage(order)); // TC19
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// S6: after closing time, uncollected READY orders are cancelled and
  /// their stock goes back on the shelf.
  Future<void> _cancelUncollected(int count) async {
    if (count == 0) {
      showSnack(
        context,
        context.tr(
          'No uncollected orders. Ready orders can be collected until {time}.',
          {'time': formatTime(DateTime(2000, 1, 1, AppRules.closingHour))},
        ),
      );
      return;
    }
    final ok = await confirm(
      context,
      title: context.tr('Cancel {count} uncollected order(s)?', {
        'count': count,
      }),
      message: context.tr(
        'They were not collected before closing time. The items go back '
        'into stock and the students see "Cancelled: not collected".',
      ),
      confirmLabel: context.tr('Cancel orders'),
      cancelLabel: context.tr('Keep'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _cancellingUncollected = true);
    try {
      final cancelled = await _orders.cancelUncollected(staffId: _staffId);
      if (mounted) {
        showSnack(
          context,
          context.tr(
            'Cancelled {count} uncollected order(s). Stock restored.',
            {'count': cancelled},
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cancellingUncollected = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: _queue,
      builder: (context, snap) {
        final orders = snap.data ?? const <Order>[];
        final pending = orders.where((o) => o.isPending).toList();
        final ready = orders.where((o) => o.isReady).toList();
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.tr('Orders queue')),
              actions: [
                IconButton(
                  tooltip: context.tr('Scan pickup QR'),
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanPickup,
                ),
              ],
              bottom: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(
                    text: context.tr('To pack ({count})', {
                      'count': pending.length,
                    }),
                  ),
                  Tab(
                    text: context.tr('Ready ({count})', {
                      'count': ready.length,
                    }),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _scanPickup,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(context.tr('Scan pickup QR')),
            ),
            body: snap.hasError
                ? ErrorView(error: snap.error!)
                : !snap.hasData
                ? const LoadingView()
                : TabBarView(
                    children: [
                      _list(pending, context.tr('No orders to pack')),
                      _list(
                        ready,
                        context.tr('No orders waiting for pickup'),
                        header: _uncollectedBar(ready),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _uncollectedBar(List<Order> ready) {
    final count = ready.where((o) => o.isUncollected()).length;
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
        onPressed: _cancellingUncollected
            ? null
            : () => _cancelUncollected(count),
        icon: const Icon(Icons.event_busy),
        label: Text(
          count == 0
              ? context.tr('Cancel uncollected')
              : context.tr('Cancel uncollected ({count})', {'count': count}),
        ),
      ),
    );
  }

  Widget _list(List<Order> orders, String empty, {Widget? header}) {
    if (orders.isEmpty) {
      return EmptyState(icon: Icons.inbox_outlined, title: empty);
    }
    final offset = header == null ? 0 : 1;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: orders.length + offset,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i < offset) return header!;
        final order = orders[i - offset];
        return _QueueCard(
          order: order,
          busy: _busy.contains(order.id),
          onAccept: () => _accept(order),
          onCollect: () => _collect(order),
          onCancel: () => _cancel(order),
        );
      },
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.order,
    required this.busy,
    required this.onAccept,
    required this.onCollect,
    required this.onCancel,
  });

  final Order order;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onCollect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waited = DateTime.now().difference(order.sortTime).inMinutes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.customerName ?? context.tr('Student'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  formatRM(order.totalSen),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              '${receiptNo(order.id)} · ${formatTime(order.sortTime)} '
              '(${waited < 1 ? context.tr('just now') : context.tr('{min} min ago', {'min': waited})})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final item in order.items)
              Text(
                '${item.qty} × ${item.name}${item.isSaveFood ? '  🍞' : ''}',
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                OrderStatusPill(order: order),
                if (order.noPlasticBag)
                  Pill(
                    label: context.tr('No plastic bag'),
                    color: context.eco,
                    icon: Icons.eco,
                  ),
                if (order.pickupCode != null)
                  Pill(
                    label: context.tr('Code {code}', {
                      'code': order.pickupCode,
                    }),
                    color: Colors.blueGrey,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: busy ? null : onCancel,
                  child: Text(
                    context.tr(order.isPending ? 'Reject' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                if (order.isPending)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 44),
                    ),
                    onPressed: busy ? null : onAccept,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.inventory),
                    label: Text(context.tr('Accept & pack')),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: busy ? null : onCollect,
                    icon: const Icon(Icons.check),
                    label: Text(context.tr('Collect')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
