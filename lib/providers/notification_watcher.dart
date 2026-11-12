import 'dart:async';

import '../core/utils/format.dart';
import '../l10n/strings.dart';
import '../models/app_user.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';

/// Watches Firestore while the app runs and shows local notifications:
/// "Order ready" (S1) and Save Food deals for students; low-stock and
/// near-expiry alerts for staff. The first snapshot of each stream is the
/// baseline, so only real changes notify.
const tr = AppStrings.tr;

class NotificationWatcher {
  NotificationWatcher({
    required this.products,
    required this.orders,
    NotificationService? notifications,
  }) : _notifications = notifications ?? NotificationService.instance;

  final ProductService products;
  final OrderService orders;
  final NotificationService _notifications;
  final _subs = <StreamSubscription<Object?>>[];
  String? _watchingKey;

  void start(AppUser user) {
    final key = '${user.uid}:${user.role}';
    if (_watchingKey == key) return;
    stop();
    _watchingKey = key;
    unawaited(_notifications.requestPermission());
    if (user.isStaff) {
      _watchStock();
    } else {
      _watchMyOrders(user.uid);
      _watchSaveFoodDeals();
    }
  }

  void stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _watchingKey = null;
  }

  // ---------------------------------------------------------------- student

  void _watchMyOrders(String uid) {
    Map<String, String>? previous;
    _subs.add(
      orders.watchMyOrders(uid).listen((orders) {
        final now = {for (final o in orders) o.id: o.status};
        if (previous != null) {
          for (final o in orders) {
            final before = previous![o.id];
            if (before == null || before == o.status) continue;
            if (o.isReady) {
              _notify(
                o.id,
                tr('Your order is ready 🎉'),
                tr('Show your pickup QR at the koperasi counter.'),
              );
            } else if (o.isCancelled) {
              _notify(
                o.id,
                tr('Order cancelled'),
                tr(
                  o.wasNotCollected
                      ? 'Order {no} was not collected in time. '
                            'Cancelled: not collected.'
                      : 'Order {no} was cancelled.',
                  {'no': receiptNo(o.id)},
                ),
              );
            }
          }
        }
        previous = now;
      }, onError: (_) {}),
    );
  }

  void _watchSaveFoodDeals() {
    Set<String>? previous;
    _subs.add(
      products.watchActiveProducts().listen((products) {
        final deals = products.where((p) => p.isOnSaveFood && p.stock > 0);
        final now = {for (final p in deals) p.barcode};
        if (previous != null) {
          final fresh = deals
              .where((p) => !previous!.contains(p.barcode))
              .toList();
          if (fresh.length == 1) {
            final p = fresh.single;
            _notify(
              'deal-${p.barcode}',
              tr('New Save Food deal 🍞'),
              tr('{name} now {price}', {
                'name': p.name,
                'price': formatRM(p.saveFoodPriceSen!),
              }),
            );
          } else if (fresh.length > 1) {
            _notify(
              'deals',
              tr('New Save Food deals 🍞'),
              tr(
                '{count} items are on Save Food. Grab them before they go to waste!',
                {'count': fresh.length},
              ),
            );
          }
        }
        previous = now;
      }, onError: (_) {}),
    );
  }

  // ------------------------------------------------------------------ staff

  void _watchStock() {
    Set<String>? previousLow;
    Set<String>? previousExpiry;
    _subs.add(
      products.watchAllProducts().listen((products) {
        final active = products.where((p) => p.isActive).toList();
        final low = {
          for (final p in active.where((p) => p.needsRestock)) p.barcode,
        };
        final expiry = {
          for (final p in active.where((p) => p.needsExpiryAction())) p.barcode,
        };

        if (previousLow == null) {
          // First load: one summary instead of one notification per product.
          if (low.isNotEmpty || expiry.isNotEmpty) {
            _notify(
              'stock-summary',
              tr('Stock alerts'),
              tr('{low} low stock · {expiry} near expiry', {
                'low': low.length,
                'expiry': expiry.length,
              }),
            );
          }
        } else {
          final newLow = active
              .where(
                (p) =>
                    low.contains(p.barcode) &&
                    !previousLow!.contains(p.barcode),
              )
              .toList();
          final newExpiry = active
              .where(
                (p) =>
                    expiry.contains(p.barcode) &&
                    !previousExpiry!.contains(p.barcode),
              )
              .toList();
          if (newLow.length + newExpiry.length > 2) {
            // e.g. a delivery or the sample catalogue: one summary, not a burst.
            _notify(
              'stock-summary',
              tr('Stock alerts'),
              tr('{low} new low stock · {expiry} new near expiry', {
                'low': newLow.length,
                'expiry': newExpiry.length,
              }),
            );
          } else {
            for (final p in newLow) {
              _notify(
                'low-${p.barcode}',
                tr('Low stock: {name}', {'name': p.name}),
                p.isOutOfStock
                    ? tr('Out of stock')
                    : tr('Only {count} left', {'count': p.stock}),
              );
            }
            for (final p in newExpiry) {
              _notify(
                'exp-${p.barcode}',
                tr('Near expiry: {name}', {'name': p.name}),
                tr('{label}. Set a Save Food price?', {
                  'label': expiryLabel(p.expiryDate!),
                }),
              );
            }
          }
        }
        previousLow = low;
        previousExpiry = expiry;
      }, onError: (_) {}),
    );
  }

  void _notify(String key, String title, String body) {
    unawaited(
      _notifications.show(
        id: key.hashCode & 0x7fffffff,
        title: title,
        body: body,
      ),
    );
  }
}
