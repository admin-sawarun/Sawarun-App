import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_web_api.dart';
import '../widgets/common.dart';

class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key});

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  final Set<String> _busy = {};

  Future<void> _add() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddAdminDialog(),
    );
    if (added == true) ref.invalidate(adminTeamProvider);
  }

  Future<void> _remove(AdminMember m) async {
    final ok = await confirmAction(
      context,
      title: 'Remove ${m.label}?',
      message: '${m.email ?? m.label} will lose access to the admin dashboard '
          'and all admin APIs. Their user account is not deleted.',
      confirmLabel: 'Remove admin',
    );
    if (!ok) return;
    setState(() => _busy.add(m.uid));
    try {
      await ref.read(adminWebRepoProvider).removeAdmin(m.uid);
      if (mounted) showToast(context, '${m.label} removed from the team');
      ref.invalidate(adminTeamProvider);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(m.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(adminTeamProvider);
    final me = FirebaseAuth.instance.currentUser?.uid;

    return PageScroll(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                team.hasValue
                    ? '${team.value!.length} admin${team.value!.length == 1 ? '' : 's'} '
                        'with dashboard access'
                    : 'People with access to this dashboard',
                style:
                    const TextStyle(fontSize: 13, color: AdminPalette.muted),
              ),
            ),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add admin'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PanelCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AsyncBody<List<AdminMember>>(
            value: team,
            onRetry: () => ref.invalidate(adminTeamProvider),
            loading: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: TableSkeleton(rows: 4),
            ),
            builder: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                    title: 'No admins listed',
                    icon: Icons.admin_panel_settings_outlined);
              }
              return WideTable(
                child: DataTable(
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('ADMIN')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('LAST SIGN-IN')),
                    DataColumn(label: Text('ADDED')),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (final m in list)
                      DataRow(cells: [
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(name: m.label),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(m.label,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      if (m.uid == me) ...[
                                        const SizedBox(width: 6),
                                        const Text('(you)',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AdminPalette.muted)),
                                      ],
                                    ],
                                  ),
                                  if (m.email != null && m.email != m.label)
                                    Text(m.email!,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AdminPalette.muted)),
                                ],
                              ),
                            ),
                          ],
                        )),
                        DataCell(StatusChip(m.disabled ? 'banned' : 'active',
                            label: m.disabled ? 'Disabled' : 'Active')),
                        DataCell(Tooltip(
                          message: formatDateTime(m.lastSignInAt),
                          child: Text(m.lastSignInAt == null
                              ? 'Never'
                              : timeAgo(m.lastSignInAt)),
                        )),
                        DataCell(Text(formatDate(m.createdAt))),
                        DataCell(Align(
                          alignment: Alignment.centerRight,
                          child: Tooltip(
                            message: m.uid == me
                                ? 'You cannot remove yourself'
                                : 'Remove admin access',
                            child: OutlinedButton.icon(
                              onPressed: m.uid == me || _busy.contains(m.uid)
                                  ? null
                                  : () => _remove(m),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AdminPalette.danger,
                                side: const BorderSide(
                                    color: Color(0xFFF2C4BF)),
                                minimumSize: const Size(0, 36),
                              ),
                              icon: _busy.contains(m.uid)
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.remove_moderator_outlined,
                                      size: 17),
                              label: const Text('Remove'),
                            ),
                          ),
                        )),
                      ]),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddAdminDialog extends ConsumerStatefulWidget {
  const _AddAdminDialog();

  @override
  ConsumerState<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends ConsumerState<_AddAdminDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.isNotEmpty && password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminWebRepoProvider)
          .addAdmin(email, password: password.isEmpty ? null : password);
      if (!mounted) return;
      showToast(context, '$email is now an admin');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add admin'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'They get full access to this dashboard. It takes effect the '
              'next time they sign in.',
              style: TextStyle(fontSize: 13, color: AdminPalette.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password (optional)',
                helperText:
                    "If the account doesn't exist, set a password to create it",
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show' : 'Hide',
                  icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 13, color: AdminPalette.danger)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Add admin'),
        ),
      ],
    );
  }
}
