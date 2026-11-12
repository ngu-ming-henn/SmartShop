import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../l10n/strings.dart';
import '../../widgets/brand.dart';

/// Opening animation (about 3.4 s): the SmartShop logo pops in inside a
/// loading ring, the tick draws, then the name and the UTS crest fade in.
/// The router leaves this screen once [gate] is finished and the login
/// state is known; until then the ring keeps spinning.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.gate});
  final SplashGate gate;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  Animation<double> _part(
    double begin,
    double end, [
    Curve curve = Curves.easeOut,
  ]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: curve),
  );

  late final _logoIn = _part(0, 0.22, Curves.easeOutBack);
  late final _ring = _part(0.06, 0.85, Curves.easeInOutCubic);
  late final _tick = _part(0.28, 0.46, Curves.easeOutCubic);
  late final _spark = _part(0.42, 0.62, Curves.elasticOut);
  late final _title = _part(0.34, 0.58, Curves.easeOutCubic);
  late final _tagline = _part(0.46, 0.70, Curves.easeOutCubic);
  late final _footer = _part(0.58, 0.85, Curves.easeOutCubic);
  late final _pulse = _part(0.85, 1, Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    if (widget.gate.done) {
      // Seen already (e.g. loading the profile after login): no replay.
      _intro.value = 1;
      _spin.repeat();
    } else {
      _intro.addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _spin.repeat();
        widget.gate.finish();
      });
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  Widget _fadeUp(Animation<double> a, Widget child) => Opacity(
    opacity: a.value.clamp(0, 1),
    child: Transform.translate(
      offset: Offset(0, 16 * (1 - a.value)),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _spin]),
            builder: (context, _) {
              final pulse = 1 + 0.06 * math.sin(math.pi * _pulse.value);
              return Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 176,
                          child: CustomPaint(
                            painter: _RingPainter(
                              progress: _ring.value,
                              spinning: _intro.isCompleted,
                              spin: _spin.value,
                            ),
                            child: Center(
                              child: Opacity(
                                opacity: _logoIn.value.clamp(0, 1),
                                child: Transform.scale(
                                  scale: (0.4 + 0.6 * _logoIn.value) * pulse,
                                  child: SmartShopLogo(
                                    size: 108,
                                    tick: _tick.value,
                                    spark: _spark.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _fadeUp(
                          _title,
                          Text(
                            'SmartShop',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _fadeUp(
                          _tagline,
                          Text(
                            context.tr('Pre-order  ·  QR pickup  ·  Go green'),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 40 + MediaQuery.paddingOf(context).bottom,
                    child: _fadeUp(
                      _footer,
                      Column(
                        children: [
                          const UtsCrest(size: 52),
                          const SizedBox(height: 10),
                          Text(
                            context.tr('University of Technology Sarawak'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            context.tr('UTS Koperasi'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Loading ring around the logo: fills once during the intro (with a gold
/// head), then spins while the app is still loading.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.spinning,
    required this.spin,
  });

  final double progress;
  final bool spinning;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final double start;
    final double sweep;
    if (spinning) {
      start = -math.pi / 2 + 2 * math.pi * spin;
      sweep = math.pi / 2;
    } else {
      start = -math.pi / 2;
      sweep = 2 * math.pi * progress;
    }
    if (sweep <= 0) return;
    canvas.drawArc(rect, start, sweep, false, arc);

    final head = start + sweep;
    canvas.drawCircle(
      center + Offset(math.cos(head), math.sin(head)) * radius,
      stroke * 1.3,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.spinning != spinning || old.spin != spin;
}
