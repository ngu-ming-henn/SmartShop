import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils/format.dart';
import '../l10n/strings.dart';
import '../models/order.dart';
import '../models/product.dart';
import 'common.dart';
import 'motion.dart';

IconData categoryIcon(String category) => switch (category) {
  'Food' => Icons.rice_bowl,
  'Drinks' => Icons.local_drink,
  'Snacks' => Icons.cookie,
  'Stationery' => Icons.edit_note,
  _ => Icons.shopping_basket,
};

String categoryEmoji(String category) => switch (category) {
  'Food' => '🍱',
  'Drinks' => '🥤',
  'Snacks' => '🍿',
  'Stationery' => '✏️',
  _ => '🛍️',
};

/// Soft background colour for each category's picture.
Color categoryColor(String category) => switch (category) {
  'Food' => const Color(0xFFFFE0B2),
  'Drinks' => const Color(0xFFB3E5FC),
  'Snacks' => const Color(0xFFFFCDD2),
  'Stationery' => const Color(0xFFD1C4E9),
  _ => const Color(0xFFC8E6C9),
};

/// Products without a photo get an emoji that matches the name (first
/// match wins), or the category.
const _emojiByKeyword = <String, String>{
  'candle': '🕯️',
  'bread': '🍞',
  'roti': '🍞',
  'bun': '🥯',
  'muffin': '🧁',
  'puff': '🥟',
  'sandwich': '🥪',
  'nasi': '🍛',
  'noodle': '🍜',
  'maggi': '🍜',
  'mee': '🍜',
  'indomie': '🍜',
  'kuih': '🍡',
  'yogurt': '🥣',
  'milk': '🥛',
  'water': '💧',
  'coffee': '☕',
  'nescaf': '☕',
  'teh': '🧋',
  'tea': '🧋',
  'milo': '🥤',
  'cola': '🥤',
  '100plus': '🥤',
  'juice': '🧃',
  'chocolate': '🍫',
  'chips': '🍟',
  'twisties': '🍟',
  'cracker': '🍘',
  'biscuit': '🍪',
  'oreo': '🍪',
  'pen': '🖊️',
  'pencil': '✏️',
  'highlighter': '🖍️',
  'notebook': '📒',
  'pad': '📝',
  'paper': '📄',
  'sticky': '🗒️',
  'calculator': '🧮',
  'tape': '📏',
  'tissue': '🧻',
  'sanitizer': '🧴',
  'mask': '😷',
  'umbrella': '☂️',
  'batter': '🔋',
  'toothpaste': '🪥',
  'shampoo': '🧴',
};

