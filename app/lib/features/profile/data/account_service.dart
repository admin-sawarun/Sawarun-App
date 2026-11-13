import 'package:firebase_auth/firebase_auth.dart';
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
}
