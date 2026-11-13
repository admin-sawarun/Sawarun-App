import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_web_api.dart';
import '../widgets/common.dart';

/// Colour for a 0–100 fit score, matching the summary buckets.
Color scoreColor(num? s) {
  if (s == null) return AdminPalette.muted;
  if (s >= 80) return AdminPalette.success;
  if (s >= 60) return AdminPalette.info;
  if (s >= 40) return AdminPalette.warning;
  return AdminPalette.danger;
}

const _bucketColors = {
  '0-39': AdminPalette.danger,
  '40-59': AdminPalette.warning,
  '60-79': AdminPalette.info,
  '80-100': AdminPalette.success,
};

class AnalysesPage extends ConsumerStatefulWidget {
  const AnalysesPage({super.key});

  @override
  ConsumerState<AnalysesPage> createState() => _AnalysesPageState();
}

class _AnalysesPageState extends ConsumerState<AnalysesPage> {
  int _days = 30;

  List<AnalysisRow> _rows = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await fetchAnalyses();
      if (!mounted || id != _requestId) return;
      setState(() {
        _rows = page.items;
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await fetchAnalyses(cursor: _cursor);
      if (!mounted) return;
      final seen = _rows.map((r) => r.id).toSet();
      setState(() {
        _rows = [..._rows, ...page.items.where((r) => seen.add(r.id))];
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _load());
    final summary = ref.watch(analysesSummaryProvider(_days));
    final s = summary.value;
    final loadingSummary = summary.isLoading;

    return PageScroll(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Last $_days days',
                  style: const TextStyle(
                      fontSize: 13, color: AdminPalette.muted)),
            ),
            RangeSelector(
                days: _days, onChanged: (d) => setState(() => _days = d)),
          ],
        ),
        const SizedBox(height: 16),
        if (summary.hasError && !loadingSummary)
          PanelCard(
            child: ErrorState(
              error: summary.error!,
              onRetry: () => ref.invalidate(analysesSummaryProvider(_days)),
            ),
          )
        else ...[
          ResponsiveGrid(
            minItemWidth: 240,
            maxColumns: 3,
            children: [
              StatTile(
                label: 'Analyses',
                value: formatCount(s?.total),
                icon: Icons.auto_awesome_outlined,
                color: const Color(0xFFB7791F),
                loading: loadingSummary,
              ),
              StatTile(
                label: 'Average fit score',
                value: s?.averageScore == null
                    ? '—'
                    : s!.averageScore!.toStringAsFixed(1),
                icon: Icons.speed_rounded,
                color: scoreColor(s?.averageScore),
                loading: loadingSummary,
              ),
              StatTile(
                label: 'Scoring 80+',
                value: s == null || s.total == 0
                    ? '—'
                    : '${(s.buckets['80-100']! / s.total * 100).round()}%',
                icon: Icons.emoji_events_outlined,
                color: AdminPalette.success,
                loading: loadingSummary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final chart = PanelCard(
              title: 'Score distribution',
              subtitle: 'Fit scores grouped into buckets',
              child: SizedBox(
                height: 240,
                child: loadingSummary || s == null
                    ? const Skeleton(height: 240, radius: 12)
                    : s.total == 0
                        ? const Center(
                            child: EmptyState(
                                title: 'No analyses in this range',
                                icon: Icons.bar_chart_rounded))
                        : _BucketChart(summary: s),
              ),
            );
            final styles = PanelCard(
              title: 'Top styles',
              subtitle: 'Most common top style',
              child: loadingSummary || s == null
                  ? const TableSkeleton(rows: 4)
                  : s.topStyles.isEmpty
                      ? const EmptyState(
                          title: 'No style data yet',
                          icon: Icons.style_outlined)
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in s.topStyles)
                              Chip(
                                label: Text(
                                    '${capitalize(t.style)}  ·  ${formatCount(t.count)}'),
                                backgroundColor: AdminPalette.accentSoft,
                                side: BorderSide.none,
                                labelStyle: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AdminPalette.accent),
                              ),
                          ],
                        ),
            );
            if (c.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [chart, const SizedBox(height: 20), styles],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: chart),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: styles),
              ],
            );
          }),
        ],
        const SizedBox(height: 24),
        PanelCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: TableSkeleton(),
                )
              : _error != null
                  ? ErrorState(error: _error!, onRetry: _load)
                  : _rows.isEmpty
                      ? const EmptyState(
                          title: 'No analyses yet',
                          subtitle: 'Outfit analyses appear here as users '
                              'run them.',
                          icon: Icons.auto_awesome_outlined)
                      : _table(),
        ),
        if (!_loading && _error == null && _cursor != null)
          LoadMoreButton(loading: _loadingMore, onPressed: _loadMore),
      ],
    );
  }

  Widget _table() {
    return WideTable(
      child: DataTable(
        showCheckboxColumn: false,
        dataRowMinHeight: 64,
        dataRowMaxHeight: 68,
        columns: const [
          DataColumn(label: Text('OUTFIT')),
          DataColumn(label: Text('USER')),
          DataColumn(label: Text('FIT SCORE')),
          DataColumn(label: Text('TOP STYLE')),
          DataColumn(label: Text('DATE')),
        ],
        rows: [
          for (final a in _rows)
            DataRow(
              onSelectChanged: (_) => showDialog<void>(
                context: context,
                builder: (_) => _AnalysisDialog(analysis: a),
              ),
              cells: [
                DataCell(NetImage(a.imageUrl, width: 48, height: 48)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(url: a.userPhotoURL, name: a.userName, size: 30),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(a.userName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                )),
                DataCell(ScoreBadge(score: a.fitScore)),
                DataCell(Text(
                    a.topStyle == null ? '—' : capitalize(a.topStyle!))),
                DataCell(Tooltip(
                  message: formatDateTime(a.createdAt),
                  child: Text(formatDate(a.createdAt)),
                )),
              ],
            ),
        ],
      ),
    );
  }
}

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.score, this.large = false});
  final num? score;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = scoreColor(score);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 14 : 10, vertical: large ? 6 : 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        score == null ? '—' : '${score!.round()}',
        style: TextStyle(
            fontSize: large ? 22 : 13,
            fontWeight: FontWeight.w700,
            color: c),
      ),
    );
  }
}

