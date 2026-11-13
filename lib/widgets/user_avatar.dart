import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../viewmodels/auth_view_model.dart';
import 'common.dart';

/// "Test User" -> "TU"; "?" when there is no name.
String initialsOf(String name) {
  final initials = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
  return initials.isEmpty ? '?' : initials;
}

/// The profile photo, or the initials when there is none.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.photo,
    this.radius = 20,
    this.background,
    this.foreground,
  });

  final String name;
  final Uint8List? photo;
  final double radius;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: background ?? context.colors.secondaryContainer,
      foregroundImage: photo == null ? null : MemoryImage(photo!),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
          color: foreground ?? context.brand,
        ),
      ),
    );
  }
}

/// Bottom sheet: take a photo, choose one, or remove it. Saves straight
/// away; the profile updates live.
Future<void> changeProfilePhoto(BuildContext context) async {
  final auth = context.read<AuthViewModel>();
  final hasPhoto = auth.user?.photo != null;
  final choice = await showModalBottomSheet<String>(
    context: context,
    // Above the bottom tab bar, not inside the tab.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: context.brand),
            title: Text(context.tr('Take a photo')),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: context.brand),
            title: Text(context.tr('Choose from gallery')),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(context.tr('Remove photo')),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    if (choice == 'remove') {
      await auth.updatePhoto(null);
      if (context.mounted) showSnack(context, context.tr('Photo removed.'));
      return;
    }
    // Small and compressed, so it fits in the profile document.
    final picked = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 320,
      maxHeight: 320,
      imageQuality: 75,
    );
    if (picked == null) return;
    await auth.updatePhoto(await picked.readAsBytes());
    if (context.mounted) showSnack(context, context.tr('Photo updated.'));
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
