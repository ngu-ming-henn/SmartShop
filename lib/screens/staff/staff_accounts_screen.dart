import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/staff/staff_accounts_view_model.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';

/// Admins add the emails of new koperasi staff. Those people can then tap
/// "Join as staff" in the app (no Firebase Console needed).
/// Data and actions: [StaffAccountsViewModel].
class StaffAccountsScreen extends StatefulWidget {
  const StaffAccountsScreen({super.key});

  @override
  State<StaffAccountsScreen> createState() => _StaffAccountsScreenState();
}

class _StaffAccountsScreenState extends State<StaffAccountsScreen> {
  StaffAccountsViewModel get _vm => context.read<StaffAccountsViewModel>();

  Future<void> _add() async {
    final form = GlobalKey<FormState>();
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Add staff')),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Type the email the new staff will log in with.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.tr('Email'),
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
                validator: validateEmail,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(context.tr('Add')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _vm.invite(email.text);
      if (mounted) {
        showSnack(
          context,
          context.tr('{email} can now join as staff.', {
            'email': email.text.trim().toLowerCase(),
          }),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _remove(String email) async {
    final ok = await confirm(
      context,
      title: context.tr('Remove {email}?', {'email': email}),
      message: context.tr('They will not be able to join as staff.'),
      confirmLabel: context.tr('Remove'),
      cancelLabel: context.tr('Keep'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _vm.remove(email);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<StaffAccountsViewModel>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Staff accounts'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(context.tr('Add staff')),
      ),
      body: Builder(
        builder: (context) {
          if (vm.error != null) return ErrorView(error: vm.error!);
          if (vm.loading) return const LoadingView();
          final staff = vm.staff;
          final waiting = vm.waiting;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              FadeSlideIn(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('How to add staff'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '1. ${context.tr('Tap "Add staff" and type their email.')}\n'
                          '2. ${context.tr('They create an account in SmartShop and choose "Koperasi staff".')}\n'
                          '3. ${context.tr('They tap "Join as staff". Done!')}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SectionHeader(
                title: context.tr('Staff ({count})', {'count': staff.length}),
              ),
              Card(
                child: Column(
                  children: [
                    for (final s in staff)
                      ListTile(
                        leading: UserAvatar(name: s.name, photo: s.photo),
                        title: Text(s.name),
                        subtitle: Text(s.email),
                        trailing: vm.isMe(s)
                            ? Pill(
                                label: context.tr('You'),
                                color: context.brand,
                              )
                            : null,
                      ),
                  ],
                ),
              ),
              SectionHeader(
                title: context.tr('Waiting to join ({count})', {
                  'count': waiting.length,
                }),
              ),
              if (waiting.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.hourglass_empty),
                    title: Text(context.tr('Nobody is waiting.')),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final email in waiting)
                        ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(email),
                          subtitle: Text(
                            context.tr('Can tap "Join as staff" now'),
                          ),
                          trailing: IconButton(
                            tooltip: context.tr('Remove'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(email),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
