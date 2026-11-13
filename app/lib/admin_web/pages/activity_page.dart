import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_web_api.dart';
import '../widgets/common.dart';

/// Base verb → past tense, used to turn raw action keys into sentences.
const _pastTense = {
  'ban': 'banned',
  'unban': 'unbanned',
  'suspend': 'suspended',
  'verify': 'verified',
  'reinstate': 'reinstated',
  'approve': 'approved',
  'reject': 'rejected',
  'revoke': 'revoked',
  'delete': 'deleted',
  'remove': 'removed',
  'add': 'added',
  'create': 'created',
  'update': 'updated',
  'edit': 'edited',
  'set': 'set',
  'save': 'saved',
  'feature': 'featured',
  'hide': 'hid',
  'unhide': 'unhid',
  'show': 'showed',
  'resolve': 'resolved',
  'dismiss': 'dismissed',
  'grant': 'granted',
  'disable': 'disabled',
  'enable': 'enabled',
};

/// Already-past forms that may appear in action keys.
const _pastForms = {
  'banned', 'unbanned', 'suspended', 'verified', 'reinstated', 'approved',
  'rejected', 'revoked', 'deleted', 'removed', 'added', 'created', 'updated',
  'edited', 'saved', 'featured', 'hidden', 'resolved', 'dismissed', 'granted',
  'disabled', 'enabled',
};

List<String> _words(String s) => s
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// Groups an action into a coarse kind for icon, colour and filtering.
String actionKind(String action) {
  final w = _words(action).toSet();
  bool any(List<String> keys) => keys.any(w.contains);
  if (any(['unban', 'reinstate', 'unbanned', 'reinstated'])) return 'reinstate';
  if (any(['ban', 'banned'])) return 'ban';
  if (any(['suspend', 'suspended'])) return 'suspend';
  if (any(['verify', 'verified'])) return 'verify';
  if (any(['delete', 'deleted', 'remove', 'removed'])) return 'delete';
  if (any(['admin', 'admins'])) return 'admin';
  if (any(['feature', 'featured'])) return 'feature';
  if (any(['approve', 'approved'])) return 'approve';
  if (any(['reject', 'rejected', 'revoke', 'revoked'])) return 'reject';
  if (any(['report', 'resolve', 'dismiss', 'resolved', 'dismissed'])) {
    return 'report';
  }
  if (any(['hide', 'hidden', 'unhide', 'show'])) return 'visibility';
  if (any(['weights', 'tuning', 'fit'])) return 'tuning';
  return 'other';
}

const _kindStyle = <String, (String, IconData, Color)>{
  'ban': ('Bans', Icons.block_rounded, AdminPalette.danger),
  'suspend': ('Suspensions', Icons.pause_circle_outline_rounded,
      AdminPalette.warning),
  'reinstate': ('Reinstated', Icons.lock_open_rounded, AdminPalette.success),
  'verify': ('Verifications', Icons.verified_outlined, AdminPalette.accent),
  'delete': ('Deletions', Icons.delete_outline_rounded, AdminPalette.danger),
  'admin': ('Admin access', Icons.admin_panel_settings_outlined,
      AdminPalette.info),
  'feature': ('Featured', Icons.star_outline_rounded, Color(0xFFB7791F)),
  'approve': ('Approvals', Icons.check_circle_outline_rounded,
      AdminPalette.success),
  'reject': ('Rejections', Icons.cancel_outlined, AdminPalette.danger),
  'report': ('Reports', Icons.flag_outlined, AdminPalette.warning),
  'visibility': ('Visibility', Icons.visibility_outlined, AdminPalette.inkSoft),
  'tuning': ('AI tuning', Icons.tune_rounded, AdminPalette.accent),
  'other': ('Other', Icons.history_rounded, AdminPalette.muted),
};

String _shortId(String id) =>
    id.length > 14 ? '${id.substring(0, 12)}…' : id;

/// A readable label for the target, preferring names in `details`.
String? _targetLabel(AuditEntry e) {
  final d = e.details;
  if (d is Map) {
    for (final k in ['name', 'targetName', 'email', 'username', 'brandName']) {
      final v = str(d[k]);
      if (v != null) return v;
    }
  }
  return e.targetId == null ? null : _shortId(e.targetId!);
}

