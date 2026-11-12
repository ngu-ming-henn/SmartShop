import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../l10n/strings.dart';
import '../../services/location_service.dart';
import '../../viewmodels/shop_map_view_model.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Where to collect: an OpenStreetMap map (free, no API key) with our own
/// pin on the koperasi, your GPS position, how far you are, the nearest car
/// or motorcycle park, and buttons that open Google Maps for directions or
/// Street View. The logic is in [ShopMapViewModel] (MVVM).
class ShopMapScreen extends StatefulWidget {
  const ShopMapScreen({super.key, this.locationSource});

  /// Tests pass a fake position; the app uses the phone's GPS.
  final LocationSource? locationSource;

  @override
  State<ShopMapScreen> createState() => _ShopMapScreenState();
}

class _ShopMapScreenState extends State<ShopMapScreen>
    with WidgetsBindingObserver {
  static const _shop = ShopMapViewModel.shop;
  final _map = MapController();
  late final ShopMapViewModel _vm;
  bool _mapReady = false;
  bool _framed = false; // zoomed to show you and the koperasi once

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm = ShopMapViewModel(widget.locationSource ?? GpsLocationSource())
      ..addListener(_frameOnFirstFix)
      ..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.removeListener(_frameOnFirstFix);
    _vm.dispose();
    super.dispose();
  }

  /// Back from the phone settings (location turned on / allowed): try again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_vm.access == LocationAccess.serviceOff ||
            _vm.access == LocationAccess.deniedForever)) {
      _vm.start();
    }
  }

  void _frameOnFirstFix() {
    final me = _vm.me;
    if (me == null || _framed || !_mapReady) return;
    _framed = true;
    // Far away (e.g. at home): keep the koperasi in view.
    if ((_vm.metersToShop ?? 0) > 20000) return;
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: [me, _shop],
        padding: const EdgeInsets.fromLTRB(60, 90, 60, 60),
        maxZoom: 18,
      ),
    );
  }

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
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Find the koperasi'))),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => Column(
          children: [
            Expanded(child: _mapView(context)),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: FadeSlideIn(child: _panel(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapView(BuildContext context) {
    final me = _vm.me;
    final nearby = _vm.nearby;
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _shop,
            initialZoom: 17.5,
            maxZoom: 19,
            onMapReady: () {
              _mapReady = true;
              _frameOnFirstFix();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ssc.smartshop',
              tileBuilder: context.isDark ? darkModeTileBuilder : null,
            ),
            if (me != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [me, _shop],
                    color: AppColors.primaryBright,
                    strokeWidth: 4,
                    pattern: StrokePattern.dashed(segments: const [10, 8]),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final (i, n) in nearby.indexed)
                  Marker(
                    point: LatLng(n.spot.latitude, n.spot.longitude),
                    width: 36,
                    height: 36,
                    child: _ParkingMarker(kind: n.spot.kind, nearest: i == 0),
                  ),
                const Marker(
                  point: _shop,
                  width: 90,
                  height: 96,
                  alignment: Alignment.topCenter,
                  child: _ShopPin(),
                ),
                if (me != null)
                  Marker(
                    point: me,
                    width: 48,
                    height: 48,
                    child: const _MeDot(),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => _open('https://openstreetmap.org/copyright'),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: null,
                tooltip: context.tr('Show me'),
                onPressed: me == null ? _vm.start : () => _map.move(me, 18),
                child: Icon(me == null ? Icons.gps_not_fixed : Icons.gps_fixed),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: null,
                tooltip: context.tr('Back to the koperasi'),
                onPressed: () => _map.move(_shop, 17.5),
                child: const Icon(Icons.storefront),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context) {
    final theme = Theme.of(context);
    final open = ShopLocation.isOpen(DateTime.now());
    String hour(int h) => formatTime(DateTime(2000, 1, 1, h));
    return Material(
      elevation: 8,
      color: context.colors.surface,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              const SizedBox(height: 8),
              _DistanceRow(vm: _vm),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'Ground floor, under the stairs. Show your pickup '
                  'QR at the counter.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              _ParkingFinder(
                vm: _vm,
                onPick: (spot) =>
                    _map.move(LatLng(spot.latitude, spot.longitude), 18),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: context.tr('Directions'),
                      icon: Icons.directions_walk,
                      onPressed: () => _open(ShopLocation.directionsUrl),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: () => _open(ShopLocation.streetViewUrl),
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
    );
  }
}

/// "350 m away · about 5 min walk", or what to do when location is off.
class _DistanceRow extends StatelessWidget {
  const _DistanceRow({required this.vm});
  final ShopMapViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiet = theme.textTheme.bodySmall;
    Widget line(
      IconData icon,
      String text, {
      String? action,
      VoidCallback? onAction,
    }) => Row(
      children: [
        Icon(icon, size: 20, color: context.brand),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: quiet)),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action)),
      ],
    );

    if (vm.access == null ||
        (vm.access == LocationAccess.granted && !vm.hasFix)) {
      return Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.brand,
            ),
          ),
          const SizedBox(width: 10),
          Text(context.tr('Finding your location…'), style: quiet),
        ],
      );
    }
    return switch (vm.access!) {
      LocationAccess.granted => Row(
        children: [
          Icon(Icons.directions_walk, size: 20, color: context.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('{distance} away · about {minutes} min walk', {
                'distance': formatDistance(vm.metersToShop!),
                'minutes': vm.minutesToShop,
              }),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      LocationAccess.denied => line(
        Icons.location_searching,
        context.tr('Allow location to see how far you are.'),
        action: context.tr('Allow'),
        onAction: vm.start,
      ),
      LocationAccess.deniedForever => line(
        Icons.location_disabled,
        context.tr('Location is blocked for SmartShop.'),
        action: context.tr('Open settings'),
        onAction: vm.openSettings,
      ),
      LocationAccess.serviceOff => line(
        Icons.location_off,
        context.tr('Location is off.'),
        action: context.tr('Turn on'),
        onAction: vm.openSettings,
      ),
    };
  }
}

/// Nearest car or motorcycle parks, nearest first; tap one to see it.
class _ParkingFinder extends StatelessWidget {
  const _ParkingFinder({required this.vm, required this.onPick});
  final ShopMapViewModel vm;
  final ValueChanged<ParkingSpot> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nearby = vm.nearby;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('Nearest parking'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ParkingKind>(
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(
              value: ParkingKind.car,
              icon: const Icon(Icons.local_parking, size: 18),
              label: Text(context.tr('Car')),
            ),
            ButtonSegment(
              value: ParkingKind.motorcycle,
              icon: const Icon(Icons.two_wheeler, size: 18),
              label: Text(context.tr('Motorcycle')),
            ),
          ],
          selected: {vm.kind},
          onSelectionChanged: (s) => vm.showKind(s.first),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: nearby.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _SpotCard(
              spot: nearby[i].spot,
              meters: nearby[i].meters,
              nearest: i == 0,
              onTap: () => onPick(nearby[i].spot),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(
            vm.hasFix
                ? 'Measured from you. Parking from OpenStreetMap.'
                : 'Measured from the koperasi until your location is found.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

String _parkingName(BuildContext context, ParkingSpot spot) => context.tr(
  spot.kind == ParkingKind.car ? 'Car park {n}' : 'Motorcycle park {n}',
  {'n': spot.number},
);

class _SpotCard extends StatelessWidget {
  const _SpotCard({
    required this.spot,
    required this.meters,
    required this.nearest,
    required this.onTap,
  });

  final ParkingSpot spot;
  final double meters;
  final bool nearest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Pressable(
      child: Material(
        color: nearest ? brand.withValues(alpha: 0.10) : context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: nearest ? brand : context.colors.outlineVariant,
            width: nearest ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  spot.kind == ParkingKind.car
                      ? Icons.local_parking
                      : Icons.two_wheeler,
                  color: brand,
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _parkingName(context, spot),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      nearest
                          ? '${formatDistance(meters)} · ${context.tr('Nearest')}'
                          : formatDistance(meters),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: nearest ? brand : null,
                        fontWeight: nearest ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A parking spot on the map; the nearest one is filled in.
class _ParkingMarker extends StatelessWidget {
  const _ParkingMarker({required this.kind, required this.nearest});
  final ParkingKind kind;
  final bool nearest;

  @override
  Widget build(BuildContext context) {
    const brand = AppColors.primaryBright;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: nearest ? brand : Colors.white,
        border: Border.all(color: nearest ? Colors.white : brand, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(
        kind == ParkingKind.car ? Icons.local_parking : Icons.two_wheeler,
        size: 20,
        color: nearest ? Colors.white : brand,
      ),
    );
  }
}

/// You: a blue dot with a soft pulse, like other map apps.
class _MeDot extends StatefulWidget {
  const _MeDot();

  @override
  State<_MeDot> createState() => _MeDotState();
}

class _MeDotState extends State<_MeDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1A73E8);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 18 + 30 * t,
              height: 18 + 30 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue.withValues(alpha: 0.30 * (1 - t)),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: blue,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
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
