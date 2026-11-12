import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// "Done" animation: a circle draws itself, then a tick, with a small
/// bounce. Plays once when it first appears.
class AnimatedTick extends StatefulWidget {
  const AnimatedTick({super.key, this.size = 96, this.color = AppColors.eco});
  final double size;
  final Color color;

  @override
  State<AnimatedTick> createState() => _AnimatedTickState();
}

class _AnimatedTickState extends State<AnimatedTick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
  );
  late final Animation<double> _circle = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.55, curve: Curves.easeInOut),
  );
  late final Animation<double> _tick = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Transform.scale(
        scale: 0.6 + 0.4 * _scale.value,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _TickPainter(
            circle: _circle.value,
            tick: _tick.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({required this.circle, required this.tick, required this.color});
  final double circle;
  final double tick;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);
    final stroke = s * 0.07;
    canvas.drawCircle(
      center,
      s / 2 * circle,
      Paint()..color = color.withValues(alpha: 0.12),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: s / 2 - stroke / 2),
      -math.pi / 2,
      2 * math.pi * circle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    if (tick <= 0) return;
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.67)
      ..lineTo(s * 0.73, s * 0.37);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * tick), paint);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.circle != circle || old.tick != tick || old.color != color;
}
