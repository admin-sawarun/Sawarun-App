import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_web_api.dart';
import '../widgets/common.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    return PageScroll(
      children: [
        stats.when(
          skipLoadingOnRefresh: false,
          data: (s) => _KpiGrid(stats: s),
          loading: () => const _KpiGrid(stats: null),
          error: (e, _) => PanelCard(
            child: ErrorState(
                error: e,
                onRetry: () => ref.invalidate(dashboardStatsProvider)),
          ),
        ),
        const SizedBox(height: 24),
        const _ActivityChart(),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final trending = _TrendingStyles(stats: stats);
          final top = _TopProducts(stats: stats);
          if (c.maxWidth < 900) {
            return Column(children: [trending, const SizedBox(height: 24), top]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: trending),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: top),
            ],
          );
        }),
      ],
    );
  }
}

/* ───────────────────────── KPI cards ───────────────────────── */

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final items = [
      ('Total users', s?.totalUsers, Icons.people_alt_outlined, AdminPalette.accent),
      ('Active today', s?.activeToday, Icons.bolt_rounded, const Color(0xFF2A9D8F)),
      ('New this week', s?.newUsersThisWeek, Icons.person_add_alt_outlined, AdminPalette.info),
      ('Total analyses', s?.totalAnalyses, Icons.auto_awesome_outlined, const Color(0xFFB7791F)),
      ('Total posts', s?.totalPosts, Icons.photo_library_outlined, const Color(0xFFD14D7E)),
      ('Open reports', s?.openReports, Icons.flag_outlined, AdminPalette.danger),
      ('Pending brands', s?.pendingBrands, Icons.storefront_outlined, AdminPalette.warning),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1200
          ? 4
          : c.maxWidth >= 760
              ? 3
              : c.maxWidth >= 480
                  ? 2
                  : 1;
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (label, value, icon, color) in items)
            SizedBox(
              width: w,
              child: _KpiCard(
                label: label,
                value: value,
                icon: icon,
                color: color,
                loading: s == null,
              ),
            ),
        ],
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.loading,
  });
  final String label;
  final int? value;
  final IconData icon;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AdminPalette.muted)),
                const SizedBox(height: 6),
                loading
                    ? const Skeleton(width: 70, height: 24)
                    : Tooltip(
                        message: value == null
                            ? 'Not reported by the backend yet'
                            : '$value',
                        child: Text(formatCount(value),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                height: 1.1)),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── Activity chart ───────────────────────── */

class _Series {
  const _Series(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;
}

// Fixed order + colours (validated for colour-blind separation).
const _series = [
  _Series('signups', 'Signups', Color(0xFF6D3FD3)),
  _Series('activeUsers', 'Active users', Color(0xFF2A9D8F)),
  _Series('analyses', 'Analyses', Color(0xFFE0A44A)),
  _Series('posts', 'Posts', Color(0xFFE05B8C)),
  _Series('clicks', 'Clicks', Color(0xFF3B82F6)),
];

class _ActivityChart extends ConsumerStatefulWidget {
  const _ActivityChart();

