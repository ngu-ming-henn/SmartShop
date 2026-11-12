import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../auth/register_screen.dart';

/// Edit name, Student / Staff ID and phone number. The email is the login,
/// so it is shown but cannot be changed here.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _user = context.read<AuthProvider>().user!;
  late final _name = TextEditingController(text: _user.name);
  late final _studentId = TextEditingController(text: _user.studentId);
  late final _phone = TextEditingController(text: _user.phone);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().updateProfile(
        name: _name.text,
        studentId: _studentId.text,
        phone: _phone.text,
      );
      if (!mounted) return;
      showSnack(context, context.tr('Profile updated.'));
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = <Widget>[
      TextFormField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: context.tr('Full name'),
          prefixIcon: const Icon(Icons.person_outline),
        ),
        validator: validateName,
      ),
      TextFormField(
        controller: _studentId,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: context.tr(_user.isStaff ? 'Staff ID' : 'Student ID'),
          prefixIcon: const Icon(Icons.badge_outlined),
        ),
        validator: validateStudentId,
      ),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: context.tr('Phone number (optional)'),
          hintText: '012-345 6789',
          prefixIcon: const Icon(Icons.phone_outlined),
        ),
        validator: validatePhone,
      ),
      TextFormField(
        initialValue: _user.email,
        enabled: false,
        decoration: InputDecoration(
          labelText: context.tr('Email'),
          prefixIcon: const Icon(Icons.alternate_email),
          suffixIcon: const Icon(Icons.lock_outline, size: 18),
          helperText: context.tr(
            'Your email is your login and cannot be changed.',
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Edit profile'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ListenableBuilder(
                listenable: _name,
                builder: (context, _) {
                  final name = _name.text.trim();
                  return CircleAvatar(
                    radius: 40,
                    backgroundColor: context.colors.secondaryContainer,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: context.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < fields.length; i++)
              FadeSlideIn(
                delay: stagger(i),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: fields[i],
                ),
              ),
            const SizedBox(height: 10),
            GradientButton(
              label: context.tr('Save changes'),
              icon: Icons.check,
              busy: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
