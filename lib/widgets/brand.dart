import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';

/// The SmartShop logo: a shopping bag with a "ready for pickup" tick and a
/// gold spark, on a navy-to-blue rounded square. It is the same drawing as
/// the Android launcher icon (res/drawable/ic_launcher_foreground.xml).
class SmartShopLogo extends StatelessWidget {
  const SmartShopLogo({
    super.key,
    this.size = 72,
    this.tick = 1,
    this.spark = 1,
    this.shadow = true,
  });

  final double size;

  /// How much of the tick is drawn, 0 to 1 (used by the opening animation).
  final double tick;

  /// Size of the gold spark, 0 to 1.
  final double spark;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: size * 0.015,
        ),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: Semantics(
        label: context.tr('SmartShop logo'),
        image: true,
        child: CustomPaint(
          painter: _LogoPainter(tick: tick, spark: spark),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.tick, required this.spark});
  final double tick;
  final double spark;

  @override
  void paint(Canvas canvas, Size size) {
    // Same 108-unit grid as the Android adaptive icon, which shows the
    // middle 72 units.
    canvas.scale(size.width / 72);
    canvas.translate(-18, -18);

    final navy = Paint()..color = AppColors.primary;
    final body = Path()
      ..moveTo(40, 45)
      ..lineTo(68, 45)
      ..quadraticBezierTo(71, 45, 71.3, 48)
      ..lineTo(73.7, 73)
      ..quadraticBezierTo(74, 77, 70, 77)
      ..lineTo(38, 77)
      ..quadraticBezierTo(34, 77, 34.3, 73)
      ..lineTo(36.7, 48)
      ..quadraticBezierTo(37, 45, 40, 45)
      ..close();
    canvas.drawPath(body, Paint()..color = Colors.white);
    final handle = Path()
      ..moveTo(46, 51)
      ..lineTo(46, 44)
      ..arcToPoint(const Offset(62, 44), radius: const Radius.circular(8))
      ..lineTo(62, 51);
    canvas.drawPath(
      handle,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(46, 51), 1.8, navy);
    canvas.drawCircle(const Offset(62, 51), 1.8, navy);

    if (tick > 0) {
      final tickPath = Path()
        ..moveTo(45, 63)
        ..lineTo(51, 69)
        ..lineTo(63, 57);
      final paint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final metric in tickPath.computeMetrics()) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * tick.clamp(0, 1)),
          paint,
        );
      }
    }

    if (spark > 0) {
      canvas.save();
      canvas.translate(70, 35);
      canvas.scale(spark);
      final star = Path()
        ..moveTo(0, -5)
        ..quadraticBezierTo(0.8, -0.8, 5, 0)
        ..quadraticBezierTo(0.8, 0.8, 0, 5)
        ..quadraticBezierTo(-0.8, 0.8, -5, 0)
        ..quadraticBezierTo(-0.8, -0.8, 0, -5)
        ..close();
      canvas.drawPath(star, Paint()..color = AppColors.accent);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.tick != tick || old.spark != spark;
}

/// University of Technology Sarawak crest in a white circle.
class UtsCrest extends StatelessWidget {
  const UtsCrest({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: size * 0.2,
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/uts_logo.png',
        semanticLabel: 'University of Technology Sarawak',
      ),
    );
  }
}

/// Main action button on the screens before login: navy-to-blue, with a
/// spinner while [busy].
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final radius = BorderRadius.circular(16);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: onPressed == null && !busy ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBright.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 56,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: busy
                      ? const SizedBox.square(
                          key: ValueKey('busy'),
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          key: const ValueKey('label'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: Colors.white),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
