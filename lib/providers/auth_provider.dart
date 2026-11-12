import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  /// App just started, Firebase has not told us yet.
  unknown,
  signedOut,

  /// Signed in, waiting for `users/{uid}`.
  loadingProfile,
  signedIn,

  /// Signed in but there is no `users/{uid}` document.
  profileMissing,
}

/// Holds the logged-in user and their role. Also used by go_router as
/// `refreshListenable` so the app redirects when the login state changes.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service) {
    _authSub = _service.authStateChanges().listen(_onAuthChanged);
  }

  final AuthService _service;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  User? _firebaseUser;
  bool _registering = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  User? get firebaseUser => _firebaseUser;
  bool get isStaff => _user?.isStaff ?? false;

  void _onAuthChanged(User? firebaseUser) {
    _profileSub?.cancel();
    _firebaseUser = firebaseUser;
    _user = null;
    if (firebaseUser == null) {
      _setStatus(AuthStatus.signedOut);
      return;
    }
    _setStatus(AuthStatus.loadingProfile);
    _profileSub = _service
        .watchUserDoc(firebaseUser.uid)
        .listen(
          (snap) {
            if (snap.exists) {
              _user = AppUser.fromDoc(snap);
              _setStatus(AuthStatus.signedIn);
            } else if (_registering || snap.metadata.isFromCache) {
              // Not written yet / not confirmed by the server yet: keep waiting.
              _user = null;
              _setStatus(AuthStatus.loadingProfile);
            } else {
              _user = null;
              _setStatus(AuthStatus.profileMissing);
            }
          },
          onError: (Object e) {
            debugPrint('Profile load failed: $e');
            _user = null;
            _setStatus(AuthStatus.profileMissing);
          },
        );
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) =>
      _service.signIn(email: email, password: password);

  Future<void> register({
    required String name,
    required String email,
    required String studentId,
    required String password,
    String phone = '',
    bool asStaff = false,
  }) async {
    _registering = true;
    try {
      await _service.register(
        name: name,
        email: email,
        studentId: studentId,
        password: password,
        phone: phone,
        asStaff: asStaff,
      );
    } finally {
      _registering = false;
      if (_firebaseUser != null && _user == null) {
        _setStatus(AuthStatus.profileMissing);
      }
    }
  }

  /// Staff join from the "Finish your profile" screen (no Student ID).
  Future<void> joinAsStaff({required String name}) {
    final u = _firebaseUser!;
    return _service.joinAsStaff(
      uid: u.uid,
      name: name.trim(),
      email: (u.email ?? '').toLowerCase(),
    );
  }

  /// For accounts that exist in Firebase Auth but have no profile document.
  Future<void> createMissingStudentProfile({
    required String name,
    required String studentId,
  }) {
    final u = _firebaseUser!;
    return _service.createStudentProfile(
      uid: u.uid,
      name: name.trim(),
      email: u.email ?? '',
      studentId: studentId.trim().toUpperCase(),
    );
  }

  Future<void> updateProfile({
    required String name,
    required String studentId,
    required String phone,
  }) => _service.updateProfile(
    _user!.uid,
    name: name,
    studentId: studentId,
    phone: phone,
  );

  Future<void> updatePhoto(Uint8List? jpeg) =>
      _service.updatePhoto(_user!.uid, jpeg);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _service.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  Future<void> sendPasswordReset(String email) =>
      _service.sendPasswordReset(email);

  Future<void> signOut() => _service.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
