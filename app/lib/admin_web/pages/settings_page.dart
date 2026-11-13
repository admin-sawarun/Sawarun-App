import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../data/admin_web_api.dart';
import '../widgets/common.dart';

const _supportEmail = 'admin-sawarun@savarun.in';
const _appPackage = 'com.savarun.savarun';
const _adminWebVersion = '1.1.0';

/// Fallback paths when the backend doesn't report its legal links.
const _defaultLinks = {
  'privacy': '/privacy',
  'terms': '/terms',
  'accountDeletion': '/account-deletion',
  'childSafety': '/child-safety',
};

Future<void> _open(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null &&
      await launchUrl(uri, webOnlyWindowName: '_blank').catchError((_) => false);
  if (!ok && context.mounted) {
    showToast(context, 'Could not open $url', error: true);
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sys = ref.watch(systemInfoProvider);
    return PageScroll(
      children: [
        LayoutBuilder(builder: (context, c) {
          final status = _SystemStatusCard(sys: sys);
          final featured = _FeaturedBrandCard(sys: sys);
          final legal = _LegalCard(sys: sys);
          const about = _AboutCard();
          if (c.maxWidth < 960) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                status,
                const SizedBox(height: 20),
                featured,
                const SizedBox(height: 20),
                legal,
                const SizedBox(height: 20),
                about,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [status, const SizedBox(height: 20), about],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [featured, const SizedBox(height: 20), legal],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

Widget _kv(String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(k,
                style:
                    const TextStyle(fontSize: 13, color: AdminPalette.muted)),
          ),
          Expanded(child: v),
        ],
      ),
    );

Widget _kvText(String k, String? v) => _kv(
    k,
    SelectableText(v ?? '—',
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)));

class _SystemStatusCard extends ConsumerWidget {
  const _SystemStatusCard({required this.sys});
  final AsyncValue<SystemInfo> sys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelCard(
      title: 'System status',
      subtitle: AppConfig.backendBaseUrl,
      child: sys.when(
        skipLoadingOnRefresh: false,
        loading: () => const TableSkeleton(rows: 5),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _kv('Backend', const StatusChip('banned', label: 'Unreachable')),
            ErrorState(
                error: e, onRetry: () => ref.invalidate(systemInfoProvider)),
          ],
        ),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _kv(
              'Backend',
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusChip('active', label: 'Reachable ✓'),
              ),
            ),
            _kvText('Version', s.backendVersion),
            _kvText('Environment', s.nodeEnv),
            _kvText(
                'AI',
                [s.aiProvider, s.aiModel].whereType<String>().join(' · ')
                    .ifEmpty()),
            _kvText('Storage', s.storageDriver),
            _kvText('Server time', formatDateTime(s.serverTime)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in const {
                  'users': 'Users',
                  'posts': 'Posts',
                  'brands': 'Brands',
                  'products': 'Products',
                }.entries)
                  Container(
                    width: 96,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AdminPalette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminPalette.border),
                    ),
                    child: Column(
                      children: [
                        Text(formatCount(s.counts[e.key]),
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
          ],
        ),
      ),
    );
  }
}

extension on String {
  String? ifEmpty() => isEmpty ? null : this;
}

class _FeaturedBrandCard extends ConsumerStatefulWidget {
  const _FeaturedBrandCard({required this.sys});
  final AsyncValue<SystemInfo> sys;

  @override
  ConsumerState<_FeaturedBrandCard> createState() =>
      _FeaturedBrandCardState();
}

class _FeaturedBrandCardState extends ConsumerState<_FeaturedBrandCard> {
  bool _busy = false;

