import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

String _admin(String path) => '${AppConfig.backendBaseUrl}/api/admin$path';

/// Whether the signed-in user holds the `admin` custom claim. This is the
/// same gate the backend enforces; the UI uses it to show/hide the dashboard.
final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final token = await user.getIdTokenResult(true);
  return token.claims?['admin'] == true;
});

/* ── Models ── */

class AdminAnalytics {
  const AdminAnalytics({
    required this.totalUsers,
    required this.dailyActiveUsers,
    required this.trendingStyles,
    required this.topProducts,
  });

  final int totalUsers;
  final int dailyActiveUsers;
  final List<({String category, num weight})> trendingStyles;
  final List<({String name, int clicks})> topProducts;

  factory AdminAnalytics.fromJson(Map<String, dynamic> d) => AdminAnalytics(
        totalUsers: (d['totalUsers'] ?? 0) as int,
        dailyActiveUsers: (d['dailyActiveUsers'] ?? 0) as int,
        trendingStyles: (d['trendingStyles'] as List? ?? [])
            .map((s) => (
                  category: (s['category'] ?? '') as String,
                  weight: (s['weight'] ?? 0) as num,
                ))
            .toList(),
        topProducts: (d['topProducts'] as List? ?? [])
            .map((p) => (
                  name: (p['name'] ?? '') as String,
                  clicks: (p['clicks'] ?? 0) as int,
                ))
            .toList(),
      );
}

class AdminUser {
  const AdminUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoURL,
    required this.status,
  });
  final String uid;
  final String name;
  final String? email;
  final String? photoURL;
  final String status;

  factory AdminUser.fromJson(Map<String, dynamic> d) => AdminUser(
        uid: d['uid'] ?? '',
        name: d['name'] ?? 'Savarun User',
        email: d['email'],
        photoURL: d['photoURL'],
        status: d['status'] ?? 'active',
      );
}

class AdminBrand {
  const AdminBrand({
    required this.id,
    required this.name,
    required this.status,
    required this.ownerName,
    required this.ownerContact,
    required this.website,
  });
  final String id;
  final String name;
  final String status;
  final String ownerName;

  /// Email or phone of the applicant (whichever is available).
  final String? ownerContact;
  final String? website;

  factory AdminBrand.fromJson(Map<String, dynamic> d) => AdminBrand(
        id: d['id'] ?? '',
        name: d['name'] ?? '',
        status: d['status'] ?? 'pending',
        ownerName: d['ownerName'] ?? 'Unknown user',
        ownerContact: d['ownerContact'],
        website: d['website'],
      );
}

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.name,
    required this.brandName,
    required this.price,
    required this.approved,
    required this.hidden,
  });
  final String id;
  final String name;
  final String brandName;
  final num price;
  final bool approved;
  final bool hidden;

  factory AdminProduct.fromJson(Map<String, dynamic> d) => AdminProduct(
        id: d['id'] ?? '',
        name: d['name'] ?? '',
        brandName: d['brandName'] ?? '',
        price: (d['price'] ?? 0) as num,
        approved: d['approved'] == true,
        hidden: d['hidden'] == true,
      );
}

/// An admin-curated Trending Fashion card (CR-1), as the admin panel sees it
/// (includes the affiliate link + hidden flag, unlike the public feed).
class AdminTrendingItem {
  const AdminTrendingItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.affiliateUrl,
    required this.order,
    required this.hidden,
    required this.clicks,
  });
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String affiliateUrl;
  final int order;
  final bool hidden;
  final int clicks;

  factory AdminTrendingItem.fromJson(Map<String, dynamic> d) => AdminTrendingItem(
        id: (d['id'] ?? '').toString(),
        title: (d['title'] ?? '').toString(),
        subtitle: (d['subtitle'] ?? '').toString(),
        imageUrl: (d['imageUrl'] ?? '').toString(),
        affiliateUrl: (d['affiliateUrl'] ?? '').toString(),
        order: (d['order'] ?? 0) as int,
        hidden: d['hidden'] == true,
        clicks: (d['clicks'] ?? 0) as int,
      );
}

class AdminReport {
  const AdminReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetUid,
    required this.reason,
    required this.details,
    required this.reporterUid,
    required this.status,
    required this.createdAt,
    required this.targetName,
    required this.reporterName,
    required this.resolution,
  });
  final String id;
  final String targetType;
  final String targetId;
  final String targetUid;
  final String reason;
  final String? details;
  final String reporterUid;
  final String status;
  final DateTime? createdAt;

  /// Optional display names the backend may attach.
  final String? targetName;
  final String? reporterName;

  /// The action taken, on resolved reports (if the backend returns it).
  final String? resolution;

  factory AdminReport.fromJson(Map<String, dynamic> d) => AdminReport(
        id: (d['id'] ?? '').toString(),
        targetType: (d['targetType'] ?? '').toString(),
        targetId: (d['targetId'] ?? '').toString(),
        targetUid: (d['targetUid'] ?? '').toString(),
        reason: (d['reason'] ?? 'other').toString(),
        details: d['details'] as String?,
        reporterUid: (d['reporterUid'] ?? '').toString(),
        status: (d['status'] ?? 'open').toString(),
        createdAt: _parseTime(d['createdAt']),
        targetName: (d['targetName'] ?? d['targetUserName']) as String?,
        reporterName: d['reporterName'] as String?,
        resolution: (d['action'] ?? d['resolution']) as String?,
      );
}

