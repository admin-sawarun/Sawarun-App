import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import 'data/trending_fashion_providers.dart';

/// Trending Fashion (CR-1) — the admin-curated feed, as its own full page.
/// Each card opens the affiliate link the admin attached (the tap is recorded
/// server-side first).
class TrendingFashionScreen extends ConsumerWidget {
  const TrendingFashionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(trendingFashionProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Trending Fashion')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _Empty(
          message: "Couldn't load Trending Fashion. Please try again.",
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _Empty(message: 'Nothing trending yet — check back soon.');
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, i) =>
                    _TrendingCard(item: list[i], height: 200),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The Home-screen strip: a header, a "See all" link, and a horizontal row of
/// curated cards. Renders nothing until the admin has added some.
class TrendingFashionSection extends ConsumerWidget {
  const TrendingFashionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(trendingFashionProvider);

    return items.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final shown = list.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Trending Fashion',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(Routes.trendingFashion),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(
                  width: 240,
                  child: _TrendingCard(item: shown[i], height: 190),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single curated card. Handles the tap: records the click, then opens the
/// admin's affiliate link in the browser. Busy state blocks a double-tap.
class _TrendingCard extends ConsumerStatefulWidget {
  const _TrendingCard({required this.item, required this.height});
  final TrendingFashionItem item;
  final double height;

  @override
  ConsumerState<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends ConsumerState<_TrendingCard> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url =
          await ref.read(trendingFashionRepoProvider).resolveUrl(widget.item.id);
      if (url.isEmpty) throw Exception('No link is set for this item yet');
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open the link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTap: _open,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: AppColors.surface,
                child: item.imageUrl.isEmpty
                    ? const Icon(Icons.checkroom_rounded,
                        size: 40, color: AppColors.inkMuted)
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                            Icons.image_outlined,
                            size: 40,
                            color: AppColors.inkMuted),
                      ),
              ),
              // Bottom gradient so text stays readable over any image.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.title.isNotEmpty)
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFE6E6EA),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Shop now',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.north_east_rounded,
                              size: 13, color: AppColors.ink),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tap feedback while the click is being recorded.
              if (_busy)
                Container(
                  color: const Color(0x55000000),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_fire_department_outlined,
                size: 44, color: AppColors.inkMuted),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
