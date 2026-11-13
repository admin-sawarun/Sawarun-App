import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../features/admin/data/admin_service.dart'
    show adminFitWeightsProvider, adminReportsProvider, AdminRepository;
import '../widgets/common.dart';

const _api = ApiClient();

String adminUrl(String path) => '${AppConfig.backendBaseUrl}/api/admin$path';

/* ───────────────────────── Refresh ───────────────────────── */

/// Bumped by the top-bar refresh button. Every data provider watches it, so
/// incrementing it reloads whatever page is on screen.
class RefreshTick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final refreshTickProvider = NotifierProvider<RefreshTick, int>(RefreshTick.new);

void refreshAll(WidgetRef ref) {
  ref.read(refreshTickProvider.notifier).bump();
  // Providers shared with the in-app admin don't watch the tick.
  ref.invalidate(adminReportsProvider);
  ref.invalidate(adminFitWeightsProvider);
}

/* ───────────────────────── Dashboard ───────────────────────── */

class DashboardStats {
  DashboardStats({
    required this.totalUsers,
    required this.activeToday,
    required this.newUsersThisWeek,
    required this.totalAnalyses,
    required this.totalPosts,
    required this.openReports,
    required this.pendingBrands,
    required this.trendingStyles,
    required this.topProducts,
  });

  final int? totalUsers;
  final int? activeToday;
  final int? newUsersThisWeek;
  final int? totalAnalyses;
  final int? totalPosts;
  final int? openReports;
  final int? pendingBrands;
  final List<({String category, double weight})> trendingStyles;
  final List<({String id, String name, int clicks, String? imageUrl})>
      topProducts;
}

final dashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) async {
  ref.watch(refreshTickProvider);
  final json = await _api.get(adminUrl('/analytics'));
  final d = (json['data'] as Map?)?.cast<String, dynamic>() ?? {};

  // Older backends don't return these counts; derive them from the lists.
  var openReports = toIntOrNull(d['openReports']);
  var pendingBrands = toIntOrNull(d['pendingBrands']);
  await Future.wait([
    if (openReports == null)
      _api
          .get(adminUrl('/reports?status=open'))
          .then((r) => openReports = (r['data'] as List?)?.length)
          .catchError((_) => null),
    if (pendingBrands == null)
      _api
          .get(adminUrl('/brands?status=pending'))
          .then((r) => pendingBrands = (r['data'] as List?)?.length)
          .catchError((_) => null),
  ]);

  return DashboardStats(
    totalUsers: toIntOrNull(d['totalUsers']),
    activeToday: toIntOrNull(d['activeToday'] ?? d['dailyActiveUsers']),
    newUsersThisWeek: toIntOrNull(d['newUsersThisWeek']),
    totalAnalyses: toIntOrNull(d['totalAnalyses']),
    totalPosts: toIntOrNull(d['totalPosts']),
    openReports: openReports,
    pendingBrands: pendingBrands,
    trendingStyles: [
      for (final s in (d['trendingStyles'] as List? ?? const []))
        if (s is Map)
          (
            category: str(s['category']) ?? 'Other',
            weight: toNum(s['weight']).toDouble(),
          ),
    ],
    topProducts: [
      for (final p in (d['topProducts'] as List? ?? const []))
        if (p is Map)
          (
            id: str(p['id']) ?? '',
            name: str(p['name']) ?? 'Untitled product',
            clicks: toInt(p['clicks']),
            imageUrl: str(p['imageUrl']),
          ),
    ],
  );
});

class TimeSeries {
  TimeSeries({required this.days, required this.series});
  final List<DateTime> days;

  /// key → values aligned with [days].
  final Map<String, List<double>> series;

  static const keys = ['signups', 'activeUsers', 'analyses', 'posts', 'clicks'];
}

final timeSeriesProvider =
    FutureProvider.autoDispose.family<TimeSeries, int>((ref, days) async {
  ref.watch(refreshTickProvider);
  final json = await _api.get(adminUrl('/analytics/timeseries?days=$days'));
  final d = (json['data'] as Map?)?.cast<String, dynamic>() ?? {};
  final dayList = [
    for (final s in (d['days'] as List? ?? const []))
      parseTime(s) ?? DateTime.now(),
  ];
  final series = <String, List<double>>{};
  for (final k in TimeSeries.keys) {
    final raw = (d[k] as List? ?? const [])
        .map((v) => toNum(v).toDouble())
        .toList();
    // Pad/trim to the day count so the chart never indexes out of range.
    series[k] = List.generate(
        dayList.length, (i) => i < raw.length ? raw[i] : 0.0);
  }
  return TimeSeries(days: dayList, series: series);
});