/// Accepts ISO strings, epoch millis, or Firestore `{_seconds}` / `{seconds}`
/// maps — whichever shape the backend serialises timestamps to.
DateTime? _parseTime(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is Map) {
    final s = v['_seconds'] ?? v['seconds'];
    if (s is num) {
      return DateTime.fromMillisecondsSinceEpoch((s * 1000).round());
    }
  }
  return null;
}

/* ── Providers ── */

final adminAnalyticsProvider =
    FutureProvider.autoDispose<AdminAnalytics>((ref) async {
  const client = ApiClient();
  final json = await client.get(_admin('/analytics'));
  return AdminAnalytics.fromJson(json['data'] as Map<String, dynamic>);
});

final adminUsersProvider =
    FutureProvider.autoDispose<List<AdminUser>>((ref) async {
  const client = ApiClient();
  final json = await client.get(_admin('/users'));
  return (json['data'] as List).map((u) => AdminUser.fromJson(u)).toList();
});

final adminBrandsProvider =
    FutureProvider.autoDispose<List<AdminBrand>>((ref) async {
  const client = ApiClient();
  final json = await client.get(_admin('/brands'));
  return (json['data'] as List).map((b) => AdminBrand.fromJson(b)).toList();
});

final adminProductsProvider =
    FutureProvider.autoDispose<List<AdminProduct>>((ref) async {
  const client = ApiClient();
  final json = await client.get(_admin('/products'));
  return (json['data'] as List).map((p) => AdminProduct.fromJson(p)).toList();
});

final adminFitWeightsProvider =
    FutureProvider.autoDispose<Map<String, num>>((ref) async {
  const client = ApiClient();
  final json = await client.get(_admin('/fit-weights'));
  final data = json['data'] as Map<String, dynamic>;
  return data.map((k, v) => MapEntry(k, (v ?? 0) as num));
});

/// Reports for the moderation queue, by status ('open' | 'resolved').
final adminReportsProvider = FutureProvider.autoDispose
    .family<List<AdminReport>, String>((ref, status) async {
  const client = ApiClient();
  final json = await client.get(_admin('/reports?status=$status'));
  return (json['data'] as List)
      .map((r) => AdminReport.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Trending Fashion cards for the admin panel (all, incl. hidden).
final adminTrendingFashionProvider =
    FutureProvider.autoDispose<List<AdminTrendingItem>>((ref) async {
  const client = ApiClient();
  final json = await client.get(_admin('/trending-fashion'));
  return (json['data'] as List)
      .map((e) => AdminTrendingItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final adminRepoProvider = Provider((ref) => const AdminRepository());

class AdminRepository {
  const AdminRepository();

  Future<void> moderateUser(String uid, String action) =>
      const ApiClient().post(_admin('/users/$uid/moderate'), {'action': action});

  Future<void> decideBrand(String id, bool approve) => const ApiClient()
      .post(_admin('/brands/$id/decision'),
          {'decision': approve ? 'approve' : 'reject'});

  Future<void> setProductApproval(String id, bool approved) => const ApiClient()
      .patch(_admin('/products/$id/approval'), {'approved': approved});

  Future<void> setProductHidden(String id, bool hidden) => const ApiClient()
      .patch(_admin('/products/$id/visibility'), {'hidden': hidden});

  /// Show this (approved) brand in the Shop's Featured Brand slot.
  Future<void> setFeaturedBrand(String brandId) => const ApiClient()
      .put(_admin('/featured-brand'), {'brandId': brandId});

  /// Resolve a report: 'dismiss' | 'remove_content' | 'ban_user'.
  Future<void> resolveReport(String id, String action) => const ApiClient()
      .post(_admin('/reports/$id/resolve'), {'action': action});

  Future<void> saveFitWeights(Map<String, num> weights) =>
      const ApiClient().put(_admin('/fit-weights'), weights);

  /* ── Trending Fashion (CR-1) ── */

  Future<void> createTrending({
    required String title,
    String subtitle = '',
    String imageUrl = '',
    required String affiliateUrl,
    int order = 0,
  }) =>
      const ApiClient().post(_admin('/trending-fashion'), {
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'affiliateUrl': affiliateUrl,
        'order': order,
      });

  Future<void> updateTrending(String id, Map<String, dynamic> fields) =>
      const ApiClient().patch(_admin('/trending-fashion/$id'), fields);

  Future<void> deleteTrending(String id) =>
      const ApiClient().delete(_admin('/trending-fashion/$id'));
}