class _BucketChart extends StatelessWidget {
  const _BucketChart({required this.summary});
  final AnalysesSummary summary;

  @override
  Widget build(BuildContext context) {
    const keys = AnalysesSummary.bucketKeys;
    final maxV = summary.buckets.values.fold<int>(0, math.max).toDouble();
    final interval = niceChartInterval(maxV);
    final top = math.max(interval * 4, (maxV / interval).ceil() * interval);
    return BarChart(
      BarChartData(
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AdminPalette.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
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
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(keys[i],
                      style: const TextStyle(
                          fontSize: 12, color: AdminPalette.inkSoft)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AdminPalette.ink,
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              'Score ${keys[group.x]}\n${formatCount(rod.toY)} analyses',
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (final (i, k) in keys.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: summary.buckets[k]!.toDouble(),
                  width: 44,
                  color: _bucketColors[k],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AnalysisDialog extends StatelessWidget {
  const _AnalysisDialog({required this.analysis});
  final AnalysisRow analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 860;

    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF0EEF5),
        child: a.imageUrl == null
            ? const SizedBox(
                height: 300,
                child: Center(
                    child: Icon(Icons.image_outlined,
                        color: AdminPalette.muted, size: 40)),
              )
            : Image.network(
                a.imageUrl!,
                fit: BoxFit.contain,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 300,
                  child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: AdminPalette.muted, size: 40)),
                ),
              ),
      ),
    );

    final maxPct = a.styleDna.isEmpty
        ? 1.0
        : a.styleDna.map((e) => e.percentage).reduce(math.max);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            UserAvatar(url: a.userPhotoURL, name: a.userName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.userName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(formatDateTime(a.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AdminPalette.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Fit score',
                style: TextStyle(fontSize: 13, color: AdminPalette.muted)),
            const SizedBox(width: 12),
            ScoreBadge(score: a.fitScore, large: true),
            if (a.topStyle != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: StatusChip('featured', label: capitalize(a.topStyle!)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        const Text('STYLE DNA',
            style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: AdminPalette.muted)),
        const SizedBox(height: 12),
        if (a.styleDna.isEmpty)
          const Text('No Style DNA recorded.',
              style: TextStyle(color: AdminPalette.muted))
        else
          for (final s in a.styleDna)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(capitalize(s.category),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AdminPalette.inkSoft)),
                  ),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: maxPct <= 0
                          ? 0.02
                          : (s.percentage / maxPct).clamp(0.02, 1.0),
                      child: Container(
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AdminPalette.accent,
                          borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text('${s.percentage.round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
      ],
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 940, maxHeight: size.height - 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Outfit analysis',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: photo),
                          const SizedBox(width: 24),
                          Expanded(child: details),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [photo, const SizedBox(height: 20), details],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
