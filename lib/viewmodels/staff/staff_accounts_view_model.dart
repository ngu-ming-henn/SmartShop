import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../view_model.dart';

/// Staff accounts (admins): current staff and the emails allowed to join,
/// both live.
class StaffAccountsViewModel extends ViewModel {
  StaffAccountsViewModel(this._auth, this._myUid) {
    follow(_auth.watchStaff(), (list) => _staff = list);
    follow(_auth.watchStaffInvites(), (list) => _invites = list);
  }

  final AuthService _auth;
  final String _myUid;
  List<AppUser>? _staff;
  List<String>? _invites;

  bool get loading => (_staff == null || _invites == null) && error == null;

  /// A-Z by name.
  List<AppUser> get staff =>
      [...?_staff]..sort((a, b) => a.name.compareTo(b.name));

  bool isMe(AppUser user) => user.uid == _myUid;

  /// Invited emails that have not joined yet.
  List<String> get waiting {
    final joined = {
      for (final s in _staff ?? const <AppUser>[]) s.email.toLowerCase(),
    };
    return (_invites ?? const <String>[])
        .where((e) => !joined.contains(e))
        .toList();
  }

  Future<void> invite(String email) => _auth.inviteStaff(email, byUid: _myUid);

  Future<void> remove(String email) => _auth.removeStaffInvite(email);
}
