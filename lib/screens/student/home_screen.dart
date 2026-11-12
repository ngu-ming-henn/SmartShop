import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/deal_widgets.dart';
import '../../widgets/motion.dart';
import '../../widgets/product_widgets.dart';

/// Search bar, categories, ready-order banner, ✨ AI Budget Planner card,
/// Save Food deals (if any) and popular items. Sections slide in one after
/// another.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late final Stream<List<Product>> _products = context
      .read<ProductService>()
      .watchActiveProducts();
  late final Stream<List<Order>> _myOrders = context
      .read<OrderService>()
      .watchMyOrders(context.read<AuthProvider>().user!.uid);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = (user?.name ?? '').trim().split(' ').first;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Row(
          children: [
            SmartShopLogo(size: 34, shadow: false),
            SizedBox(width: 10),
            Text('SmartShop', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          GreenPointsChip(points: user?.greenPoints ?? 0),
          const CartButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!);
          final products = snap.data;
          final deals =
              (products ?? const <Product>[])
                  .where((p) => p.isOnSaveFood && !p.isOutOfStock)
                  .toList()
                ..sort(
                  (a, b) => (a.expiryDate ?? DateTime(9999)).compareTo(
                    b.expiryDate ?? DateTime(9999),
                  ),
                );
          final popular =
              (products ?? const <Product>[])
                  .where((p) => !p.isOutOfStock)
                  .toList()
                ..sort((a, b) {
                  final bySold = b.soldCount.compareTo(a.soldCount);
                  return bySold != 0 ? bySold : a.name.compareTo(b.name);
                });

          final sections = <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                firstName.isEmpty
                    ? context.tr('What would you like today?')
                    : context.tr('Hi {name}, what would you like today?', {
                        'name': firstName,
                      }),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: TextField(
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.tr('Search products'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onSubmitted: (q) => context.push(
                  '/products?q=${Uri.encodeQueryComponent(q.trim())}',
                ),
              ),
            ),
            CategoriesAndDeal(
              featured: [
                ...deals,
                ...popular.where((p) => !p.isOnSaveFood),
              ].take(6).toList(),
            ),
            _ReadyOrdersBanner(orders: _myOrders),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _BudgetPlannerCard(),
            ),
            const _FindShopCard(),
            if (deals.isNotEmpty) ...[
              SectionHeader(
                title: '🍞 ${context.tr('Save Food deals')}',
                action: context.tr('See all'),
                onAction: () => context.push('/products?saveFood=1'),
              ),
              _ProductCarousel(products: deals),
            ],
            SectionHeader(
              title: '🔥 ${context.tr('Popular now')}',
              action: context.tr('See all'),
              onAction: () => context.push('/products'),
            ),
            if (products == null)
              const SizedBox(height: 120, child: LoadingView())
            else if (popular.isEmpty)
              EmptyState(
                icon: Icons.inventory_2_outlined,
                title: context.tr(
                  products.isEmpty
                      ? 'No products yet'
                      : 'Everything is sold out',
                ),
                message: context.tr(
                  products.isEmpty
                      ? 'The koperasi has not added any products.'
                      : 'Check back after the next delivery.',
                ),
              )
            else
              _ProductCarousel(products: popular.take(10).toList()),
          ];

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (var i = 0; i < sections.length; i++)
                FadeSlideIn(delay: stagger(i, stepMs: 70), child: sections[i]),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCarousel extends StatelessWidget {
  const _ProductCarousel({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 228,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => FadeSlideIn(
          delay: stagger(i, stepMs: 60),
          offset: 18,
          child: ProductCard(
            product: products[i],
            onTap: () => context.push(productPath(products[i].barcode)),
          ),
        ),
      ),
    );
  }
}

/// "Order A7K2Q9 is READY" for every order waiting for pickup, with a soft
/// pulse so it catches the eye.
class _ReadyOrdersBanner extends StatelessWidget {
  const _ReadyOrdersBanner({required this.orders});
  final Stream<List<Order>> orders;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: orders,
      builder: (context, snap) {
        final ready = (snap.data ?? const <Order>[])
            .where((o) => o.isReady)
            .toList();
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              for (final o in ready)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _Pulse(
                    child: Card(
                      color: AppColors.accent,
                      child: ListTile(
                        onTap: () => context.push('/order/${o.id}'),
                        leading: const Icon(
                          Icons.shopping_bag,
                          color: AppColors.textOnAccent,
                        ),
                        title: Text(
                          context.tr('Order {no} is READY', {
                            'no': receiptNo(o.id),
                          }),
                          style: const TextStyle(
                            color: AppColors.textOnAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          context.tr('Show your pickup QR at the counter'),
                          style: const TextStyle(color: AppColors.textOnAccent),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textOnAccent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Gentle repeating scale, for things the student should not miss.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(
      begin: 1.0,
      end: 1.025,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// Closed with ✕ until the app is opened again (not saved on purpose).
final _shopCardHidden = ValueNotifier(false);

/// Where the koperasi is: green when open, red when closed. Tap for the map.
class _FindShopCard extends StatelessWidget {
  const _FindShopCard();

  void _hide(BuildContext context) {
    _shopCardHidden.value = true;
    showSnack(
      context,
      context.tr(
        'Hidden until you open the app again. The map is also in Profile.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _shopCardHidden,
      builder: (context, hidden, _) => AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: hidden ? const SizedBox(width: double.infinity) : _card(context),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final open = ShopLocation.isOpen(DateTime.now());
    final color = open ? context.eco : AppColors.error;
    String time(int hour) => formatTime(DateTime(2000, 1, 1, hour));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Pressable(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => context.push('/shop'),
            contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(Icons.storefront, color: color),
            ),
            title: Text(
              context.tr('Find the koperasi'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    open
                        ? context.tr('Open now · until {time}', {
                            'time': time(AppRules.closingHour),
                          })
                        : context.tr('Closed now · opens {time}', {
                            'time': time(AppRules.openingHour),
                          }),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              tooltip: context.tr('Hide'),
              icon: Icon(Icons.close, color: context.colors.outline),
              onPressed: () => _hide(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetPlannerCard extends StatelessWidget {
  const _BudgetPlannerCard();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/planner'),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBright.withValues(alpha: 0.14),
                  AppColors.accent.withValues(alpha: 0.12),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✨ ${context.tr('AI Budget Planner')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'What can RM10 buy? Get 3 combos for your budget.',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
