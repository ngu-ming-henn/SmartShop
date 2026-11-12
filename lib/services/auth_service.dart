import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../core/utils/errors.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Includes metadata changes so we can tell "not in the local cache yet"
  /// apart from "really does not exist on the server".
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(String uid) =>
      _userRef(uid).snapshots(includeMetadataChanges: true);

  Future<AppUser?> getUser(String uid) async {
    final doc = await _userRef(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  /// Students self-register. Staff can too ([asStaff]) if an admin has
  /// added their email in More -> Staff accounts (see [joinAsStaff]).
  Future<void> register({
    required String name,
    required String email,
    required String studentId,
    required String password,
    String phone = '',
    bool asStaff = false,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(name.trim());
    if (asStaff) {
      return joinAsStaff(
        uid: user.uid,
        name: name.trim(),
        email: email.trim().toLowerCase(),
      );
    }
    await createStudentProfile(
      uid: user.uid,
      name: name.trim(),
      email: email.trim(),
      studentId: studentId.trim().toUpperCase(),
      phone: phone.trim(),
    );
  }

  Future<void> createStudentProfile({
    required String uid,
    required String name,
    required String email,
    required String studentId,
    String phone = '',
  }) => _userRef(uid).set(
    AppUser.newStudentMap(
      name: name,
      email: email,
      studentId: studentId,
      phone: phone,
    ),
  );

  /// Name, Student ID and phone; role and points are protected by the rules.
  Future<void> updateProfile(
    String uid, {
    required String name,
    required String studentId,
    required String phone,
  }) => _userRef(uid).update({
    'name': name.trim(),
    'studentId': studentId.trim().toUpperCase(),
    'phone': phone.trim(),
  });

  /// Profile photo as a small JPEG (about 30 KB) in the profile document:
  /// Firebase Storage needs the paid plan. `null` removes it. The rules let
  /// users edit their own profile.
  Future<void> updatePhoto(String uid, Uint8List? jpeg) {
    if (jpeg != null && jpeg.length > maxPhotoBytes) {
      throw const AppException(
        'That photo is too big. Please choose another one.',
      );
    }
    return _userRef(uid)
        .update({'photo': jpeg == null ? FieldValue.delete() : Blob(jpeg)});
  }

  static const maxPhotoBytes = 300 * 1024;

  /// Checks the current password again (Firebase needs a recent login),
  /// then sets the new one.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser!;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      ),
    );
    await user.updatePassword(newPassword);
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  // ------------------------------------------------------------------ staff

  DocumentReference<Map<String, dynamic>> get _setup =>
      _db.collection('config').doc('setup');
  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('staffInvites');

  /// Creates a staff profile. The security rules allow it only if an admin
  /// added this email (More -> Staff accounts), or if the shop has no admin
  /// yet: then this person becomes the first admin and `config/setup` is
  /// written in the same batch, so it can never happen again.
  Future<void> joinAsStaff({
    required String uid,
    required String name,
    required String email,
  }) async {
    final firstAdmin = !(await _setup.get()).exists;
    final batch = _db.batch()
      ..set(_userRef(uid), AppUser.newStaffMap(name: name, email: email));
    if (firstAdmin) {
      batch.set(_setup, {
        'firstAdmin': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AppException(
          'Your email is not on the staff list yet. Ask a koperasi admin to '
          'add it in More → Staff accounts.',
        );
      }
      rethrow;
    }
  }

  /// Staff accounts (for More -> Staff accounts).
  Stream<List<AppUser>> watchStaff() => _db
      .collection('users')
      .where('role', isEqualTo: UserRoles.staff)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  /// Emails allowed to join as staff.
  Stream<List<String>> watchStaffInvites() =>
      _invites.snapshots().map((s) => s.docs.map((d) => d.id).toList()..sort());

  Future<void> inviteStaff(String email, {required String byUid}) {
    final id = email.trim().toLowerCase();
    return _invites.doc(id).set({
      'email': id,
      'invitedBy': byUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeStaffInvite(String email) => _invites.doc(email).delete();

  Future<void> signOut() => _auth.signOut();
}
