import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';

String? validateEmail(String? v) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return AppStrings.tr('Enter your email');
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
    return AppStrings.tr('Enter a valid email');
  }
  return null;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      // On success the router redirects by role (student -> /home, staff -> /staff).
      await context.read<AuthViewModel>().signIn(_email.text, _password.text);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() {
    final email = _email.text.trim();
    context.push(
      Uri(
        path: '/forgot-password',
        queryParameters: email.isEmpty ? null : {'email': email},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      title: context.tr('Welcome back 👋'),
      subtitle: context.tr(
        'Log in to pre-order and skip the queue at UTS Koperasi.',
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.tr('New student?')),
          TextButton(
            onPressed: () => context.push('/register'),
            child: Text(
              context.tr('Create an account'),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('Log in'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr('Email'),
                  hintText: 'you@student.uts.edu.my',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: context.tr('Password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: context.tr(
                      _hide ? 'Show password' : 'Hide password',
                    ),
                    icon: Icon(
                      _hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty
                    ? context.tr('Enter your password')
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: Text(context.tr('Forgot password?')),
                ),
              ),
              const SizedBox(height: 4),
              GradientButton(
                label: context.tr('Log in'),
                icon: Icons.login,
                busy: _busy,
                onPressed: _login,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
