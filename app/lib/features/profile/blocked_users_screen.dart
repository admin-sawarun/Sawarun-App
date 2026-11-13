import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../social/data/block_providers.dart';
import '../wardrobe/data/wardrobe_providers.dart';
import 'data/profile_providers.dart';

/// Settings → Blocked users: everyone I've blocked, each with Unblock.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUidsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Blocked users')),
      body: blockedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (uids) {
          if (uids.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "You haven't blocked anyone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ),
            );
          }
          final list = uids.toList()..sort();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _BlockedTile(uid: list[i]),
          );
        },
      ),
    );
  }
}

class _BlockedTile extends ConsumerWidget {
  const _BlockedTile({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userByUidProvider(uid)).value;
    final me = ref.watch(currentUidProvider);
    final hasPhoto = user?.photoURL != null && user!.photoURL!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: () => context.push(Routes.otherProfile, extra: uid),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          backgroundImage: hasPhoto ? NetworkImage(user.photoURL!) : null,
          child: hasPhoto
              ? null
              : Text(user?.initial ?? '?',
                  style: const TextStyle(color: Colors.white)),
        ),
        title: Text(user?.name ?? 'Savarun User',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: user == null ? null : Text(user.handle),
        trailing: OutlinedButton(
          onPressed: me == null
              ? null
              : () => ref.read(blockRepoProvider).unblock(me, uid),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: const Text('Unblock'),
        ),
      ),
    );
  }
}
