import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/password.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/animated_tick.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/password_strength.dart';

/// Current password -> new password (same rules as registration, with the
/// strength line) -> confirm. Shows an animated tick when it is done.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context.read<AuthViewModel>().changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Change password'))),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _done ? _doneView(context) : _formView(context),
      ),
    );
  }

  Widget _doneView(BuildContext context) {
    return Center(
      key: const ValueKey('done'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedTick(size: 110),
            const SizedBox(height: 20),
            Text(
              context.tr('Password changed'),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('Use your new password next time you log in.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: context.tr('Done'),
              icon: Icons.check,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formView(BuildContext context) {
    Widget eye() => IconButton(
      tooltip: context.tr(_hide ? 'Show password' : 'Hide password'),
      icon: Icon(
        _hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: () => setState(() => _hide = !_hide),
    );

    return Form(
      key: _form,
      child: ListView(
        key: const ValueKey('form'),
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.shield_outlined, color: context.brand),
              title: Text(context.tr('For your safety')),
              subtitle: Text(context.tr('Enter your current password first.')),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _current,
            obscureText: _hide,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: context.tr('Current password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: eye(),
            ),
            validator: (v) => (v ?? '').isEmpty
                ? context.tr('Enter your current password')
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _new,
            obscureText: _hide,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: context.tr('New password'),
              prefixIcon: const Icon(Icons.key_outlined),
            ),
            validator: (v) {
              final problem = validateNewPassword(v);
              if (problem != null) return problem;
              return v == _current.text
                  ? context.tr('Use a different password from the current one')
                  : null;
            },
          ),
          const SizedBox(height: 10),
          PasswordStrengthMeter(controller: _new),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: Listenable.merge([_new, _confirm]),
            builder: (context, _) {
              final matches =
                  _confirm.text.isNotEmpty && _confirm.text == _new.text;
              return TextFormField(
                controller: _confirm,
                obscureText: _hide,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: context.tr('Confirm new password'),
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: AnimatedScale(
                    scale: matches ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Icon(Icons.check_circle, color: context.eco),
                  ),
                ),
                validator: (v) => v != _new.text
                    ? context.tr('Passwords do not match')
                    : null,
              );
            },
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: context.tr('Update password'),
            icon: Icons.lock_reset,
            busy: _busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
