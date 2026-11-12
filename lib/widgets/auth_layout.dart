import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import 'brand.dart';

/// Layout for the screens before login: a curved navy-to-blue header with
/// the SmartShop logo and the UTS crest, and the form on a white card that
/// slides up into view.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.headerIcon,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  /// Replaces the SmartShop logo in the header.
  final Widget? headerIcon;

  /// Shown under the card, e.g. "New student? Create an account".
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              ClipPath(
                clipper: _CurvedBottom(),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                      ),
                      padding: EdgeInsets.fromLTRB(20, top + 8, 20, 84),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (showBack)
                                const BackButton(color: Colors.white)
                              else
                                const SizedBox(height: 48),
                              const Spacer(),
                              const _UtsBadge(),
                            ],
                          ),
                          const SizedBox(height: 12),
                          headerIcon ?? const SmartShopLogo(size: 76),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(right: -50, top: -40, child: _Bubble(170)),
                    const Positioned(
                      left: -40,
                      bottom: 10,
                      child: _Bubble(110),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -56),
                child: _SlideUp(
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 18),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 12),
                        footer!,
                      ],
                      const SizedBox(height: 20),
                      Text(
                        context.tr(
                          'University of Technology Sarawak · UTS Koperasi',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// UTS crest + name, top right of the header.
class _UtsBadge extends StatelessWidget {
  const _UtsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UtsCrest(size: 30),
          SizedBox(width: 8),
          Text(
            'UTS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.size);
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.07),
    ),
  );
}

/// Fades the card in and slides it up once, when the screen opens.
class _SlideUp extends StatelessWidget {
  const _SlideUp({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 40 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _CurvedBottom extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 48)
    ..quadraticBezierTo(
      size.width / 2,
      size.height + 4,
      size.width,
      size.height - 48,
    )
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(_CurvedBottom oldClipper) => false;
}