String productEmoji(Product product) {
  final name = product.name.toLowerCase();
  for (final e in _emojiByKeyword.entries) {
    if (name.contains(e.key)) return e.value;
  }
  return switch (product.category) {
    'Food' => '🍱',
    'Drinks' => '🥤',
    'Snacks' => '🍿',
    'Stationery' => '✏️',
    _ => '🛍️',
  };
}

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    this.size = 56,
    this.radius = 12,
  });

  final Product product;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _tileColors(context, product),
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        productEmoji(product),
        style: TextStyle(fontSize: size * 0.5, height: 1.1),
      ),
    );
    if (product.imageUrl == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: product.imageUrl!,
        width: size,
        height: size,
        // Whole product visible; transparent PNGs look best.
        fit: BoxFit.contain,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

/// Category colours for the emoji tile, blended onto the surface so they
/// are solid: the layers behind it in [Product360] must not show through.
List<Color> _tileColors(BuildContext context, Product product) {
  final tint = categoryColor(product.category);
  final base = context.colors.surface;
  final (start, end) = context.isDark ? (0.30, 0.12) : (1.0, 0.45);
  return [
    Color.alphaBlend(tint.withValues(alpha: start), base),
    Color.alphaBlend(tint.withValues(alpha: end), base),
  ];
}

/// The side of a pack: its colour, and where the product is inside the
/// square picture (0..1), so the side wall has the right size.
typedef _PackSide = ({Color color, Rect bounds});

final _packSides = <String, _PackSide>{};

/// Reads a product photo once (cached): the colour along its left and
/// right edges, a little darker, is what the side of the pack would look
/// like. Null if the photo cannot be read.
Future<_PackSide?> _photoPackSide(String url) async {
  if (_packSides[url] case final side?) return side;
  final stream = CachedNetworkImageProvider(url)
      .resolve(ImageConfiguration.empty);
  final loaded = Completer<ImageInfo?>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!loaded.isCompleted) loaded.complete(info);
    },
    onError: (_, _) {
      stream.removeListener(listener);
      if (!loaded.isCompleted) loaded.complete(null);
    },
  );
  stream.addListener(listener);
  final info = await loaded.future;
  if (info == null) return null;
  try {
    final image = info.image;
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) return null;
    final w = image.width;
    final h = image.height;
    var r = 0, g = 0, b = 0, n = 0;
    var minX = w, maxX = -1, minY = h, maxY = -1;
    bool solid(int x, int y) => data.getUint8((y * w + x) * 4 + 3) > 200;
    void add(int x, int y) {
      final i = (y * w + x) * 4;
      r += data.getUint8(i);
      g += data.getUint8(i + 1);
      b += data.getUint8(i + 2);
      n++;
    }

    // First and last solid pixel of every other row, a little inside.
    for (var y = 0; y < h; y += 2) {
      var left = 0;
      while (left < w && !solid(left, y)) {
        left++;
      }
      if (left == w) continue;
      var right = w - 1;
      while (!solid(right, y)) {
        right--;
      }
      add(math.min(left + 2, right), y);
      add(math.max(right - 2, left), y);
      minX = math.min(minX, left);
      maxX = math.max(maxX, right);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    if (n == 0) return null;
    final edge = Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
    // The photo is shown with BoxFit.contain in a square.
    final m = math.max(w, h).toDouble();
    final dx = (m - w) / 2, dy = (m - h) / 2;
    return _packSides[url] = (
      color: Color.lerp(edge, Colors.black, 0.25)!,
      bounds: Rect.fromLTRB(
        (dx + minX) / m,
        (dy + minY) / m,
        (dx + maxX + 1) / m,
        (dy + maxY + 1) / m,
      ),
    );
  } catch (_) {
    return null;
  } finally {
    info.dispose();
  }
}

/// "Live 360°" product picture: turns slowly like on a turntable. It is
/// built from thin layers of the picture stacked behind each other, so it
/// has real thickness from the side instead of being paper-thin. The inner
/// layers and a side wall are one solid colour (from the photo's edges) and
/// form the sides of the pack. The front gets darker as it turns away from
/// the light, and the floor shadow narrows.
/// With [interactive], drag sideways to turn it yourself (it starts turning
/// again after a moment).
class Product360 extends StatefulWidget {
  const Product360({
    super.key,
    required this.product,
    this.size = 72,
    this.radius = 12,
    this.interactive = false,
    this.secondsPerTurn = 8,
    this.thickness = 0.16,
  });

  final Product product;
  final double size;
  final double radius;
  final bool interactive;
  final int secondsPerTurn;

  /// Depth of the pack as a fraction of [size].
  final double thickness;

  @override
  State<Product360> createState() => _Product360State();
}

