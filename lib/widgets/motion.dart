import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small animations used around the app.

/// Delay for item [index] in a list, so items appear one after another
/// (capped, so long lists do not wait).
Duration stagger(int index, {int stepMs = 60}) =>
    Duration(milliseconds: stepMs * math.min(index, 8));

/// Fades and slides [child] up into place when it first appears.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 24,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Shrinks [child] a little while it is pressed. Taps still reach the
/// child's own InkWell / buttons.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.96});
  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Counts up to [value] when it appears, and animates when it changes.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style, this.format});
  final int value;
  final TextStyle? style;
  final String Function(int value)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final shown = v.round();
        return Text(format?.call(shown) ?? '$shown', style: style);
      },
    );
  }
}

/// Floats [child] gently up and down (empty-state icons).
class Floating extends StatefulWidget {
  const Floating({super.key, required this.child, this.distance = 6});
  final Widget child;
  final double distance;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          widget.distance * Curves.easeInOut.transform(_controller.value) -
              widget.distance / 2,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