  @override
  ConsumerState<_ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends ConsumerState<_ActivityChart> {
  int _days = 30;
  final Set<String> _on = {'signups', 'activeUsers'};

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(timeSeriesProvider(_days));
    return PanelCard(
      title: 'Activity',
      subtitle: 'Daily totals for the last $_days days',
      trailing: SegmentedButton<int>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(value: 7, label: Text('7d')),
          ButtonSegment(value: 30, label: Text('30d')),
          ButtonSegment(value: 90, label: Text('90d')),
        ],
        selected: {_days},
        onSelectionChanged: (s) => setState(() => _days = s.first),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _series)
                FilterChip(
                  label: Text(s.label),
                  selected: _on.contains(s.key),
                  showCheckmark: false,
                  avatar: Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  selectedColor: s.color.withValues(alpha: 0.12),
                  onSelected: (v) => setState(() {
                    v ? _on.add(s.key) : _on.remove(s.key);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 320,
            child: data.when(
              skipLoadingOnRefresh: false,
              loading: () => const Skeleton(height: 320, radius: 12),
              error: (e, _) => Center(
                child: ErrorState(
                    error: e,
                    onRetry: () => ref.invalidate(timeSeriesProvider(_days))),
              ),
              data: (ts) {
                final active = _series.where((s) => _on.contains(s.key));
                if (ts.days.isEmpty) {
                  return const Center(
                      child: EmptyState(
                          title: 'No activity yet',
                          icon: Icons.show_chart_rounded));
                }
                if (active.isEmpty) {
                  return const Center(
                      child: EmptyState(
                          title: 'Pick a metric above',
                          icon: Icons.show_chart_rounded));
                }
                return _LineChart(ts: ts, series: active.toList());
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.ts, required this.series});
  final TimeSeries ts;
  final List<_Series> series;

  @override
  Widget build(BuildContext context) {
    final n = ts.days.length;
    var maxY = 0.0;
    for (final s in series) {
      for (final v in ts.series[s.key]!) {
        maxY = math.max(maxY, v);
      }
    }
    final yInterval = _niceInterval(maxY);
    final top = math.max(yInterval * 4, (maxY / yInterval).ceil() * yInterval);
    final labelEvery = math.max(1, (n / 7).ceil());

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble().clamp(1, double.infinity),
        minY: 0,
        maxY: top,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AdminPalette.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(formatCount(v),
                    style: const TextStyle(
                        fontSize: 11, color: AdminPalette.muted)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i != v || i < 0 || i >= n || i % labelEvery != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(formatShortDate(ts.days[i]),
                      style: const TextStyle(
                          fontSize: 11, color: AdminPalette.muted)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (bar, idx) => [
            for (final _ in idx)
              TouchedSpotIndicatorData(
                const FlLine(color: AdminPalette.border, strokeWidth: 1),
                FlDotData(
                  getDotPainter: (_, _, b, _) => FlDotCirclePainter(
                    radius: 4,
                    color: b.color ?? AdminPalette.accent,
                    strokeColor: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AdminPalette.ink,
            tooltipBorderRadius: BorderRadius.circular(8),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final (k, s) in spots.indexed)
                LineTooltipItem(
                  '${k == 0 ? '${formatShortDate(ts.days[s.x.round()])}\n' : ''}'
                  '${series[s.barIndex].label}: ${formatCount(s.y)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              spots: [
                for (var i = 0; i < n; i++)
                  FlSpot(i.toDouble(), ts.series[s.key]![i]),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: s.color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: series.length <= 2,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    s.color.withValues(alpha: 0.16),
                    s.color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static double _niceInterval(double max) {
    if (max <= 4) return 1;
    final raw = max / 4;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final step = norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10;
    return step * mag;
  }
}

/* ───────────────────────── Trending + top products ───────────────────────── */

class _TrendingStyles extends ConsumerWidget {
  const _TrendingStyles({required this.stats});
  final AsyncValue<DashboardStats> stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelCard(
      title: 'Trending styles this week',
      subtitle: 'Share of Style DNA across recent outfit analyses',
      child: stats.when(
        skipLoadingOnRefresh: false,
        loading: () => const TableSkeleton(rows: 5),
        error: (e, _) => ErrorState(
            error: e, onRetry: () => ref.invalidate(dashboardStatsProvider)),
        data: (s) {
          final items = s.trendingStyles;
          if (items.isEmpty) {
            return const EmptyState(
                title: 'No style data yet',
                subtitle: 'Appears once users analyse outfits.',
                icon: Icons.style_outlined);
          }
          final total = items.fold<double>(0, (a, b) => a + b.weight);
          final max = items.map((e) => e.weight).reduce(math.max);
          return Column(
            children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(capitalize(it.category),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AdminPalette.inkSoft)),
                      ),
                      Expanded(
                        child: Tooltip(
                          message:
                              '${capitalize(it.category)}: ${(it.weight / (total == 0 ? 1 : total) * 100).toStringAsFixed(1)}%',
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: max == 0
                                ? 0.02
                                : (it.weight / max).clamp(0.02, 1.0),
                            child: Container(
                              height: 14,
                              decoration: const BoxDecoration(
                                color: AdminPalette.accent,
                                borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 52,
                        child: Text(
                          '${(it.weight / (total == 0 ? 1 : total) * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopProducts extends ConsumerWidget {
  const _TopProducts({required this.stats});
  final AsyncValue<DashboardStats> stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelCard(
      title: 'Top clicked products',
      subtitle: 'All-time affiliate clicks',
      child: stats.when(
        skipLoadingOnRefresh: false,
        loading: () => const TableSkeleton(rows: 5),
        error: (e, _) => ErrorState(
            error: e, onRetry: () => ref.invalidate(dashboardStatsProvider)),
        data: (s) {
          if (s.topProducts.isEmpty) {
            return const EmptyState(
                title: 'No clicks yet', icon: Icons.ads_click_rounded);
          }
          return Column(
            children: [
              for (final (i, p) in s.topProducts.indexed) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AdminPalette.muted)),
                      ),
                      if (p.imageUrl != null) ...[
                        NetImage(p.imageUrl, width: 36, height: 36),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(p.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5)),
                      ),
                      Text('${formatCount(p.clicks)} clicks',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
