import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/admin_service.dart';
import 'admin_scaffold.dart';

/// Admin → Trending Fashion (CR-1). The admin curates the Home "Trending
/// Fashion" feed here: add cards (image + title + affiliate link), reorder,
/// show/hide and delete. Everything the users see on that feed is placed here.
class AdminTrendingTab extends ConsumerWidget {
  const AdminTrendingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Curate the Home "Trending Fashion" feed. Each card opens the affiliate link you set.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showForm(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminAsync<List<AdminTrendingItem>>(
            value: ref.watch(adminTrendingFashionProvider),
            onRetry: () => ref.invalidate(adminTrendingFashionProvider),
            builder: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text('No Trending Fashion cards yet. Tap "Add".',
                      style: TextStyle(color: AppColors.inkMuted)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _TrendingRow(item: items[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendingRow extends ConsumerWidget {
  const _TrendingRow({required this.item});
  final AdminTrendingItem item;

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(adminTrendingFashionProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(adminRepoProvider);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 56,
                  color: AppColors.surface,
                  child: item.imageUrl.isEmpty
                      ? const Icon(Icons.image_outlined,
                          color: AppColors.inkMuted)
                      : Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.inkMuted),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? '(no title)' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (item.subtitle.isNotEmpty)
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.inkMuted),
                      ),
                    Text(
                      '${item.clicks} clicks · order ${item.order}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: item.hidden ? 'Hidden' : 'Live',
                color: item.hidden ? AppColors.inkMuted : AppColors.success,
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Row(
                children: [
                  const Text('Visible',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                  Switch(
                    value: !item.hidden,
                    activeThumbColor: AppColors.ink,
                    onChanged: (v) => _run(context, ref,
                        () => repo.updateTrending(item.id, {'hidden': !v})),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _showForm(context, ref, existing: item),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.danger),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete this card?'),
                      content: Text(item.title.isEmpty
                          ? 'This Trending Fashion card will be removed.'
                          : '"${item.title}" will be removed from Trending Fashion.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete',
                                style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await _run(
                        context, ref, () => repo.deleteTrending(item.id));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add / edit dialog. For an edit, pass [existing] to prefill the fields.
Future<void> _showForm(BuildContext context, WidgetRef ref,
    {AdminTrendingItem? existing}) async {
  final titleC = TextEditingController(text: existing?.title ?? '');
  final subtitleC = TextEditingController(text: existing?.subtitle ?? '');
  final imageC = TextEditingController(text: existing?.imageUrl ?? '');
  final linkC = TextEditingController(text: existing?.affiliateUrl ?? '');
  final orderC =
      TextEditingController(text: (existing?.order ?? 0).toString());
  final formKey = GlobalKey<FormState>();
  final repo = ref.read(adminRepoProvider);
  final isEdit = existing != null;

  String? requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? urlValidator(String? v, {bool required = true}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return required ? 'Required' : null;
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.isAbsolute || !uri.scheme.startsWith('http')) {
      return 'Enter a full link starting with https://';
    }
    return null;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      var busy = false;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEdit ? 'Edit card' : 'New Trending Fashion card'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleC,
                    decoration: const InputDecoration(labelText: 'Title *'),
                    validator: requiredValidator,
                  ),
                  TextFormField(
                    controller: subtitleC,
                    decoration:
                        const InputDecoration(labelText: 'Subtitle (optional)'),
                  ),
                  TextFormField(
                    controller: imageC,
                    decoration: const InputDecoration(
                        labelText: 'Image URL (optional)',
                        hintText: 'https://…'),
                    validator: (v) => urlValidator(v, required: false),
                  ),
                  TextFormField(
                    controller: linkC,
                    decoration: const InputDecoration(
                        labelText: 'Affiliate link *', hintText: 'https://…'),
                    validator: (v) => urlValidator(v),
                  ),
                  TextFormField(
                    controller: orderC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Order (lower shows first)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setState(() => busy = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final order = int.tryParse(orderC.text.trim()) ?? 0;
                      try {
                        if (isEdit) {
                          await repo.updateTrending(existing.id, {
                            'title': titleC.text.trim(),
                            'subtitle': subtitleC.text.trim(),
                            'imageUrl': imageC.text.trim(),
                            'affiliateUrl': linkC.text.trim(),
                            'order': order,
                          });
                        } else {
                          await repo.createTrending(
                            title: titleC.text.trim(),
                            subtitle: subtitleC.text.trim(),
                            imageUrl: imageC.text.trim(),
                            affiliateUrl: linkC.text.trim(),
                            order: order,
                          );
                        }
                        ref.invalidate(adminTrendingFashionProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() => busy = false);
                        messenger
                            .showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      );
    },
  );
}
