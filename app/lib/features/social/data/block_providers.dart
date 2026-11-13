import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'follow_providers.dart';

/// Blocks live at `users/{myUid}/blocked/{otherUid}` = { createdAt }.
/// Only the owner reads/writes them; everything else is filtered client-side.
final blockRepoProvider = Provider((ref) => BlockRepository(ref));

class BlockRepository {
  BlockRepository(this._ref);
  final Ref _ref;
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String me, String other) =>
      _db.collection('users').doc(me).collection('blocked').doc(other);

  /// Block [other] and drop my follow edge to them (if any).
  Future<void> block(String me, String other) async {
    await _doc(me, other).set({'createdAt': FieldValue.serverTimestamp()});
    try {
      await _ref.read(followRepoProvider).unfollow(me, other);
    } catch (_) {
      // Not following them (or already removed) — nothing to undo.
    }
  }

  Future<void> unblock(String me, String other) => _doc(me, other).delete();
}

/// Uids the signed-in user has blocked (live). Empty while signed out.
final blockedUidsProvider = StreamProvider<Set<String>>((ref) {
  final me = ref.watch(authStateProvider).value?.uid;
  if (me == null) return Stream.value(const <String>{});
  return FirebaseFirestore.instance
      .collection('users')
      .doc(me)
      .collection('blocked')
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toSet());
});

/// Synchronous view of the blocked set for filtering (empty until loaded).
final blockedSetProvider = Provider<Set<String>>(
    (ref) => ref.watch(blockedUidsProvider).value ?? const <String>{});

/// Have I blocked [uid]?
final isBlockedProvider = Provider.family<bool, String>(
    (ref, uid) => ref.watch(blockedSetProvider).contains(uid));
