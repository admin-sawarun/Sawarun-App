import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/admin_web_api.dart';
import '../widgets/common.dart';

const _tabs = ['pending', 'approved', 'rejected', 'revoked'];

class BrandsPage extends ConsumerStatefulWidget {
  const BrandsPage({super.key});

  @override
  ConsumerState<BrandsPage> createState() => _BrandsPageState();
}

class _BrandsPageState extends ConsumerState<BrandsPage> {
  String _tab = 'pending';

  /// Set right after "Set as featured" so the badge moves immediately (the
  /// public featured endpoint hides brands that have no live products).
  String? _featuredOverride;

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(brandsByStatusProvider(_tab));
    final featured =
        _featuredOverride ?? ref.watch(featuredBrandIdProvider).value;

    return PageScroll(
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final t in _tabs)
                      ButtonSegment(value: t, label: Text(capitalize(t))),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AsyncBody<List<BrandRow>>(
          value: brands,
          onRetry: () => ref.invalidate(brandsByStatusProvider(_tab)),
          loading: const PanelCard(child: TableSkeleton(rows: 4)),
          builder: (list) {
            if (list.isEmpty) {
              return PanelCard(
                child: EmptyState(
                  title: 'No $_tab brands',
                  subtitle: _tab == 'pending'
                      ? 'New "Sell on Savarun" applications appear here.'
                      : null,
                  icon: Icons.storefront_outlined,
                ),
              );
            }
            return LayoutBuilder(builder: (context, c) {
              final cols = (c.maxWidth / 380).floor().clamp(1, 4);
              const gap = 16.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final b in list)
                    SizedBox(
                      width: w,
                      child: _BrandCard(
                        brand: b,
                        featured: b.id == featured,
                        onFeatured: () =>
                            setState(() => _featuredOverride = b.id),
                      ),
                    ),
                ],
              );
            });
          },
        ),
      ],
    );
  }
}

class _BrandCard extends ConsumerStatefulWidget {
  const _BrandCard({
    required this.brand,
    required this.featured,
    required this.onFeatured,
  });
  final BrandRow brand;
  final bool featured;
  final VoidCallback onFeatured;

  @override
  ConsumerState<_BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends ConsumerState<_BrandCard> {
  bool _busy = false;

  Future<void> _decide(String decision) async {
    final b = widget.brand;
    if (decision != 'approve') {
      final label = decision == 'reject' ? 'Reject' : 'Revoke';
      final ok = await confirmAction(
        context,
        title: '$label ${b.name}?',
        message: decision == 'reject'
            ? 'The application is rejected and the brand cannot list products.'
            : 'The brand loses its approval and its products leave the Shop.',
        confirmLabel: label,
      );
      if (!ok) return;
    }
    await _run(() async {
      await ref.read(adminWebRepoProvider).decideBrand(b.id, decision);
      for (final t in _tabs) {
        ref.invalidate(brandsByStatusProvider(t));
      }
      return switch (decision) {
        'approve' => '${b.name} approved',
        'reject' => '${b.name} rejected',
        _ => '${b.name} revoked',
      };
    });
  }

  Future<void> _feature() async {
    final b = widget.brand;
    final ok = await confirmAction(
      context,
      title: 'Feature ${b.name}?',
      message: 'It replaces the current brand in the Shop\'s Featured slot.',
      confirmLabel: 'Set as featured',
      destructive: false,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(adminWebRepoProvider).setFeaturedBrand(b.id);
      widget.onFeatured();
      return '${b.name} is now featured';
    });
  }

  Future<void> _run(Future<String> Function() task) async {
    setState(() => _busy = true);
    try {
      final msg = await task();
      if (mounted) showToast(context, msg);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.brand;
    return PanelCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NetImage(b.logoUrl,
                  width: 44,
                  height: 44,
                  radius: 10,
                  fallbackIcon: Icons.storefront_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(b.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (widget.featured) ...[
                const StatusChip('featured', label: '★ Featured'),
                const SizedBox(width: 6),
              ],
              StatusChip(b.status),
            ],
          ),
          if (b.description != null) ...[
            const SizedBox(height: 10),
            Text(b.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, color: AdminPalette.inkSoft)),
          ],
          const SizedBox(height: 14),
          _meta(Icons.language_rounded, b.website ?? 'No website',
              link: b.website),
          _meta(Icons.person_outline_rounded,
              '${b.ownerName}${b.ownerContact != null ? ' · ${b.ownerContact}' : ''}'),
          _meta(Icons.calendar_today_outlined,
              'Applied ${formatDate(b.createdAt)}'),
          const SizedBox(height: 16),
          if (_busy)
            const LinearProgressIndicator(minHeight: 2)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (b.status != 'approved')
                  FilledButton(
                    onPressed: () => _decide('approve'),
                    child: const Text('Approve'),
                  ),
                if (b.status == 'pending')
                  _danger('Reject', () => _decide('reject')),
                if (b.status == 'approved') ...[
                  if (!widget.featured)
                    OutlinedButton.icon(
                      onPressed: _feature,
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label: const Text('Set as featured'),
                    ),
                  _danger('Revoke', () => _decide('revoke')),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _danger(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminPalette.danger,
          side: const BorderSide(color: Color(0xFFF2C4BF)),
        ),
        child: Text(label),
      );

  Widget _meta(IconData icon, String text, {String? link}) {
    final row = Row(
      children: [
        Icon(icon, size: 16, color: AdminPalette.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: link != null ? AdminPalette.accent : AdminPalette.inkSoft,
              )),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: link == null
          ? row
          : InkWell(
              onTap: () {
                final uri = Uri.tryParse(
                    link.startsWith('http') ? link : 'https://$link');
                if (uri != null) launchUrl(uri);
              },
              child: row,
            ),
    );
  }
}
