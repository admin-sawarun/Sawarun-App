import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SessionStatus { loading, signedOut, denied, admin }

/// Tracks the Firebase user and whether they hold the `admin` custom claim.
/// The router listens to it to redirect between login, denied and the shell.
class AdminSession extends ChangeNotifier {
  AdminSession(this._auth) {
    _sub = _auth.authStateChanges().listen(_evaluate);
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _sub;

  SessionStatus status = SessionStatus.loading;
  User? user;
  String? error;

  String get displayName =>
      user?.displayName ?? user?.email ?? user?.phoneNumber ?? 'Admin';

  String? get contact => user?.email ?? user?.phoneNumber;

  Future<void> _evaluate(User? u) async {
    user = u;
    error = null;
    if (u == null) {
      status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    status = SessionStatus.loading;
    notifyListeners();
    try {
      // Force-refresh so a freshly granted/revoked claim is picked up.
      final token = await u.getIdTokenResult(true);
      status = token.claims?['admin'] == true
          ? SessionStatus.admin
          : SessionStatus.denied;
    } catch (e) {
      error = '$e';
      status = SessionStatus.denied;
    }
    notifyListeners();
  }

  /// Re-read the claim (e.g. after another admin granted access).
  Future<void> recheck() => _evaluate(_auth.currentUser);

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final adminSessionProvider = Provider<AdminSession>((ref) {
  final s = AdminSession(FirebaseAuth.instance);
  ref.onDispose(s.dispose);
  return s;
});
