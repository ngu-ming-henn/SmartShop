import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_tick.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';

/// Firebase emails a secure reset link (free Spark plan). After sending,
/// an animated tick confirms it and the student can resend after 30 s.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendAfter = 30;

  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  bool _busy = false;
  bool _sent = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    // The form is gone on the "sent" view; the email was checked already.
    if (!(_form.currentState?.validate() ?? true)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().sendPasswordReset(_email.text);
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown--);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: context.tr('Reset your password'),
      subtitle: context.tr(
        'We will email you a secure link to set a new password.',
      ),
      headerIcon: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.lock_reset, color: Colors.white, size: 40),
      ),
      // No clipping, so the button shadows stay soft.
      child: AnimatedSize(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _sent ? _sentView(context) : _formView(context),
        ),
      ),
    );
  }

  Widget _formView(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _form,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Forgot your password?'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('Enter the email you registered with.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: context.tr('Email'),
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: validateEmail,
            onFieldSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: context.tr('Send reset link'),
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  Widget _sentView(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      key: const ValueKey('sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AnimatedTick(size: 96)),
        const SizedBox(height: 16),
        Text(
          context.tr('Check your email'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('We sent a reset link to'),
          textAlign: TextAlign.center,
          style: muted,
        ),
        Text(
          _email.text.trim(),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: context.brand,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        for (final (i, step) in const [
          'Open the email from SmartShop (check Spam too).',
          'Tap the link and choose a new password: 8+ characters with a number and a symbol.',
          'Come back here and log in.',
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: context.colors.secondaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr(step), style: muted)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        GradientButton(
          label: context.tr('Back to log in'),
          icon: Icons.login,
          onPressed: () => context.pop(),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => setState(() => _sent = false),
              child: Text(context.tr('Use another email')),
            ),
            TextButton(
              onPressed: _cooldown > 0 || _busy ? null : _send,
              child: Text(
                _cooldown > 0
                    ? context.tr('Resend in {s}s', {'s': _cooldown})
                    : context.tr('Resend email'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