class _Product360State extends State<Product360>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.secondsPerTurn),
    // Each product starts at a different angle, so a row of them is not
    // all turning in step.
    value: (widget.product.barcode.hashCode % 1000).abs() / 1000,
  )..repeat();
  double _drag = 0; // extra turns from the student's finger
  Timer? _resume;
  _PackSide? _photoSide; // see [_photoPackSide]

  @override
  void initState() {
    super.initState();
    _loadPhotoSide();
  }

  @override
  void didUpdateWidget(Product360 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.imageUrl != widget.product.imageUrl) {
      _photoSide = null;
      _loadPhotoSide();
    }
  }

  Future<void> _loadPhotoSide() async {
    final url = widget.product.imageUrl;
    if (url == null) return;
    final side = await _photoPackSide(url);
    if (mounted && url == widget.product.imageUrl) {
      setState(() => _photoSide = side);
    }
  }

  @override
  void dispose() {
    _resume?.cancel();
    _spin.dispose();
    super.dispose();
  }

  /// Side colour and outline: from the photo, or the emoji tile's.
  _PackSide? _packSide(BuildContext context) {
    if (widget.product.imageUrl != null) return _photoSide;
    return (
      color: Color.lerp(
        _tileColors(context, widget.product).first,
        Colors.black,
        0.22,
      )!,
      bounds: const Rect.fromLTRB(0, 0, 1, 1),
    );
  }

  /// One inner layer: the outline of the picture filled with one solid
  /// colour, so together the layers look like the plain side of a pack.
  Widget _layer(Color? color) {
    final size = widget.size;
    final radius = BorderRadius.circular(widget.radius);
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: radius),
    );
    final url = widget.product.imageUrl;
    if (url == null) return tile;
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Paints the colour only where the picture is (its outline).
        color: color ?? Colors.black.withValues(alpha: 0.3),
        colorBlendMode: BlendMode.srcIn,
        placeholder: (_, _) => tile,
        errorWidget: (_, _, _) => tile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final depth = size * widget.thickness;
    // About one layer every 1.5 px, so the side looks solid.
    final layers = (depth / 1.5).round().clamp(6, 16);
    final packSide = _packSide(context);
    final face = ProductImage(
      product: widget.product,
      size: size,
      radius: widget.radius,
    );
    final layer = _layer(packSide?.color);

    Matrix4 turned(double angle) => Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(angle);

    final picture = AnimatedBuilder(
      animation: _spin,
      builder: (context, _) {
        final angle = 2 * math.pi * (_spin.value + _drag);
        final facing = math.cos(angle);
        final front = facing >= 0;
        // Layer 0 is the front, the last one the back. Positive z is away
        // from the viewer, so paint the farthest layer first and the face
        // nearest to the viewer last.
        final order = front
            ? [for (var i = layers - 1; i >= 0; i--) i]
            : [for (var i = 0; i < layers; i++) i];
        Widget at(int i, Widget child) => Transform(
          key: ValueKey(i),
          alignment: Alignment.center,
          transform: turned(angle)
            ..translateByDouble(0, 0, -depth / 2 + depth * i / (layers - 1), 1)
            // From behind, flip so the picture is not mirrored.
            ..scaleByDouble(front ? 1 : -1, 1, 1, 1),
          child: child,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final i in order.take(layers - 1)) at(i, layer),
                  if (packSide != null) _wall(angle, front, depth, packSide),
                  at(
                    order.last,
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(
                          alpha: 0.3 * (1 - facing.abs()),
                        ),
                        BlendMode.srcATop,
                      ),
                      child: face,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: size * 0.07),
            Container(
              width: size * 0.7 * (0.3 + 0.7 * facing.abs()),
              height: size * 0.07,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.45 : 0.14,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!widget.interactive) return picture;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _resume?.cancel();
        _spin.stop();
      },
      onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx / 320),
      onHorizontalDragEnd: (_) => _resume = Timer(
        const Duration(seconds: 2),
        () => mounted ? _spin.repeat() : null,
      ),
      child: picture,
    );
  }

  /// A solid panel along the visible edge of the pack, as deep as the pack.
  /// Seen exactly side-on the layers are only hairlines; this fills the
  /// gaps between them.
  Widget _wall(double angle, bool front, double depth, _PackSide side) {
    final size = widget.size;
    final b = side.bounds;
    // The right edge faces the viewer while sin(angle) > 0. From behind
    // the layers are flipped, so the picture's other edge is there.
    final rightVisible = math.sin(angle) > 0;
    final edge = (rightVisible == front ? b.right : b.left) * size - size / 2;
    return Transform(
      key: const ValueKey('wall'),
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(angle)
        ..translateByDouble(
          front ? edge : -edge,
          (b.center.dy - 0.5) * size,
          0,
          1,
        )
        ..rotateY(math.pi / 2),
      child: Container(
        width: depth,
        height: b.height * size,
        color: side.color,
      ),
    );
  }
}

