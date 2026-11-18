import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

/// One admin-curated Trending Fashion card (CR-1). The affiliate URL is kept
/// on the server; the app fetches it only when the card is tapped, so the tap
/// is always recorded for the admin's analytics.
class TrendingFashionItem {
  const TrendingFashionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;

  factory TrendingFashionItem.fromJson(Map<String, dynamic> d) =>
      TrendingFashionItem(
        id: (d['id'] ?? '').toString(),
        title: (d['title'] ?? '').toString(),
        subtitle: (d['subtitle'] ?? '').toString(),
        imageUrl: (d['imageUrl'] ?? '').toString(),
      );
}

/// The curated Trending Fashion feed, admin-ordered. Renders nothing in the UI
/// until the admin has added at least one card.
final trendingFashionProvider =
    FutureProvider.autoDispose<List<TrendingFashionItem>>((ref) async {
  const client = ApiClient();
  final json = await client.get(AppConfig.trendingFashionEndpoint);
  return (json['data'] as List)
      .map((e) => TrendingFashionItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final trendingFashionRepoProvider =
    Provider((ref) => const TrendingFashionRepository());

class TrendingFashionRepository {
  const TrendingFashionRepository();

  /// Record the tap and return the affiliate URL the card should open.
  Future<String> resolveUrl(String id) async {
    const client = ApiClient();
    final json =
        await client.post(AppConfig.trendingFashionClickEndpoint, {'id': id});
    return (json['data'] as Map<String, dynamic>)['url']?.toString() ?? '';
  }
}
