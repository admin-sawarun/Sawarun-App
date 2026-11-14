import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

final accountRepoProvider = Provider((ref) => const AccountRepository());

/// Thrown when the backend refuses the deletion because the sign-in is too
/// old (HTTP 401) — the user must log out, log back in and retry.
class ReauthRequiredException implements Exception {
  const ReauthRequiredException();
  @override
  String toString() =>
      'For your security, please log out, log in again and then retry '
      'deleting your account.';
}

class AccountRepository {
  const AccountRepository();

  /// Permanently deletes the signed-in account and all its data on the
  /// backend (DELETE /api/users/me), then signs out locally.
  Future<void> deleteMyAccount() async {
    await _revokeAppleSignIn();
    try {
      await const ApiClient().delete('${AppConfig.backendBaseUrl}/api/users/me');
    } on ApiException catch (e) {
      if (e.statusCode == 401) throw const ReauthRequiredException();
      // 5xx: e.g. the Firebase Auth deletion failed part-way — safe to retry.
      if (e.statusCode >= 500) {
        throw Exception("Couldn't finish deleting, please try again.");
      }
      rethrow;
    }
    // The Firebase user no longer exists server-side; clear the local session.
    // (Google sign-in goes through FirebaseAuth's provider flow, so there is
    // no separate Google session to clear.)
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// App Store guideline 5.1.1(v): deleting an account that uses Sign in
  /// with Apple must also revoke the app's Apple tokens. Apple only hands out
  /// the authorization code needed for that at sign-in, so the user confirms
  /// with Apple once more. Cancelling stops the deletion.
  Future<void> _revokeAppleSignIn() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) return;
    final usesApple = user.providerData.any((p) => p.providerId == 'apple.com');
    if (!usesApple || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    final UserCredential cred;
    try {
      cred = await user.reauthenticateWithProvider(AppleAuthProvider());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled' || e.code == 'web-context-canceled') {
        throw Exception('Apple confirmation was cancelled, so the account was not deleted.');
      }
      rethrow;
    }
    final code = cred.additionalUserInfo?.authorizationCode;
    if (code != null) await auth.revokeTokenWithAuthorizationCode(code);
  }
}