/* ───────────────────────── Users ───────────────────────── */

class UserRow {
  UserRow({
    required this.uid,
    required this.name,
    this.username,
    this.email,
    this.phone,
    this.photoURL,
    this.style,
    required this.status,
    required this.followers,
    this.lastActiveAt,
    this.createdAt,
    this.postsCount,
    this.analysesCount,
  });

  final String uid;
  final String name;
  final String? username;
  final String? email;
  final String? phone;
  final String? photoURL;
  final String? style;
  String status;
  final int followers;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final int? postsCount;
  final int? analysesCount;

  factory UserRow.fromJson(Map<String, dynamic> d) {
    final contact = (d['contact'] as Map?) ?? const {};
    return UserRow(
      uid: str(d['uid']) ?? str(d['id']) ?? '',
      name: str(d['name']) ?? str(d['username']) ?? 'Savarun User',
      username: str(d['username']),
      email: str(d['email']) ?? str(contact['email']),
      phone: str(d['phone']) ?? str(contact['phone']),
      photoURL: str(d['photoURL']),
      style: str(d['style']),
      status: str(d['status']) ?? 'active',
      followers: toInt(d['followers']),
      lastActiveAt: parseTime(d['lastActiveAt']),
      createdAt: parseTime(d['createdAt']),
      postsCount: toIntOrNull(d['postsCount']),
      analysesCount: toIntOrNull(d['analysesCount']),
    );
  }
}

class UsersPage {
  UsersPage(this.users, this.nextCursor);
  final List<UserRow> users;
  final String? nextCursor;
}

Future<UsersPage> fetchUsers({
  String q = '',
  String status = 'all',
  String? cursor,
  int limit = 50,
}) async {
  final params = <String, String>{
    'limit': '$limit',
    if (q.isNotEmpty) 'q': q,
    if (status != 'all') 'status': status,
    'cursor': ?cursor,
  };
  final query = Uri(queryParameters: params).query;
  final json = await _api.get(adminUrl('/users?$query'));
  final users = [
    for (final u in (json['data'] as List? ?? const []))
      if (u is Map) UserRow.fromJson(u.cast<String, dynamic>()),
  ];
  return UsersPage(users, str(json['nextCursor']));
}

class UserDetail {
  UserDetail({
    required this.row,
    required this.isAdmin,
    required this.bio,
    required this.counts,
    required this.recentPosts,
    required this.recentAnalyses,
  });

  final UserRow row;
  final bool isAdmin;
  final String? bio;
  final Map<String, int?> counts;
  final List<({String id, String? imageUrl, DateTime? createdAt})> recentPosts;
  final List<({num? fitScore, String? imageUrl, DateTime? createdAt})>
      recentAnalyses;

  factory UserDetail.fromJson(Map<String, dynamic> d) {
    final counts = (d['counts'] as Map?) ?? const {};
    return UserDetail(
      row: UserRow.fromJson(d),
      isAdmin: d['isAdmin'] == true || d['admin'] == true,
      bio: str(d['bio']),
      counts: {
        for (final k in ['posts', 'analyses', 'wardrobe', 'followers', 'following'])
          k: toIntOrNull(counts[k] ?? d[k]),
      },
      recentPosts: [
        for (final p in (d['recentPosts'] as List? ?? const []))
          if (p is Map)
            (
              id: str(p['id']) ?? '',
              imageUrl: str(p['imageUrl']),
              createdAt: parseTime(p['createdAt']),
            ),
      ],
      recentAnalyses: [
        for (final a in (d['recentAnalyses'] as List? ?? const []))
          if (a is Map)
            (
              fitScore: a['fitScore'] is num
                  ? a['fitScore'] as num
                  : num.tryParse('${a['fitScore']}'),
              imageUrl: str(a['imageUrl']),
              createdAt: parseTime(a['createdAt']),
            ),
      ],
    );
  }
}

final userDetailProvider =
    FutureProvider.autoDispose.family<UserDetail, String>((ref, uid) async {
  ref.watch(refreshTickProvider);
  final json = await _api.get(adminUrl('/users/$uid'));
  return UserDetail.fromJson(
      (json['data'] as Map?)?.cast<String, dynamic>() ?? {'uid': uid});
});

/* ───────────────────────── Brands ───────────────────────── */

class BrandRow {
  BrandRow({
    required this.id,
    required this.name,
    required this.status,
    this.website,
    this.logoUrl,
    this.description,
    required this.ownerName,
    this.ownerContact,
    this.createdAt,
  });
  final String id;
  final String name;
  final String status;
  final String? website;
  final String? logoUrl;
  final String? description;
  final String ownerName;
  final String? ownerContact;
  final DateTime? createdAt;

