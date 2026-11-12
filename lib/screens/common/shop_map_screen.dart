import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Where to collect: an OpenStreetMap map (free, no API key) with our own
/// pin on the koperasi, opening hours, and buttons that open Google Maps
/// for directions or Street View.
class ShopMapScreen extends StatefulWidget {
  const ShopMapScreen({super.key});

  @override
  State<ShopMapScreen> createState() => _ShopMapScreenState();
}

class _ShopMapScreenState extends State<ShopMapScreen> {
  static const _shop = LatLng(ShopLocation.latitude, ShopLocation.longitude);
  final _map = MapController();

  Future<void> _open(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      showSnack(context, context.tr('Could not open Google Maps.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = ShopLocation.isOpen(DateTime.now());
    String hour(int h) => formatTime(DateTime(2000, 1, 1, h));

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Find the koperasi'))),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: const MapOptions(
                    initialCenter: _shop,
                    initialZoom: 17.5,
                    maxZoom: 19,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ssc.smartshop',
                      tileBuilder: context.isDark ? darkModeTileBuilder : null,
                    ),
                    const MarkerLayer(
                      markers: [
                        Marker(
                          point: _shop,
                          width: 90,
                          height: 96,
                          alignment: Alignment.topCenter,
                          child: _ShopPin(),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () =>
                              _open('https://openstreetmap.org/copyright'),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: context.tr('Back to the koperasi'),
                    onPressed: () => _map.move(_shop, 17.5),
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          FadeSlideIn(
            child: Material(
              elevation: 8,
              color: context.colors.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const SmartShopLogo(size: 44, shadow: false),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ShopLocation.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  ShopLocation.address,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Pill(
                            label: context.tr(open ? 'Open now' : 'Closed'),
                            color: open ? context.eco : AppColors.error,
                            icon: open ? Icons.storefront : Icons.lock_clock,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr('Daily {open} – {close}', {
                                'open': hour(AppRules.openingHour),
                                'close': hour(AppRules.closingHour),
                              }),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          'Ground floor, under the stairs. Show your pickup '
                          'QR at the counter.',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GradientButton(
                              label: context.tr('Directions'),
                              icon: Icons.directions_walk,
                              onPressed: () =>
                                  _open(ShopLocation.directionsUrl),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                              ),
                              onPressed: () =>
                                  _open(ShopLocation.streetViewUrl),
                              icon: const Icon(Icons.streetview),
                              label: Text(context.tr('Street View')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The SmartShop logo on a pin that bobs, with a pulsing ring on the spot.
class _ShopPin extends StatelessWidget {
  const _ShopPin();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        const Positioned(bottom: 0, child: _PulseRing()),
        Floating(
          distance: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SmartShopLogo(size: 46),
              CustomPaint(
                size: const Size(16, 12),
                painter: _PinTip(AppColors.primaryBright),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinTip extends CustomPainter {
  _PinTip(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTip old) => old.color != color;
}

class _PulseRing extends StatefulWidget {
  const _PulseRing();

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: 12 + 40 * t,
          height: (12 + 40 * t) * 0.45,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(40),
            color: AppColors.primaryBright.withValues(alpha: 0.35 * (1 - t)),
          ),
        );
      },
    );
  }
}
