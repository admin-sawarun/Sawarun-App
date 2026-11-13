import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/data/admin_service.dart'
    show AdminReport, adminReportsProvider;
import '../data/admin_web_api.dart';
import '../widgets/common.dart';

const _actionLabels = {
  'dismiss': 'Dismiss',
  'remove_content': 'Remove content',
  'ban_user': 'Ban user',
};

/// Moderation queue as a wide table (same data/actions as the in-app tab).
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String _status = 'open';
  final Set<String> _busy = {};

  Future<void> _resolve(AdminReport r, String action) async {
    final label = _actionLabels[action]!;
    if (action != 'dismiss') {
      final ok = await confirmAction(
        context,
        title: '$label?',
        message: action == 'ban_user'
            ? 'Ban ${r.targetName ?? r.targetUid} from Savarun? Their account '
                'is disabled and signed out.'
            : 'Remove the reported ${r.targetType}? This cannot be undone.',
        confirmLabel: label,
      );
      if (!ok) return;
    }
    setState(() => _busy.add(r.id));
    try {
      await ref.read(adminWebRepoProvider).resolveReport(r.id, action);
      ref.invalidate(adminReportsProvider('open'));
      ref.invalidate(adminReportsProvider('resolved'));
      if (mounted) showToast(context, 'Report resolved: $label');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(adminReportsProvider(_status));
    return PageScroll(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'open', label: Text('Open')),
              ButtonSegment(value: 'resolved', label: Text('Resolved')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        const SizedBox(height: 20),
        PanelCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AsyncBody<List<AdminReport>>(
            value: reports,
            onRetry: () => ref.invalidate(adminReportsProvider(_status)),
            loading: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: TableSkeleton(),
            ),
            builder: (list) => list.isEmpty
                ? EmptyState(
                    title: _status == 'open'
                        ? 'No open reports. All clear!'
                        : 'No resolved reports',
                    icon: Icons.flag_outlined,
                  )
                : _table(list),
          ),
        ),
      ],
    );
  }

  Widget _table(List<AdminReport> list) {
    final open = _status == 'open';
    return WideTable(
      child: DataTable(
        dataRowMinHeight: 60,
        dataRowMaxHeight: 72,
        columns: [
          const DataColumn(label: Text('TYPE')),
          const DataColumn(label: Text('REASON')),
          const DataColumn(label: Text('TARGET')),
          const DataColumn(label: Text('REPORTED BY')),
          const DataColumn(label: Text('DETAILS')),
          const DataColumn(label: Text('REPORTED')),
          DataColumn(label: Text(open ? 'ACTIONS' : 'OUTCOME')),
        ],
        rows: [
          for (final r in list)
            DataRow(cells: [
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    switch (r.targetType) {
                      'user' => Icons.person_outline_rounded,
                      'post' => Icons.image_outlined,
                      'message' => Icons.chat_bubble_outline_rounded,
                      'analysis' => Icons.auto_awesome_outlined,
                      _ => Icons.flag_outlined,
                    },
                    size: 18,
                    color: AdminPalette.inkSoft,
                  ),
                  const SizedBox(width: 8),
                  Text(capitalize(r.targetType)),
                ],
              )),
              DataCell(Text(capitalize(r.reason.replaceAll('_', ' ')),
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(_twoLine(r.targetName ?? r.targetUid,
                  r.targetType == 'user' ? null : r.targetId)),
              DataCell(_twoLine(r.reporterName ?? r.reporterUid, null)),
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Tooltip(
                  message: r.details ?? '',
                  child: Text(
                    (r.details?.trim().isNotEmpty ?? false) ? r.details! : '—',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AdminPalette.inkSoft),
                  ),
                ),
              )),
              DataCell(Text(timeAgo(r.createdAt))),
              DataCell(open ? _actions(r) : StatusChip('resolved',
                  label: _actionLabels[r.resolution] ?? 'Resolved')),
            ]),
        ],
      ),
    );
  }

  Widget _twoLine(String a, String? b) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a, overflow: TextOverflow.ellipsis),
            if (b != null)
              Text(b,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11.5, color: AdminPalette.muted)),
          ],
        ),
      );

  Widget _actions(AdminReport r) {
    if (_busy.contains(r.id)) {
      return const SizedBox(
          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }
    ButtonStyle danger() => TextButton.styleFrom(
        foregroundColor: AdminPalette.danger,
        visualDensity: VisualDensity.compact);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => _resolve(r, 'dismiss'),
          child: const Text('Dismiss'),
        ),
        // The backend rejects remove_content for user reports.
        // AI result reports only need review + dismiss.
        if (r.targetType != 'user' && r.targetType != 'analysis')
          TextButton(
            style: danger(),
            onPressed: () => _resolve(r, 'remove_content'),
            child: const Text('Remove content'),
          ),
        if (r.targetType != 'analysis')
          TextButton(
            style: danger(),
            onPressed: () => _resolve(r, 'ban_user'),
            child: const Text('Ban user'),
          ),
      ],
    );
  }
}
