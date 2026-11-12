import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/password.dart';
import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/password_strength.dart';
import 'login_screen.dart';

String? validateStudentId(String? v) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return AppStrings.tr('Enter your Student ID');
  if (!RegExp(r'^[A-Za-z0-9]{5,20}$').hasMatch(value)) {
    return AppStrings.tr('Letters and numbers only, e.g. BCS22110001');
  }
  return null;
}

String? validateName(String? v) =>
    (v?.trim().length ?? 0) < 2 ? AppStrings.tr('Enter your name') : null;

/// Optional; Malaysian numbers like 012-345 6789 or +60 12 345 6789.
String? validatePhone(String? v) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return null;
  final digits = value.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\+?\d{9,15}$').hasMatch(digits)) {
    return AppStrings.tr('Enter a valid phone number, e.g. 012-345 6789');
  }
  return null;
}

/// Students self-register. Staff accounts are made in the Firebase Console.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _studentId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _staff = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _studentId, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().register(
        name: _name.text,
        email: _email.text,
        studentId: _staff ? '' : _studentId.text,
        password: _password.text,
        asStaff: _staff,
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      showBack: true,
      title: context.tr('Create your account'),
      subtitle: context.tr('For UTS students and koperasi staff.'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.school_outlined),
                  label: Text(context.tr('Student')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(context.tr('Koperasi staff')),
                ),
              ],
              selected: {_staff},
              onSelectionChanged: (s) => setState(() => _staff = s.first),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _staff
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        context.tr(
                          'No Student ID needed. An admin must add your '
                          'email first (the very first staff becomes the admin).',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('Your details'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: context.tr('Full name'),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: validateName,
            ),
            if (!_staff) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _studentId,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr('Student ID'),
                  hintText: 'BCS22110001',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: validateStudentId,
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: context.tr('Email'),
                hintText: 'you@student.uts.edu.my',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 22),
            Text(
              context.tr('Password'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
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
              validator: validateNewPassword,
            ),
            const SizedBox(height: 10),
            PasswordStrengthMeter(controller: _password),
            const SizedBox(height: 14),
            ListenableBuilder(
              listenable: Listenable.merge([_password, _confirm]),
              builder: (context, _) {
                final matches =
                    _confirm.text.isNotEmpty && _confirm.text == _password.text;
                return TextFormField(
                  controller: _confirm,
                  obscureText: _hide,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  decoration: InputDecoration(
                    labelText: context.tr('Confirm password'),
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                        child: child,
                      ),
                      child: matches
                          ? Icon(
                              Icons.check_circle,
                              key: ValueKey('match'),
                              color: context.eco,
                            )
                          : const SizedBox.shrink(key: ValueKey('no')),
                    ),
                  ),
                  validator: (v) => v != _password.text
                      ? context.tr('Passwords do not match')
                      : null,
                );
              },
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: context.tr(
                _staff ? 'Create staff account' : 'Create account',
              ),
              icon: Icons.person_add_alt_1,
              busy: _busy,
              onPressed: _register,
            ),
          ],
        ),
      ),
    );
  }
}