/// In stock / Low / Out of stock (design principle: clear stock status).
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.product, this.showCount = true});

  final Product product;
  final bool showCount;

  @override
  Widget build(BuildContext context) => switch (product.stockStatus) {
    StockStatus.out => Pill(
      label: context.tr('Out of stock'),
      color: AppColors.error,
      icon: Icons.cancel,
    ),
    StockStatus.low => Pill(
      label: showCount
          ? context.tr('Low stock ({count})', {'count': product.stock})
          : context.tr('Low stock'),
      color: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    ),
    StockStatus.inStock => Pill(
      label: showCount
          ? context.tr('In stock ({count})', {'count': product.stock})
          : context.tr('In stock'),
      color: context.brand,
      icon: Icons.check_circle,
    ),
  };
}

class SaveFoodBadge extends StatelessWidget {
  const SaveFoodBadge({super.key});

  @override
  Widget build(BuildContext context) => Pill(
    label: context.tr('SAVE FOOD'),
    color: AppColors.accent,
    textColor: AppColors.textOnAccent,
    icon: Icons.eco,
  );
}

/// Effective price, with the normal price struck through on Save Food.
class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.product, this.large = false});

  final Product product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (large ? theme.textTheme.headlineMedium : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w700);
    if (!product.isOnSaveFood) {
      return Text(formatRM(product.priceSen), style: style);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      children: [
        Text(
          formatRM(product.saveFoodPriceSen!),
          style: style?.copyWith(color: const Color(0xFFB26A00)),
        ),
        Text(
          formatRM(product.priceSen),
          style: theme.textTheme.bodySmall?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
    this.showStockCount = true,
  });

  final Product product;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showStockCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Pressable(
      scale: 0.98,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: product.isActive ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ProductImage(product: product),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        PriceText(product: product),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            StockBadge(
                              product: product,
                              showCount: showStockCount,
                            ),
                            if (product.isOnSaveFood) const SaveFoodBadge(),
                            if (!product.isActive)
                              Pill(
                                label: context.tr('Disabled'),
                                color: Colors.grey,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small card for the "Popular now" and Save Food carousels on the student
/// home screen. Save Food deals get an amber border and their expiry.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
      child: Pressable(
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: product.isOnSaveFood
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.accent, width: 1.5),
                )
              : null,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Product360(product: product, size: 64)),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  PriceText(product: product),
                  if (product.isOnSaveFood && product.expiryDate != null)
                    Text(
                      expiryLabel(product.expiryDate!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.tr('Less'),
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: context.tr('More'),
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) => switch (order.status) {
    'pending' => Pill(
      label: context.tr('Pending'),
      color: Color(0xFF1565C0),
      icon: Icons.schedule,
    ),
    'ready' => Pill(
      label: context.tr('Ready for pickup'),
      color: AppColors.accent,
      textColor: AppColors.textOnAccent,
      icon: Icons.shopping_bag,
    ),
    'collected' => Pill(
      label: context.tr('Collected'),
      color: context.brand,
      icon: Icons.check_circle,
    ),
    _ => Pill(
      label: context.tr(
        order.wasNotCollected ? 'Cancelled: not collected' : 'Cancelled',
      ),
      color: AppColors.error,
      icon: Icons.cancel,
    ),
  };
}
