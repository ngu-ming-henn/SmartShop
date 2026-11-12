import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/errors.dart';
import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

/// The account exists in Firebase Auth but `users/{uid}` does not (e.g. an
/// account made in the Firebase Console). Students finish their profile
/// here; staff tap "Join as staff" (no Student ID). Who may join as staff is
/// checked by the security rules: emails an admin added in More -> Staff
/// accounts, or the very first admin.
class ProfileMissingScreen extends StatefulWidget {
  const ProfileMissingScreen({super.key});

  @override
  State<ProfileMissingScreen> createState() => _ProfileMissingScreenState();
}

class _ProfileMissingScreenState extends State<ProfileMissingScreen> {
  final _form = GlobalKey<FormState>();
  late final _user = context.read<AuthProvider>().firebaseUser;
  late final _name = TextEditingController(text: _user?.displayName ?? '');
  final _studentId = TextEditingController();
  bool _busy = false;
  String? _staffError;

  /// Console-made accounts are usually staff; student emails pick student.
  late bool _staff = !(_user?.email ?? '').toLowerCase().contains('student');

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().createMissingStudentProfile(
        name: _name.text,
        studentId: _studentId.text,
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinAsStaff() async {
    if (validateName(_name.text) != null) {
      setState(() => _staffError = validateName(_name.text));
      return;
    }
    setState(() {
      _busy = true;
      _staffError = null;
    });
    try {
      // On success the app opens the Staff Dashboard by itself.
      await context.read<AuthProvider>().joinAsStaff(name: _name.text);
    } catch (e) {
      if (mounted) setState(() => _staffError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Finish your profile')),
        actions: [
          TextButton(
            onPressed: auth.signOut,
            child: Text(
              context.tr('Log out'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr('Signed in as {email}', {'email': _user?.email ?? ''}),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('Your SmartShop profile was not found. Who are you?'),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _staff ? _staffSteps(context) : _studentForm(context),
          ),
        ],
      ),
    );
  }

  Widget _studentForm(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        key: const ValueKey('student'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            decoration: InputDecoration(
              labelText: context.tr('Full name'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: validateName,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _studentId,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: context.tr('Student ID'),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            validator: validateStudentId,
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: context.tr('Create student profile'),
            icon: Icons.check,
            busy: _busy,
            onPressed: _createStudent,
          ),
        ],
      ),
    );
  }

  Widget _staffSteps(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('staff'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr('Tap the button to open the staff side of SmartShop.')),
        const SizedBox(height: 14),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.tr('Your name'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: context.tr('Join as staff'),
          icon: Icons.storefront,
          busy: _busy,
          onPressed: _joinAsStaff,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _staffError == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Card(
                    color: context.colors.errorContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: context.colors.onErrorContainer,
                      ),
                      title: Text(
                        _staffError!,
                        style: TextStyle(
                          color: context.colors.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: context.brand),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('Good to know'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${context.tr('No Student ID needed for staff.')}\n'
                  '• ${context.tr('The first staff to join becomes the admin.')}\n'
                  '• ${context.tr('After that, an admin adds new staff emails in More → Staff accounts.')}',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
