import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/preferences_card.dart';
import '../../widgets/user_avatar.dart';

/// Profile for students and staff: details, member QR, account settings
/// (edit profile, change password), language and light / dark mode.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await confirm(
      context,
      title: context.tr('Log out?'),
      message: context.tr('You can log in again any time.'),
      confirmLabel: context.tr('Log out'),
      cancelLabel: context.tr('Cancel'),
    );
    if (ok && context.mounted) await context.read<AuthProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: LoadingView());

    final sections = <Widget>[
      if (!user.isStaff) _MemberQrCard(user: user),
      _Section(
        title: context.tr('Account'),
        children: [
          _Tile(
            icon: Icons.person_outline,
            title: context.tr('Edit profile'),
            subtitle: context.tr('Photo, name, ID and phone number'),
            onTap: () => context.push('/account/edit'),
          ),
          _Tile(
            icon: Icons.lock_outline,
            title: context.tr('Change password'),
            subtitle: context.tr('Keep your account safe'),
            onTap: () => context.push('/account/password'),
          ),
          if (!user.isStaff)
            _Tile(
              icon: Icons.eco_outlined,
              iconColor: context.eco,
              title: context.tr('Green points'),
              subtitle: context.tr('{points} points', {
                'points': user.greenPoints,
              }),
              onTap: () => context.push('/points'),
            ),
        ],
      ),
      _Section(
        title: context.tr('Preferences'),
        plain: true,
        children: const [PreferencesCard()],
      ),
      _Section(
        title: context.tr('More'),
        children: [
          _Tile(
            icon: Icons.location_on_outlined,
            title: context.tr('Find the koperasi'),
            subtitle: ShopLocation.address,
            onTap: () => context.push('/shop'),
          ),
          _Tile(
            icon: Icons.info_outline,
            title: context.tr('About SmartShop'),
            onTap: () => context.push('/settings'),
          ),
          _Tile(
            icon: Icons.logout,
            iconColor: context.colors.error,
            title: context.tr('Log out'),
            titleColor: context.colors.error,
            onTap: () => _logout(context),
          ),
        ],
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                _Header(user: user),
                for (var i = 0; i < sections.length; i++)
                  FadeSlideIn(
                    delay: stagger(i + 1, stepMs: 80),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: sections[i],
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
            // Keeps the status bar readable while the page scrolls under it.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.brandGradient),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, top + 4, 16, 24),
      child: Column(
        children: [
          Row(
            children: [
              if (context.canPop())
                const BackButton(color: Colors.white)
              else
                const SizedBox(width: 8),
              Text(
                context.tr('Profile'),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: context.tr('Edit profile'),
                onPressed: () => context.push('/account/edit'),
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            child: Pressable(
              child: GestureDetector(
                onTap: () => changeProfilePhoto(context),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: UserAvatar(
                        name: user.name,
                        photo: user.photo,
                        radius: 42,
                        background: Colors.white.withValues(alpha: 0.2),
                        foreground: Colors.white,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_camera,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            user.email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (user.studentId.isNotEmpty)
                _HeaderChip(icon: Icons.badge_outlined, label: user.studentId),
              _HeaderChip(
                icon: user.isStaff ? Icons.storefront : Icons.school_outlined,
                label: context.tr(user.isStaff ? 'Koperasi staff' : 'Student'),
              ),
              if (user.phone.isNotEmpty)
                _HeaderChip(icon: Icons.phone_outlined, label: user.phone),
            ],
          ),
          if (!user.isStaff) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: CountUp(
                        value: user.greenPoints,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      label: context.tr('Green points'),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  Expanded(
                    child: _Stat(
                      value: Text(
                        user.createdAt == null
                            ? '-'
                            : formatDate(user.createdAt!),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      label: context.tr('Member since'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final Widget value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      value,
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 12,
        ),
      ),
    ],
  );
}

/// Member QR, folded away until the student taps it.
class _MemberQrCard extends StatefulWidget {
  const _MemberQrCard({required this.user});
  final AppUser user;

  @override
  State<_MemberQrCard> createState() => _MemberQrCardState();
}

class _MemberQrCardState extends State<_MemberQrCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _open = !_open),
            leading: CircleAvatar(
              backgroundColor: context.colors.secondaryContainer,
              child: Icon(Icons.qr_code_2, color: context.brand),
            ),
            title: Text(
              context.tr('Member QR'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.tr(
                'Show at the counter for a digital receipt and points',
              ),
            ),
            trailing: AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              child: const Icon(Icons.expand_more),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white, // QR codes need a white background
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: widget.user.memberQrData,
                      size: 190,
                      backgroundColor: Colors.white,
                      semanticsLabel: context.tr('Member QR'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const UtsCrest(size: 22),
                      const SizedBox(width: 6),
                      Text('UTS SmartShop', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.plain = false,
  });

  final String title;
  final List<Widget> children;

  /// Children are cards already (no wrapping card).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        if (plain)
          ...children
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? context.brand;
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
