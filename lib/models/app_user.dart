import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/utils/firestore_helpers.dart';

/// A document in `users/{uid}`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.studentId,
    required this.role,
    required this.greenPoints,
    this.phone = '',
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String studentId;
  final String role; // 'student' or 'staff'
  final int greenPoints;
  final String phone; // optional, e.g. "012-345 6789"
  final DateTime? createdAt;

  bool get isStaff => role == UserRoles.staff;

  /// Shown as a QR code on the profile; staff scan it at the counter.
  String get memberQrData => '$memberQrPrefix$uid';

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      studentId: d['studentId'] as String? ?? '',
      role: d['role'] as String? ?? UserRoles.student,
      greenPoints: readInt(d['greenPoints']),
      phone: d['phone'] as String? ?? '',
      createdAt: readDate(d['createdAt']),
    );
  }

  /// A new self-registered profile. The security rules only accept
  /// role 'student' with 0 points here.
  static Map<String, dynamic> newStudentMap({
    required String name,
    required String email,
    required String studentId,
    String phone = '',
  }) => {
    'name': name,
    'email': email,
    'studentId': studentId,
    'phone': phone,
    'role': UserRoles.student,
    'greenPoints': 0,
    'createdAt': FieldValue.serverTimestamp(),
  };

  /// A staff profile. The rules accept it only for emails an admin added in
  /// More -> Staff accounts, or for the very first admin.
  static Map<String, dynamic> newStaffMap({
    required String name,
    required String email,
  }) => {
    'name': name,
    'email': email,
    'studentId': '',
    'phone': '',
    'role': UserRoles.staff,
    'greenPoints': 0,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