  factory BrandRow.fromJson(Map<String, dynamic> d) => BrandRow(
        id: str(d['id']) ?? '',
        name: str(d['name']) ?? 'Unnamed brand',
        status: str(d['status']) ?? 'pending',
        website: str(d['website']),
        logoUrl: str(d['logoUrl']) ?? str(d['logo']),
        description: str(d['description']),
        ownerName: str(d['ownerName']) ?? 'Unknown user',
        ownerContact: str(d['ownerContact']) ??
            str(d['ownerEmail']) ??
            str(d['ownerPhone']),
        createdAt: parseTime(d['createdAt']),
      );
}

final brandsByStatusProvider = FutureProvider.autoDispose
    .family<List<BrandRow>, String>((ref, status) async {
  ref.watch(refreshTickProvider);
  final json = await _api.get(adminUrl('/brands?status=$status'));
  final list = [
    for (final b in (json['data'] as List? ?? const []))
      if (b is Map) BrandRow.fromJson(b.cast<String, dynamic>()),
  ];
  // Guard against backends that ignore the status filter.
  return list.where((b) => b.status == status).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0))
        .compareTo(a.createdAt ?? DateTime(0)));
});

/// Id of the brand currently in the Shop's Featured slot (null if none).
final featuredBrandIdProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  ref.watch(refreshTickProvider);
  // Prefer the analytics payload if the backend exposes it there.
  try {
    final a = await _api.get(adminUrl('/analytics'));
    final id = str((a['data'] as Map?)?['featuredBrandId']);
    if (id != null) return id;
  } catch (_) {}
  final json = await _api
      .get('${AppConfig.backendBaseUrl}/api/affiliate/featured');
  return str((json['data'] as Map?)?['brandId']);
});

/* ───────────────────────── Products ───────────────────────── */

class ProductRow {
  ProductRow({
    required this.id,
    required this.name,
    required this.brandId,
    required this.brandName,
    required this.price,
    this.currency,
    this.imageUrl,
    this.category,
    required this.clicks,
    required this.approved,
    required this.hidden,
  });
  final String id;
  final String name;
  final String? brandId;
  final String brandName;
  final num price;
  final String? currency;
  final String? imageUrl;
  final String? category;
  final int clicks;
  bool approved;
  bool hidden;

  factory ProductRow.fromJson(Map<String, dynamic> d) => ProductRow(
        id: str(d['id']) ?? '',
        name: str(d['name']) ?? 'Untitled',
        brandId: str(d['brandId']),
        brandName: str(d['brandName']) ?? '—',
        price: toNum(d['price']),
        currency: str(d['currency']),
        imageUrl: str(d['imageUrl']),
        category: str(d['category']),
        clicks: toInt(d['clicks']),
        approved: d['approved'] == true,
        hidden: d['hidden'] == true,
      );
}

final productsProvider =
    FutureProvider.autoDispose<List<ProductRow>>((ref) async {
  ref.watch(refreshTickProvider);
  final json = await _api.get(adminUrl('/products'));
  return [
    for (final p in (json['data'] as List? ?? const []))
      if (p is Map) ProductRow.fromJson(p.cast<String, dynamic>()),
  ];
});

/* ───────────────────────── Actions ───────────────────────── */

final adminWebRepoProvider = Provider((ref) => const AdminWebRepository());

/// Write actions. Reuses the in-app admin repository where it already exists.
class AdminWebRepository {
  const AdminWebRepository();
  static const _base = AdminRepository();

  /// action: 'ban' | 'suspend' | 'verify' | 'reinstate'
  Future<void> moderateUser(String uid, String action) =>
      _base.moderateUser(uid, action);

  Future<void> setAdmin(String uid, bool isAdmin) =>
      _api.post(adminUrl('/users/$uid/set-admin'), {'admin': isAdmin});

  /// decision: 'approve' | 'reject' | 'revoke'
  Future<void> decideBrand(String id, String decision) =>
      _api.post(adminUrl('/brands/$id/decision'), {'decision': decision});

  Future<void> setFeaturedBrand(String id) => _base.setFeaturedBrand(id);

  Future<void> setProductApproval(String id, bool approved) =>
      _base.setProductApproval(id, approved);

  Future<void> setProductHidden(String id, bool hidden) =>
      _base.setProductHidden(id, hidden);

  /// action: 'dismiss' | 'remove_content' | 'ban_user'
  Future<void> resolveReport(String id, String action) =>
      _base.resolveReport(id, action);

  Future<void> saveFitWeights(Map<String, num> w) => _base.saveFitWeights(w);
}