  Future<void> _change(String? currentId) async {
    final picked = await showDialog<BrandRow>(
      context: context,
      builder: (_) => _BrandPickerDialog(currentId: currentId),
    );
    if (picked == null || picked.id == currentId) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminWebRepoProvider).setFeaturedBrand(picked.id);
      ref.invalidate(systemInfoProvider);
      ref.invalidate(featuredBrandIdProvider);
      if (mounted) showToast(context, '${picked.name} is now featured');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sys.value;
    final loading = widget.sys.isLoading;
    return PanelCard(
      title: 'Featured brand',
      subtitle: 'Shown in the Featured slot of the in-app Shop',
      child: loading
          ? const TableSkeleton(rows: 1)
          : widget.sys.hasError
              ? const Text('Unavailable while the backend is unreachable.',
                  style: TextStyle(fontSize: 13, color: AdminPalette.muted))
              : Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB7791F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: Color(0xFFB7791F)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s?.featuredBrandName ??
                            (s?.featuredBrandId == null
                                ? 'No featured brand'
                                : 'Brand ${s!.featuredBrandId}'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: s?.featuredBrandId == null
                                ? AdminPalette.muted
                                : AdminPalette.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed:
                          _busy ? null : () => _change(s?.featuredBrandId),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Change'),
                    ),
                  ],
                ),
    );
  }
}

class _BrandPickerDialog extends ConsumerStatefulWidget {
  const _BrandPickerDialog({required this.currentId});
  final String? currentId;

  @override
  ConsumerState<_BrandPickerDialog> createState() => _BrandPickerDialogState();
}

class _BrandPickerDialogState extends ConsumerState<_BrandPickerDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(brandsByStatusProvider('approved'));
    return AlertDialog(
      title: const Text('Choose featured brand'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search approved brands',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AsyncBody<List<BrandRow>>(
                value: brands,
                onRetry: () =>
                    ref.invalidate(brandsByStatusProvider('approved')),
                loading: const TableSkeleton(rows: 5),
                builder: (list) {
                  final shown = list
                      .where((b) => _q.isEmpty ||
                          b.name.toLowerCase().contains(_q))
                      .toList();
                  if (shown.isEmpty) {
                    return EmptyState(
                      title: list.isEmpty
                          ? 'No approved brands'
                          : 'No brands match',
                      subtitle: list.isEmpty
                          ? 'Approve a brand on the Brands page first.'
                          : null,
                      icon: Icons.storefront_outlined,
                    );
                  }
                  return ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, i) {
                      final b = shown[i];
                      final current = b.id == widget.currentId;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        leading: NetImage(b.logoUrl,
                            width: 40,
                            height: 40,
                            fallbackIcon: Icons.storefront_outlined),
                        title: Text(b.name,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: b.website == null
                            ? null
                            : Text(b.website!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AdminPalette.muted)),
                        trailing: current
                            ? const StatusChip('featured', label: 'Current')
                            : null,
                        onTap: () => Navigator.of(context).pop(b),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({required this.sys});
  final AsyncValue<SystemInfo> sys;

  @override
  Widget build(BuildContext context) {
    final links = sys.value?.links ?? const {};
    const items = [
      ('privacy', 'Privacy policy', Icons.privacy_tip_outlined),
      ('terms', 'Terms of service', Icons.gavel_rounded),
      ('accountDeletion', 'Account deletion', Icons.person_remove_outlined),
      ('childSafety', 'Child safety standards', Icons.child_care_rounded),
    ];
    String urlFor(String key) {
      final link = links[key] ?? _defaultLinks[key]!;
      if (link.startsWith('http')) return link;
      return '${AppConfig.backendBaseUrl}${link.startsWith('/') ? '' : '/'}$link';
    }

    return PanelCard(
      title: 'Legal & support',
      subtitle: 'Public pages linked from the app and store listings',
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (key, label, icon) in items)
            _LinkTile(
              icon: icon,
              label: label,
              detail: urlFor(key),
              onTap: () => _open(context, urlFor(key)),
            ),
          const Divider(),
          _LinkTile(
            icon: Icons.support_agent_rounded,
            label: 'Support email',
            detail: _supportEmail,
            trailingIcon: Icons.mail_outline_rounded,
            onTap: () => _open(context, 'mailto:$_supportEmail'),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.trailingIcon = Icons.open_in_new_rounded,
  });
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AdminPalette.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(detail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AdminPalette.muted)),
                ],
              ),
            ),
            Icon(trailingIcon, size: 18, color: AdminPalette.muted),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kvText('App', 'Savarun'),
          _kvText('App package', _appPackage),
          _kvText('Admin website', 'v$_adminWebVersion'),
          _kvText('Backend URL', AppConfig.backendBaseUrl),
        ],
      ),
    );
  }
}
