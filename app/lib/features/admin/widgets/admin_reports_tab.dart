import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/admin_service.dart';
import 'admin_scaffold.dart';

/// Moderation queue: user reports with Dismiss / Remove content / Ban user.
class AdminReportsTab extends ConsumerStatefulWidget {
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  bool _showResolved = false;

  String get _status => _showResolved ? 'resolved' : 'open';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _showResolved ? 'Resolved reports' : 'Open reports',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const Text('Show resolved',
                  style: TextStyle(fontSize: 13, color: AppColors.inkMuted)),
              const SizedBox(width: 6),
              Switch(
                value: _showResolved,
                activeThumbColor: AppColors.ink,
                onChanged: (v) => setState(() => _showResolved = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: AdminAsync<List<AdminReport>>(
            value: ref.watch(adminReportsProvider(_status)),
            onRetry: () => ref.invalidate(adminReportsProvider(_status)),
            builder: (reports) {
              if (reports.isEmpty) {
                return Center(
                  child: Text(
                    _showResolved
                        ? 'No resolved reports.'
                        : 'No open reports. All clear!',
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(adminReportsProvider(_status)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ReportRow(report: reports[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends ConsumerStatefulWidget {
  const _ReportRow({required this.report});
  final AdminReport report;

  @override
  ConsumerState<_ReportRow> createState() => _ReportRowState();
}

class _ReportRowState extends ConsumerState<_ReportRow> {
  bool _busy = false;

  static const _actionLabels = {
    'dismiss': 'Dismiss',
    'remove_content': 'Remove content',
    'ban_user': 'Ban user',
  };

  Future<void> _resolve(String action) async {
    final r = widget.report;
    final label = _actionLabels[action]!;
    final messenger = ScaffoldMessenger.of(context);

    if (action != 'dismiss') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$label?'),
          content: Text(action == 'ban_user'
              ? 'Ban ${r.targetName ?? r.targetUid} from Savarun?'
              : 'Remove the reported ${r.targetType}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(label),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(adminRepoProvider).resolveReport(r.id, action);
      ref.invalidate(adminReportsProvider('open'));
      ref.invalidate(adminReportsProvider('resolved'));
      messenger
          .showSnackBar(SnackBar(content: Text('Report resolved: $label')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final open = r.status == 'open';
    final typeIcon = switch (r.targetType) {
      'user' => Icons.person_outline_rounded,
      'post' => Icons.image_outlined,
      'message' => Icons.chat_bubble_outline_rounded,
      _ => Icons.flag_outlined,
    };
    final reason = r.reason.isEmpty
        ? 'Other'
        : '${r.reason[0].toUpperCase()}${r.reason.substring(1)}';
    final target = r.targetName ?? r.targetUid;
    final targetLine = r.targetType == 'user'
        ? 'Target: $target'
        : 'Target: ${r.targetType} by $target (${r.targetId})';

    Widget meta(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(icon, size: 15, color: AppColors.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.inkMuted)),
              ),
            ],
          ),
        );

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, size: 18, color: AppColors.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$reason · ${r.targetType}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              StatusPill(
                label:
                    open ? 'Open' : (_actionLabels[r.resolution] ?? 'Resolved'),
                color: open ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 6),
          meta(Icons.gps_fixed_rounded, targetLine),
          meta(Icons.outlined_flag_rounded,
              'Reported by ${r.reporterName ?? r.reporterUid}'),
          if (r.createdAt != null)
            meta(Icons.schedule_rounded, _ago(r.createdAt!)),
          if (r.details != null && r.details!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(r.details!,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
            ),
          ],
          if (open) ...[
            const SizedBox(height: 14),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                      label: 'Dismiss', onTap: () => _resolve('dismiss')),
                  // The backend rejects remove_content for user reports.
                  if (r.targetType != 'user' && r.targetType != 'analysis')
                    _ActionButton(
                        label: 'Remove content',
                        danger: true,
                        onTap: () => _resolve('remove_content')),
                  if (r.targetType != 'analysis')
                    _ActionButton(
                      label: 'Ban user',
                      danger: true,
                      onTap: () => _resolve('ban_user')),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.label, required this.onTap, this.danger = false});
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      child: Text(label),
    );
  }
}