/// e.g. "admin@x.com banned user abc123".
String auditSentence(AuditEntry e) {
  final who = e.adminEmail ?? 'An admin';
  final words = _words(e.action);
  final type = e.targetType == null ? null : _words(e.targetType!).join(' ');
  String? verb;
  final rest = <String>[];
  for (final w in words) {
    if (verb == null && _pastTense.containsKey(w)) {
      verb = _pastTense[w];
    } else if (verb == null && _pastForms.contains(w)) {
      verb = w;
    } else {
      rest.add(w);
    }
  }
  // Drop words that repeat the target type ("user.ban" + targetType user).
  final typeWords = type?.split(' ').toSet() ?? const <String>{};
  final object = [
    ...rest.where((w) => !typeWords.contains(w)),
    ?type,
  ].join(' ');
  final target = _targetLabel(e);
  final tail = [
    if (object.isNotEmpty) object,
    ?target,
  ].join(' ');
  if (verb == null) {
    return '$who performed "${e.action}"${tail.isEmpty ? '' : ' on $tail'}';
  }
  return '$who $verb${tail.isEmpty ? '' : ' $tail'}';
}

/// Remaining details as short "key: value" text.
String? _detailsText(AuditEntry e) {
  final d = e.details;
  if (d == null) return null;
  if (d is Map) {
    final parts = <String>[];
    for (final entry in d.entries) {
      final v = entry.value;
      if (v == null || v is Map || v is List) continue;
      parts.add('${entry.key}: $v');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
  return str(d);
}

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  List<AuditEntry> _rows = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _requestId = 0;
  String? _kind; // null = all

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await fetchAudit();
      if (!mounted || id != _requestId) return;
      setState(() {
        _rows = page.items;
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await fetchAudit(cursor: _cursor);
      if (!mounted) return;
      final seen = _rows.map((r) => r.id).toSet();
      setState(() {
        _rows = [..._rows, ...page.items.where((r) => seen.add(r.id))];
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _load());
    final counts = <String, int>{};
    for (final r in _rows) {
      final k = actionKind(r.action);
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final kinds = _kindStyle.keys.where(counts.containsKey).toList();
    final visible = _kind == null
        ? _rows
        : _rows.where((r) => actionKind(r.action) == _kind).toList();

    return PageScroll(
      children: [
        if (!_loading && _error == null && _rows.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('All  ${_rows.length}'),
                selected: _kind == null,
                showCheckmark: false,
                selectedColor: AdminPalette.accentSoft,
                onSelected: (_) => setState(() => _kind = null),
              ),
              for (final k in kinds)
                ChoiceChip(
                  avatar: Icon(_kindStyle[k]!.$2,
                      size: 16, color: _kindStyle[k]!.$3),
                  label: Text('${_kindStyle[k]!.$1}  ${counts[k]}'),
                  selected: _kind == k,
                  showCheckmark: false,
                  selectedColor: _kindStyle[k]!.$3.withValues(alpha: 0.12),
                  onSelected: (_) =>
                      setState(() => _kind = _kind == k ? null : k),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        PanelCard(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: TableSkeleton(),
                )
              : _error != null
                  ? ErrorState(error: _error!, onRetry: _load)
                  : visible.isEmpty
                      ? EmptyState(
                          title: _rows.isEmpty
                              ? 'No admin activity yet'
                              : 'Nothing matches this filter',
                          subtitle: _rows.isEmpty
                              ? 'Moderation and settings changes are '
                                  'recorded here.'
                              : null,
                          icon: Icons.history_rounded)
                      : Column(
                          children: [
                            for (final (i, e) in visible.indexed)
                              _ActivityTile(
                                  entry: e, last: i == visible.length - 1),
                          ],
                        ),
        ),
        if (!_loading && _error == null && _cursor != null)
          LoadMoreButton(loading: _loadingMore, onPressed: _loadMore),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry, required this.last});
  final AuditEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (_, icon, color) = _kindStyle[actionKind(entry.action)]!;
    final details = _detailsText(entry);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail: icon with a connector line below it.
          SizedBox(
            width: 56,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 4),
                      color: AdminPalette.border,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(auditSentence(entry),
                            style: const TextStyle(
                                fontSize: 13.5, height: 1.4)),
                      ),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: formatDateTime(entry.at),
                        child: Text(timeAgo(entry.at),
                            style: const TextStyle(
                                fontSize: 12, color: AdminPalette.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminPalette.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AdminPalette.border),
                        ),
                        child: Text(entry.action,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: AdminPalette.inkSoft)),
                      ),
                      if (entry.targetId != null)
                        Text('ID ${entry.targetId}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AdminPalette.muted)),
                    ],
                  ),
                  if (details != null) ...[
                    const SizedBox(height: 6),
                    Text(details,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AdminPalette.muted)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
