import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../analysis/widgets/past_scores_strip.dart';
import '../profile/data/profile_providers.dart';
import '../wardrobe/data/wardrobe_models.dart';
import '../wardrobe/data/wardrobe_providers.dart';
import 'data/block_providers.dart';
import 'data/follow_providers.dart';
import 'data/report_service.dart';
import 'widgets/report_sheet.dart';

class OtherProfileScreen extends ConsumerWidget {
  const OtherProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userByUidProvider(uid));
    final me = ref.watch(currentUidProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(profileAsync.value?.handle ?? 'Profile'),
        actions: [
          if (me != null && me != uid)
            _ProfileMenu(
                me: me, uid: uid, name: profileAsync.value?.name ?? 'this user'),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));

          final followers = ref.watch(followerCountProvider(uid)).value ?? 0;
          final following = ref.watch(followingCountProvider(uid)).value ?? 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary,
                      backgroundImage: (user.photoURL != null && user.photoURL!.isNotEmpty) ? NetworkImage(user.photoURL!) : null,
                      child: (user.photoURL == null || user.photoURL!.isEmpty)
                          ? Text(user.initial, style: const TextStyle(color: Colors.white, fontSize: 32))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('${user.handle}${user.style != null ? ' · ${user.style}' : ''}',
                        style: const TextStyle(color: AppColors.inkMuted)),
                    const SizedBox(height: 8),
                    Text(user.bio, textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(
                    value: '$followers',
                    label: 'Followers',
                    onTap: () =>
                        context.push(Routes.followers, extra: (uid, 0)),
                  ),
                  _Stat(
                    value: '$following',
                    label: 'Following',
                    onTap: () =>
                        context.push(Routes.followers, extra: (uid, 1)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ActionButtons(uid: uid),
              const SizedBox(height: 28),
              // Only resolves when their profile is public (Firestore rules).
              PastScoresStrip(uid: uid),
              const SizedBox(height: 24),
              const Text('Wardrobe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (user.wardrobePublic)
                _PublicWardrobe(uid: uid)
              else
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                  child: const Column(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 36, color: AppColors.inkMuted),
                      SizedBox(height: 10),
                      Text('This wardrobe is private', style: TextStyle(color: AppColors.inkMuted)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUidProvider);
    final isFollowing = ref.watch(isFollowingProvider(uid)).value ?? false;

    // Viewing your own profile from search — hide follow/message.
    if (me == uid) return const SizedBox.shrink();

    if (ref.watch(isBlockedProvider(uid))) {
      return Column(
        children: [
          const Text('You blocked this user.',
              style: TextStyle(color: AppColors.inkMuted)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: me == null
                ? null
                : () => ref.read(blockRepoProvider).unblock(me, uid),
            child: const Center(child: Text('Unblock')),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: isFollowing
              ? OutlinedButton(
                  onPressed: () => me == null ? null : ref.read(followRepoProvider).unfollow(me, uid),
                  child: const Text('Following'),
                )
              : ElevatedButton(
                  onPressed: () => me == null ? null : ref.read(followRepoProvider).follow(me, uid),
                  child: const Text('Follow'),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(Routes.chat, extra: uid),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Message'),
          ),
        ),
      ],
    );
  }
}

class _PublicWardrobe extends ConsumerWidget {
  const _PublicWardrobe({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(userWardrobeProvider(uid));
    return itemsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (e, _) => const Text('Could not load wardrobe', style: TextStyle(color: AppColors.inkMuted)),
      data: (items) {
        if (items.isEmpty) {
          return const Text('No items yet.', style: TextStyle(color: AppColors.inkMuted));
        }
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final item in items.take(9)) _MiniItem(item: item),
          ],
        );
      },
    );
  }
}

class _MiniItem extends StatelessWidget {
  const _MiniItem({required this.item});
  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: item.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        image: item.photoURL != null ? DecorationImage(image: NetworkImage(item.photoURL!), fit: BoxFit.cover) : null,
      ),
      child: item.photoURL != null
          ? null
          : Icon(Icons.checkroom_rounded, color: item.color.computeLuminance() > 0.6 ? AppColors.inkMuted : Colors.white70),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

/// App-bar overflow menu on someone else's profile: Report and Block/Unblock.
class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu({required this.me, required this.uid, required this.name});
  final String me;
  final String uid;
  final String name;

  Future<void> _toggleBlock(
      BuildContext context, WidgetRef ref, bool blocked) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(blockRepoProvider);
    if (blocked) {
      try {
        await repo.unblock(me, uid);
        messenger.showSnackBar(SnackBar(content: Text('$name unblocked')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Could not unblock: $e')));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block $name?'),
        content: const Text(
            "They won't appear in your feed, search or messages, and you "
            "won't be able to chat with them. You'll also unfollow them. "
            'You can unblock anytime in Settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.block(me, uid);
      messenger.showSnackBar(SnackBar(content: Text('$name blocked')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not block: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(isBlockedProvider(uid));
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        switch (value) {
          case 'report':
            showReportSheet(context,
                targetType: ReportTarget.user, targetId: uid, targetUid: uid);
          case 'block':
            _toggleBlock(context, ref, blocked);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined),
            title: Text('Report'),
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                color: blocked ? null : AppColors.danger),
            title: Text(blocked ? 'Unblock' : 'Block',
                style: TextStyle(color: blocked ? null : AppColors.danger)),
          ),
        ),
      ],
    );
  }
}
