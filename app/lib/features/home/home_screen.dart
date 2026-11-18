import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../analysis/data/history_providers.dart';
import '../profile/data/profile_providers.dart';
import '../shop/data/shop_providers.dart';
import '../shop/trending_fashion_screen.dart';
import '../social/widgets/feed_section.dart';
import 'camera_3d.dart';

/// Home — the design's greeting, the big "Analyze Outfit" orb, and a strip of
/// recent analyses.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final name = profile?.name.split(' ').first ?? 'there';
    final photo = profile?.photoURL;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()},',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '$name 👋',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push(Routes.settings),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.white,
                  backgroundImage:
                      (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                  child: (photo == null || photo.isEmpty)
                      ? const Icon(Icons.person_outline_rounded,
                          size: 20, color: AppColors.inkMuted)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Featured Brand (Module 4) — shown at the top of Home when the admin
          // sets one; renders nothing otherwise.
          const _FeaturedBrandBanner(),
          const SizedBox(height: 8),
          const Text(
            'How do you feel\nabout your outfit today?',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 24),
          // Tap the 3D camera itself to open the camera and analyze an outfit.
          Camera3DHero(onTap: () => context.push(Routes.camera)),
          const SizedBox(height: 40),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Analyses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push(Routes.outfitHistory),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _RecentStrip(),
          const SizedBox(height: 32),
          const TrendingFashionSection(),
          const SizedBox(height: 32),
          const _TrendingBrands(),
          const SizedBox(height: 32),
          const FeedSection(),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

/// Horizontal strip of the user's most recent analyses.
class _RecentStrip extends ConsumerWidget {
  const _RecentStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(outfitHistoryProvider);

    return history.when(
      loading: () => const SizedBox(
        height: 130,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => const SizedBox(
        height: 130,
        child: Center(
          child: Text(
            'Could not load history',
            style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Container(
            height: 130,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'No analyses yet — tap the orb to start.',
              style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
          );
        }

        final shown = items.take(10).toList();
        return SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _RecentCard(entry: shown[i]),
          ),
        );
      },
    );
  }
}

/// The admin-chosen Featured Brand banner (Module 4). Sits near the top of
/// Home and disappears entirely when no brand is featured.
class _FeaturedBrandBanner extends ConsumerWidget {
  const _FeaturedBrandBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredBrandProvider);

    return featured.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (fb) {
        if (fb == null || fb.products.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'FEATURED',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fb.brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: fb.products.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final p = fb.products[i];
                    return GestureDetector(
                      onTap: () =>
                          context.push(Routes.productDetails, extra: p),
                      child: SizedBox(
                        width: 92,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 92,
                                height: 92,
                                color: AppColors.white,
                                child: p.imageUrl.isEmpty
                                    ? const Icon(Icons.image_outlined,
                                        color: AppColors.inkMuted)
                                    : Image.network(
                                        p.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                            Icons.image_outlined,
                                            color: AppColors.inkMuted),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${p.price}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Trending Brands" section from Module 4 — the most-clicked approved
/// products. Hidden entirely until brands have listings.
class _TrendingBrands extends ConsumerWidget {
  const _TrendingBrands();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingProductsProvider);

    return trending.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final shown = items.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trending Brands',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = shown[i];
                  return GestureDetector(
                    onTap: () =>
                        context.push(Routes.productDetails, extra: p),
                    child: SizedBox(
                      width: 118,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 118,
                              height: 118,
                              color: AppColors.white,
                              child: p.imageUrl.isEmpty
                                  ? const Icon(Icons.image_outlined,
                                      color: AppColors.inkMuted)
                                  : Image.network(
                                      p.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                          Icons.image_outlined,
                                          color: AppColors.inkMuted),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.brandName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            '₹${p.price}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final url = entry.analysis.imageUrl;

    return GestureDetector(
      onTap: () =>
          context.push(Routes.analysisResult, extra: entry.analysis),
      child: SizedBox(
        width: 96,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 96,
                height: 130,
                color: AppColors.surface,
                child: (url != null && url.isNotEmpty)
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.checkroom_rounded,
                          color: AppColors.inkMuted,
                        ),
                      )
                    : const Icon(Icons.checkroom_rounded,
                        color: AppColors.inkMuted),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${entry.analysis.fitScore}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
