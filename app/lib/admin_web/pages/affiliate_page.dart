import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_web_api.dart';
import '../widgets/common.dart';

const _clickColor = Color(0xFF3B82F6);

class AffiliatePage extends ConsumerStatefulWidget {
  const AffiliatePage({super.key});

  @override
  ConsumerState<AffiliatePage> createState() => _AffiliatePageState();
}

class _AffiliatePageState extends ConsumerState<AffiliatePage> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final perf = ref.watch(affiliatePerformanceProvider(_days));
    final p = perf.value;
    final loading = perf.isLoading;
    void retry() => ref.invalidate(affiliatePerformanceProvider(_days));

    final avg = p == null
        ? null
        : p.totalClicks / math.max(1, p.days.isEmpty ? _days : p.days.length);
    final peak = p == null || p.clicks.isEmpty
        ? null
        : p.clicks.reduce(math.max);

    return PageScroll(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Affiliate clicks over the last $_days days',
                  style: const TextStyle(
                      fontSize: 13, color: AdminPalette.muted)),
            ),
            RangeSelector(
                days: _days, onChanged: (d) => setState(() => _days = d)),
          ],
        ),
        const SizedBox(height: 16),
        if (perf.hasError && !loading)
          PanelCard(child: ErrorState(error: perf.error!, onRetry: retry))
        else ...[
          ResponsiveGrid(
            minItemWidth: 240,
            maxColumns: 3,
            children: [
              StatTile(
                label: 'Total clicks',
                value: formatCount(p?.totalClicks),
                icon: Icons.ads_click_rounded,
                color: _clickColor,
                loading: loading,
              ),
              StatTile(
                label: 'Average per day',
                value: avg == null
                    ? '—'
                    : avg < 10
                        ? avg.toStringAsFixed(1)
                        : formatCount(avg),
                icon: Icons.calendar_today_outlined,
                color: AdminPalette.accent,
                loading: loading,
              ),
              StatTile(
                label: 'Best day',
                value: formatCount(peak),
                icon: Icons.trending_up_rounded,
                color: AdminPalette.success,
                loading: loading,
                caption: p == null || peak == null || peak == 0
                    ? null
                    : formatDate(p.days[p.clicks.indexOf(peak)]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PanelCard(
            title: 'Clicks per day',
            subtitle: 'Outbound affiliate link clicks',
            child: SizedBox(
              height: 300,
              child: loading || p == null
                  ? const Skeleton(height: 300, radius: 12)
                  : p.days.isEmpty
                      ? const Center(
                          child: EmptyState(
                              title: 'No click data yet',
                              icon: Icons.show_chart_rounded))
                      : _ClicksChart(perf: p),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final products = _TopProductsCard(perf: p, loading: loading);
            final brands = _TopBrandsCard(perf: p, loading: loading);
            if (c.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [products, const SizedBox(height: 20), brands],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: products),
                const SizedBox(width: 20),
                Expanded(child: brands),
              ],
            );
          }),
        ],
      ],
    );
  }
}

class _ClicksChart extends StatelessWidget {
  const _ClicksChart({required this.perf});
  final AffiliatePerformance perf;

  @override
  Widget build(BuildContext context) {
    final n = perf.days.length;
    final maxY = perf.clicks.fold<double>(0, math.max);
    final interval = niceChartInterval(maxY);
    final top = math.max(interval * 4, (maxY / interval).ceil() * interval);
    final labelEvery = math.max(1, (n / 7).ceil());

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble().clamp(1, double.infinity),
        minY: 0,
        maxY: top,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
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
              interval: interval,
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
                  child: Text(formatShortDate(perf.days[i]),
                      style: const TextStyle(
                          fontSize: 11, color: AdminPalette.muted)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AdminPalette.ink,
            tooltipBorderRadius: BorderRadius.circular(8),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${formatShortDate(perf.days[s.x.round()])}\n'
                  '${formatCount(s.y)} clicks',
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < n; i++) FlSpot(i.toDouble(), perf.clicks[i]),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: _clickColor,
            barWidth: 2,
            dotData: FlDotData(show: n <= 7),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _clickColor.withValues(alpha: 0.16),
                  _clickColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.perf, required this.loading});
  final AffiliatePerformance? perf;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = perf;
    return PanelCard(
      title: 'Top products',
      subtitle: 'Most clicked in this range',
      child: loading || p == null
          ? const TableSkeleton(rows: 5)
          : p.topProducts.isEmpty
              ? const EmptyState(
                  title: 'No product clicks yet',
                  icon: Icons.shopping_bag_outlined)
              : Column(
                  children: [
                    for (final (i, t) in p.topProducts.indexed) ...[
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
                            NetImage(t.imageUrl,
                                width: 40,
                                height: 40,
                                fallbackIcon: Icons.shopping_bag_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500)),
                                  if (t.brandName != null)
                                    Text(t.brandName!,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AdminPalette.muted)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${formatCount(t.clicks)} clicks',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _TopBrandsCard extends StatelessWidget {
  const _TopBrandsCard({required this.perf, required this.loading});
  final AffiliatePerformance? perf;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = perf;
    return PanelCard(
      title: 'Top brands',
      subtitle: 'Clicks across each brand\'s products',
      child: loading || p == null
          ? const TableSkeleton(rows: 5)
          : p.topBrands.isEmpty
              ? const EmptyState(
                  title: 'No brand clicks yet',
                  icon: Icons.storefront_outlined)
              : Builder(builder: (context) {
                  final max = p.topBrands.map((b) => b.clicks).reduce(math.max);
                  return Column(
                    children: [
                      for (final (i, b) in p.topBrands.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 26,
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AdminPalette.muted)),
                              ),
                              SizedBox(
                                width: 140,
                                child: Text(b.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AdminPalette.inkSoft)),
                              ),
                              Expanded(
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: max == 0
                                      ? 0.02
                                      : (b.clicks / max).clamp(0.02, 1.0),
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
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 56,
                                child: Text(formatCount(b.clicks),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }),
    );
  }
}
