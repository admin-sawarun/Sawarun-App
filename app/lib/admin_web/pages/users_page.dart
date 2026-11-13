import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_web_api.dart';
import '../widgets/common.dart';

const _statuses = ['all', 'active', 'verified', 'suspended', 'banned'];

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';
  String _status = 'all';

  List<UserRow> _users = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await fetchUsers(q: _q, status: _status);
      if (!mounted || id != _requestId) return;
      setState(() {
        _users = page.users;
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
      final page =
          await fetchUsers(q: _q, status: _status, cursor: _cursor);
      if (!mounted) return;
      final seen = _users.map((u) => u.uid).toSet();
      setState(() {
        _users = [..._users, ...page.users.where((u) => seen.add(u.uid))];
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (v.trim() == _q) return;
      _q = v.trim();
      _load();
    });
  }

  /// Client-side filter too, in case the backend ignores q/status.
  List<UserRow> get _visible {
    final q = _q.toLowerCase();
    return _users.where((u) {
      if (_status != 'all' && u.status != _status) return false;
      if (q.isEmpty) return true;
      return [u.name, u.username, u.email, u.phone, u.uid]
          .any((f) => f != null && f.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _open(UserRow u) async {
    await showUserDetailPanel(context, u, onStatusChanged: (s) {
      setState(() => u.status = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _load());
    final rows = _visible;
    return PageScroll(
      children: [
        PanelCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    _q = v.trim();
                    _load();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search name, username, email or phone',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final s in _statuses)
                    ButtonSegment(value: s, label: Text(capitalize(s))),
                ],
                selected: {_status},
                onSelectionChanged: (s) {
                  setState(() => _status = s.first);
                  _load();
                },
              ),
              if (!_loading && _error == null)
                Text('${rows.length} shown',
                    style: const TextStyle(
                        fontSize: 13, color: AdminPalette.muted)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PanelCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: TableSkeleton(),
                )
              : _error != null
                  ? ErrorState(error: _error!, onRetry: _load)
                  : rows.isEmpty
                      ? EmptyState(
                          title: 'No users found',
                          subtitle: _q.isEmpty && _status == 'all'
                              ? null
                              : 'Try a different search or filter.',
                          icon: Icons.person_search_outlined)
                      : _table(rows),
        ),
        if (!_loading && _error == null && _cursor != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.expand_more_rounded),
              label: const Text('Load more'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _table(List<UserRow> rows) {
    return WideTable(
      child: DataTable(
        showCheckboxColumn: false,
        dataRowMinHeight: 60,
        dataRowMaxHeight: 64,
        columns: const [
          DataColumn(label: Text('USER')),
          DataColumn(label: Text('CONTACT')),
          DataColumn(label: Text('STYLE')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('FOLLOWERS'), numeric: true),
          DataColumn(label: Text('LAST ACTIVE')),
          DataColumn(label: Text('JOINED')),
        ],
        rows: [
          for (final u in rows)
            DataRow(
              onSelectChanged: (_) => _open(u),
              cells: [
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(url: u.photoURL, name: u.name),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.name,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          if (u.username != null)
                            Text('@${u.username}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AdminPalette.muted)),
                        ],
                      ),
                    ),
                  ],
                )),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(u.email ?? u.phone ?? '—',
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(Text(u.style == null ? '—' : capitalize(u.style!))),
                DataCell(StatusChip(u.status)),
                DataCell(Text(formatCount(u.followers))),
                DataCell(Text(timeAgo(u.lastActiveAt))),
                DataCell(Text(formatDate(u.createdAt))),
              ],
            ),
        ],
      ),
    );
  }
}

/* ───────────────────────── Detail panel ───────────────────────── */

Future<void> showUserDetailPanel(
  BuildContext context,
  UserRow user, {
  required ValueChanged<String> onStatusChanged,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x40101018),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: MediaQuery.sizeOf(ctx).width.clamp(320.0, 520.0),
        height: double.infinity,
        child: Material(
          color: Colors.white,
          child: _UserDetailPanel(user: user, onStatusChanged: onStatusChanged),
        ),
      ),
    ),
    transitionBuilder: (_, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _UserDetailPanel extends ConsumerStatefulWidget {
  const _UserDetailPanel({required this.user, required this.onStatusChanged});
  final UserRow user;
  final ValueChanged<String> onStatusChanged;

  @override
  ConsumerState<_UserDetailPanel> createState() => _UserDetailPanelState();
}

class _UserDetailPanelState extends ConsumerState<_UserDetailPanel> {
  bool _busy = false;

  Future<void> _moderate(String action, String status) async {
    final u = widget.user;
    const labels = {
      'verify': 'Verify',
      'suspend': 'Suspend',
      'ban': 'Ban',
      'reinstate': 'Unban',
    };
    final label = labels[action]!;
    if (action == 'suspend' || action == 'ban') {
      final ok = await confirmAction(
        context,
        title: '$label ${u.name}?',
        message: action == 'ban'
            ? 'The account is disabled and signed out everywhere. You can '
                'unban it later.'
            : 'The account is disabled and signed out until reinstated.',
        confirmLabel: label,
      );
      if (!ok) return;
    }
    await _run(() async {
      await ref.read(adminWebRepoProvider).moderateUser(u.uid, action);
      widget.onStatusChanged(status);
      return '${u.name}: $status';
    });
  }

  Future<void> _setAdmin(bool makeAdmin) async {
    final u = widget.user;
    final ok = await confirmAction(
      context,
      title: makeAdmin ? 'Make ${u.name} an admin?' : 'Remove admin access?',
      message: makeAdmin
          ? 'They will get full access to this dashboard and all admin APIs. '
              'It takes effect the next time they sign in.'
          : '${u.name} will lose access to the admin dashboard.',
      confirmLabel: makeAdmin ? 'Make admin' : 'Remove admin',
      destructive: !makeAdmin,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(adminWebRepoProvider).setAdmin(u.uid, makeAdmin);
      return makeAdmin ? 'Admin access granted' : 'Admin access removed';
    });
  }

  Future<void> _run(Future<String> Function() task) async {
    setState(() => _busy = true);
    try {
      final msg = await task();
      ref.invalidate(userDetailProvider(widget.user.uid));
      if (mounted) showToast(context, msg);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final detail = ref.watch(userDetailProvider(u.uid));
    final d = detail.value;
    final status = d?.row.status ?? u.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AdminPalette.border))),
          child: Row(
            children: [
              const Expanded(
                child: Text('User details',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  UserAvatar(
                      url: d?.row.photoURL ?? u.photoURL, name: u.name, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d?.row.name ?? u.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        if ((d?.row.username ?? u.username) != null)
                          Text('@${d?.row.username ?? u.username}',
                              style: const TextStyle(
                                  color: AdminPalette.muted)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          StatusChip(status),
                          if (d?.isAdmin == true) const StatusChip('admin'),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              if (d?.bio != null) ...[
                const SizedBox(height: 16),
                Text(d!.bio!,
                    style: const TextStyle(
                        fontSize: 13.5, color: AdminPalette.inkSoft)),
              ],
              const SizedBox(height: 20),
              _actions(status, d?.isAdmin),
              const SizedBox(height: 24),
              _section('Contact'),
              _kv('Email', d?.row.email ?? u.email),
              _kv('Phone', d?.row.phone ?? u.phone),
              _kv('User ID', u.uid, selectable: true),
              _kv('Style', d?.row.style ?? u.style),
              _kv('Last active', timeAgo(d?.row.lastActiveAt ?? u.lastActiveAt)),
              _kv('Joined', formatDate(d?.row.createdAt ?? u.createdAt)),
              const SizedBox(height: 20),
              ...detail.when(
                skipLoadingOnRefresh: false,
                loading: () => const [TableSkeleton(rows: 4)],
                error: (e, _) => [
                  ErrorState(
                    error: e,
                    onRetry: () => ref.invalidate(userDetailProvider(u.uid)),
                  ),
                ],
                data: (d) => _detailSections(d),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _detailSections(UserDetail d) {
    const countLabels = {
      'posts': 'Posts',
      'analyses': 'Analyses',
      'wardrobe': 'Wardrobe',
      'followers': 'Followers',
      'following': 'Following',
    };
    return [
      _section('Activity'),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final e in countLabels.entries)
            Container(
              width: 86,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AdminPalette.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminPalette.border),
              ),
              child: Column(
                children: [
                  Text(formatCount(d.counts[e.key]),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(e.value,
                      style: const TextStyle(
                          fontSize: 11.5, color: AdminPalette.muted)),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      _section('Recent posts'),
      if (d.recentPosts.isEmpty)
        const Text('No posts yet.', style: TextStyle(color: AdminPalette.muted))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in d.recentPosts)
              Tooltip(
                message: formatDate(p.createdAt),
                child: NetImage(p.imageUrl, width: 102, height: 102),
              ),
          ],
        ),
      const SizedBox(height: 24),
      _section('Recent analyses'),
      if (d.recentAnalyses.isEmpty)
        const Text('No analyses yet.',
            style: TextStyle(color: AdminPalette.muted))
      else
        for (final a in d.recentAnalyses)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                NetImage(a.imageUrl, width: 44, height: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(formatDate(a.createdAt),
                      style: const TextStyle(fontSize: 13)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminPalette.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a.fitScore == null
                        ? '—'
                        : 'Fit ${a.fitScore!.round()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminPalette.accent),
                  ),
                ),
              ],
            ),
          ),
    ];
  }

  Widget _actions(String status, bool? isAdmin) {
    final restricted = status == 'banned' || status == 'suspended';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status != 'verified' && !restricted)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _moderate('verify', 'verified'),
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: const Text('Verify'),
          ),
        if (restricted)
          FilledButton.icon(
            onPressed: _busy ? null : () => _moderate('reinstate', 'active'),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Unban'),
          ),
        if (status != 'suspended')
          _dangerButton('Suspend', Icons.pause_circle_outline_rounded,
              () => _moderate('suspend', 'suspended')),
        if (status != 'banned')
          _dangerButton('Ban', Icons.block_rounded,
              () => _moderate('ban', 'banned')),
        if (isAdmin == true)
          _dangerButton('Remove admin', Icons.remove_moderator_outlined,
              () => _setAdmin(false))
        else
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _setAdmin(true),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('Make admin'),
          ),
      ],
    );
  }

  Widget _dangerButton(String label, IconData icon, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: _busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminPalette.danger,
          side: const BorderSide(color: Color(0xFFF2C4BF)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: AdminPalette.muted)),
      );

  Widget _kv(String k, String? v, {bool selectable = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style:
                      const TextStyle(fontSize: 13, color: AdminPalette.muted)),
            ),
            Expanded(
              child: selectable
                  ? SelectableText(v ?? '—', style: const TextStyle(fontSize: 13))
                  : Text(v ?? '—', style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
}
