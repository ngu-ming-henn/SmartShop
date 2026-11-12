import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../models/stock_movement.dart';
import '../../services/order_service.dart';
import '../../services/stock_service.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Sales chart, top products and the sustainability metrics (section 10).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 7;
  late DateTime _since;
  late Stream<List<Order>> _orders;
  late Stream<List<StockMovement>> _movements;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final today = dateOnly(DateTime.now());
    _since = DateTime(today.year, today.month, today.day - (_days - 1));
    _orders = context.read<OrderService>().watchOrdersSince(_since);
    _movements = context.read<StockService>().watchMovementsSince(_since);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Reports'))),
      body: StreamBuilder<List<Order>>(
        stream: _orders,
        builder: (context, orderSnap) => StreamBuilder<List<StockMovement>>(
          stream: _movements,
          builder: (context, moveSnap) {
            final error = orderSnap.error ?? moveSnap.error;
            if (error != null) return ErrorView(error: error);
            if (!orderSnap.hasData || !moveSnap.hasData) {
              return const LoadingView();
            }
            // While a new period loads, keep the previous render, dimmed.
            final refreshing =
                orderSnap.connectionState == ConnectionState.waiting ||
                moveSnap.connectionState == ConnectionState.waiting;
            final report = _Report.build(
              orders: orderSnap.data!,
              movements: moveSnap.data!,
              since: _since,
              days: _days,
            );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // One filter row above everything it scopes.
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 7,
                      label: Text(context.tr('Last 7 days')),
                    ),
                    ButtonSegment(
                      value: 30,
                      label: Text(context.tr('Last 30 days')),
                    ),
                  ],
                  selected: {_days},
                  onSelectionChanged: (s) => setState(() {
                    _days = s.first;
                    _subscribe();
                  }),
                ),
                const SizedBox(height: 16),
                AnimatedOpacity(
                  opacity: refreshing ? 0.5 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: _ReportBody(report: report),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// All numbers for one period, computed once per snapshot.
class _Report {
  _Report({
    required this.dailySales,
    required this.salesSen,
    required this.orderCount,
    required this.preorderCount,
    required this.topProducts,
    required this.itemsSaved,
    required this.itemsExpired,
    required this.receiptsAvoided,
    required this.bagsAvoided,
    required this.preorderNoBagCount,
    required this.outOfStockEvents,
    required this.queueMinutesSaved,
  });

  final List<({DateTime day, int sen, int orders})> dailySales;
  final int salesSen;
  final int orderCount;
  final int preorderCount;
  final List<({String name, int qty})> topProducts;
  final int itemsSaved;
  final int itemsExpired;
  final int receiptsAvoided;
  final int bagsAvoided;
  final int preorderNoBagCount;
  final int outOfStockEvents;
  final int queueMinutesSaved;

  /// MOV: at least 20% of transactions through pre-order.
  int get preorderSharePct =>
      orderCount == 0 ? 0 : (preorderCount * 100 / orderCount).round();

  /// MOV: at least 50% of pre-orders without a plastic bag.
  int get preorderNoBagPct => preorderCount == 0
      ? 0
      : (preorderNoBagCount * 100 / preorderCount).round();

  factory _Report.build({
    required List<Order> orders,
    required List<StockMovement> movements,
    required DateTime since,
    required int days,
  }) {
    // Only collected orders are sales (money taken at the counter).
    final sold = orders.where((o) => o.isCollected).toList();

    final senByDay = List.filled(days, 0);
    final ordersByDay = List.filled(days, 0);
    for (final o in sold) {
      final i = daysUntil(o.sortTime, from: since);
      if (i >= 0 && i < days) {
        senByDay[i] += o.totalSen;
        ordersByDay[i]++;
      }
    }

    final qtyByProduct = <String, ({String name, int qty})>{};
    for (final o in sold) {
      for (final item in o.items) {
        final prev = qtyByProduct[item.productId];
        qtyByProduct[item.productId] = (
          name: item.name,
          qty: (prev?.qty ?? 0) + item.qty,
        );
      }
    }
    final top = qtyByProduct.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));

    final preorders = sold.where((o) => o.isPreorder).length;
    return _Report(
      dailySales: [
        for (var i = 0; i < days; i++)
          (
            day: DateTime(since.year, since.month, since.day + i),
            sen: senByDay[i],
            orders: ordersByDay[i],
          ),
      ],
      salesSen: sold.fold(0, (sum, o) => sum + o.totalSen),
      orderCount: sold.length,
      preorderCount: preorders,
      topProducts: top.take(5).toList(),
      itemsSaved: sold.fold(0, (sum, o) => sum + o.saveFoodItemCount),
      itemsExpired: movements
          .where((m) => m.type == MovementType.expired)
          .fold(0, (sum, m) => sum + m.quantity.abs()),
      receiptsAvoided: sold.where((o) => o.userId != null).length,
      bagsAvoided: sold.where((o) => o.noPlasticBag).length,
      preorderNoBagCount: sold
          .where((o) => o.isPreorder && o.noPlasticBag)
          .length,
      outOfStockEvents: movements
          .where((m) => m.quantity < 0 && m.stockAfter == 0)
          .length,
      queueMinutesSaved: preorders * AppRules.minutesSavedPerPreorder,
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});
  final _Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = report;
    final big = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final queueTime = r.queueMinutesSaved >= 60
        ? context.tr('{h}h {m}m', {
            'h': r.queueMinutesSaved ~/ 60,
            'm': r.queueMinutesSaved % 60,
          })
        : context.tr('{m} min', {'m': r.queueMinutesSaved});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _Summary(
                    label: context.tr('Sales'),
                    child: Text(formatRM(r.salesSen), style: big),
                  ),
                  const VerticalDivider(width: 1),
                  _Summary(
                    label: context.tr('Orders'),
                    child: CountUp(value: r.orderCount, style: big),
                  ),
                  const VerticalDivider(width: 1),
                  _Summary(
                    label: context.tr('Pre-orders'),
                    child: CountUp(value: r.preorderCount, style: big),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    context.tr('Daily sales (RM)'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    context.tr(
                      'Collected orders. Tap a bar for the exact amount.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: _DailySalesChart(data: r.dailySales),
                ),
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      context.tr('View as table'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    children: [
                      for (final d in r.dailySales.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dateFormat('EEE, d MMM').format(d.day),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  context.tr('{count} orders', {
                                    'count': d.orders,
                                  }),
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  formatRM(d.sen),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SectionHeader(title: context.tr('Top products (units sold)')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: r.topProducts.isEmpty
                ? Text(context.tr('No sales in this period yet.'))
                : _TopProducts(items: r.topProducts),
          ),
        ),
        SectionHeader(title: context.tr('🌱 Sustainability impact')),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GoalBar(
                  label: context.tr('Pre-order share'),
                  percent: r.preorderSharePct,
                  target: 20,
                ),
                const SizedBox(height: 14),
                _GoalBar(
                  label: context.tr('Pre-orders with no plastic bag'),
                  percent: r.preorderNoBagPct,
                  target: 50,
                ),
                const Divider(height: 28),
                _Metric(
                  icon: Icons.timer_outlined,
                  label: context.tr('Shopping time saved by pre-orders'),
                  value: queueTime,
                ),
                _Metric(
                  icon: Icons.receipt_long,
                  label: context.tr('Paper receipts avoided'),
                  value: '${r.receiptsAvoided}',
                ),
                _Metric(
                  icon: Icons.shopping_bag_outlined,
                  label: context.tr('Plastic bags avoided'),
                  value: '${r.bagsAvoided}',
                ),
                _Metric(
                  icon: Icons.bakery_dining,
                  label: context.tr('Items saved from waste (Save Food sold)'),
                  value: '${r.itemsSaved}',
                ),
                _Metric(
                  icon: Icons.remove_shopping_cart_outlined,
                  label: context.tr('Out-of-stock events (aim: down)'),
                  value: '${r.outOfStockEvents}',
                ),
                _Metric(
                  icon: Icons.delete_outline,
                  label: context.tr('Items expired (aim: down)'),
                  value: '${r.itemsExpired}',
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Shopping time assumes {min} minutes saved per collected pre-order. '
                    'Pre-order share counts the transactions recorded in the app.',
                    {'min': AppRules.minutesSavedPerPreorder},
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One number in the summary card.
class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(child: child),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}

/// A percentage against its target: the bar fills up to 100% of the target
/// and turns green once the target is reached.
class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.label,
    required this.percent,
    required this.target,
  });

  final String label;
  final int percent;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = percent >= target;
    final color = reached ? context.eco : AppColors.warning;
    final fill = (percent / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => Container(
            height: 8,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fill),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Container(
                width: c.maxWidth * v,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          reached
              ? context.tr('Target {target}% reached ✓', {'target': target})
              : context.tr('Target {target}%', {'target': target}),
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// One line in the sustainability list: icon, label, number.
class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.eco),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-series column chart: one colour, no legend (the title names it),
/// hairline solid grid, bars at most 24px with 4px rounded tops.
class _DailySalesChart extends StatelessWidget {
  const _DailySalesChart({required this.data});
  final List<({DateTime day, int sen, int orders})> data;

  /// A clean tick step (1, 2 or 5 × 10^n) giving about 4 gridlines.
  static double _niceStep(double max) {
    if (max <= 0) return 10;
    final raw = max / 4;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    for (final m in [1, 2, 5, 10]) {
      if (raw <= m * magnitude) return m * magnitude;
    }
    return 10 * magnitude;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurfaceVariant;
    final grid = theme.colorScheme.onSurface.withValues(alpha: 0.1);
    final maxRM = data.fold(0, (m, d) => math.max(m, d.sen)) / 100;
    final step = _niceStep(maxRM);
    final maxY = math.max(step, (maxRM / step).ceil() * step);
    final weekly = data.length <= 7;
    final tickStyle = theme.textTheme.labelSmall?.copyWith(
      color: ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = (constraints.maxWidth - 48) / data.length;
        final barWidth = math.min(24.0, slot * 0.6);
        return BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(
              show: true,
              border: Border(bottom: BorderSide(color: grid, width: 1)),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: grid, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: step,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      NumberFormat.compact().format(value),
                      style: tickStyle,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    final last = data.length - 1;
                    // 7 days: every day. 30 days: every 5th day + today.
                    if (!weekly && i != last && (last - i) % 5 != 0) {
                      return const SizedBox.shrink();
                    }
                    final day = data[i].day;
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        weekly
                            ? dateFormat('EEE').format(day)
                            : dateFormat('d/M').format(day),
                        style: tickStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF263238),
                tooltipBorderRadius: BorderRadius.circular(8),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final d = data[group.x];
                  // Value leads, label follows.
                  return BarTooltipItem(
                    formatRM(d.sen),
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(
                        text:
                            '\n${dateFormat('EEE, d MMM').format(d.day)} · '
                            '${context.tr('{count} orders', {'count': d.orders})}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].sen / 100,
                      color: context.brand,
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal bars built from widgets: one colour, value at the tip.
class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.items});
  final List<({String name, int qty})> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = items.first.qty;
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 16,
                            width: math.max(4, c.maxWidth * item.qty / max),
                            decoration: BoxDecoration(
                              color: context.brand,
                              borderRadius: BorderRadius.horizontal(
                                right: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${item.qty}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
