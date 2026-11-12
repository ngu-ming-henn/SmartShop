import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/strings.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../auth/login_screen.dart';

/// Admins add the emails of new koperasi staff. Those people can then tap
/// "Join as staff" in the app (no Firebase Console needed).
class StaffAccountsScreen extends StatefulWidget {
  const StaffAccountsScreen({super.key});

  @override
  State<StaffAccountsScreen> createState() => _StaffAccountsScreenState();
}

class _StaffAccountsScreenState extends State<StaffAccountsScreen> {
  late final _service = context.read<AuthService>();
  late final Stream<List<AppUser>> _staff = _service.watchStaff();
  late final Stream<List<String>> _invites = _service.watchStaffInvites();

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
      await _service.inviteStaff(
        email.text,
        byUid: context.read<AuthProvider>().user!.uid,
      );
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
      await _service.removeStaffInvite(email);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Staff accounts'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(context.tr('Add staff')),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _staff,
        builder: (context, staffSnap) => StreamBuilder<List<String>>(
          stream: _invites,
          builder: (context, inviteSnap) {
            final error = staffSnap.error ?? inviteSnap.error;
            if (error != null) return ErrorView(error: error);
            if (!staffSnap.hasData || !inviteSnap.hasData) {
              return const LoadingView();
            }
            final staff = staffSnap.data!
              ..sort((a, b) => a.name.compareTo(b.name));
            final staffEmails = {for (final s in staff) s.email.toLowerCase()};
            final waiting = inviteSnap.data!
                .where((e) => !staffEmails.contains(e))
                .toList();

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
                          leading: CircleAvatar(
                            backgroundColor: context.colors.secondaryContainer,
                            child: Text(
                              s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                              style: TextStyle(color: context.brand),
                            ),
                          ),
                          title: Text(s.name),
                          subtitle: Text(s.email),
                          trailing: s.uid == me?.uid
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
      ),
    );
  }
}
