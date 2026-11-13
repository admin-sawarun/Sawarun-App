import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Palette for the web admin dashboard. The accent matches the brand purple
/// used across the consumer app; surfaces are cooler/neutral for a desktop UI.
class AdminPalette {
  AdminPalette._();

  static const Color accent = Color(0xFF6D3FD3);
  static const Color accentSoft = Color(0xFFEEE8FB);
  static const Color background = Color(0xFFF7F7FA);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE7E5EE);
  static const Color ink = Color(0xFF16151C);
  static const Color inkSoft = Color(0xFF44434D);
  static const Color muted = Color(0xFF8A8996);
  static const Color success = Color(0xFF2E9E6A);
  static const Color warning = Color(0xFFD9922E);
  static const Color danger = Color(0xFFD9483B);
  static const Color info = Color(0xFF3B82F6);
}

/* ───────────────────────── Parsing helpers ───────────────────────── */

/// Accepts ISO strings, epoch seconds/millis, or Firestore `{_seconds}` maps.
DateTime? parseTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  if (v is num) {
    // Heuristic: values below 1e12 are seconds, otherwise millis.
    final ms = v < 1e12 ? (v * 1000).round() : v.round();
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  if (v is Map) {
    final s = v['_seconds'] ?? v['seconds'];
    if (s is num) return DateTime.fromMillisecondsSinceEpoch((s * 1000).round());
  }
  return null;
}

int? toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
  return null;
}

int toInt(dynamic v) => toIntOrNull(v) ?? 0;

num toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

String? str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime? d) =>
    d == null ? '—' : '${_months[d.month - 1]} ${d.day}, ${d.year}';

String formatShortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

String timeAgo(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return formatDate(t);
}

String formatCount(num? n) {
  if (n == null) return '—';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  final s = n.round().toString();
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

String capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/* ───────────────────────── Building blocks ───────────────────────── */

/// White card with a subtle border, the base surface of every page.
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminPalette.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: const TextStyle(
                                fontSize: 12.5, color: AdminPalette.muted)),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }
}

/// A pulsing grey placeholder block used for loading skeletons.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFECEAF2),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Skeleton rows mimicking a table while it loads.
class TableSkeleton extends StatelessWidget {
  const TableSkeleton({super.key, this.rows = 8});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Skeleton(width: 36, height: 36, radius: 18),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: Skeleton(height: 14)),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: Skeleton(height: 14)),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: Skeleton(height: 14)),
              ],
            ),
          ),
      ],
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    var msg = error.toString().replaceFirst('Exception: ', '');
    if (msg.contains('Failed to fetch') || msg.contains('XMLHttpRequest')) {
      msg = 'Could not reach the server. Check your connection (or CORS).';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFDECEA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: AdminPalette.danger),
          ),
          const SizedBox(height: 12),
          const Text('Something went wrong',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AdminPalette.muted)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
  });
  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AdminPalette.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AdminPalette.accent),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: AdminPalette.muted)),
          ],
        ],
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading / error states.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.loading,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      data: builder,
      loading: () => loading ?? const TableSkeleton(),
      error: (e, _) => ErrorState(error: e, onRetry: onRetry),
    );
  }
}

/// Coloured pill for statuses (active, banned, pending, ...).
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  static Color colorFor(String s) => switch (s.toLowerCase()) {
        'active' || 'approved' || 'resolved' || 'visible' => AdminPalette.success,
        'verified' || 'featured' => AdminPalette.accent,
        'pending' || 'open' || 'suspended' => AdminPalette.warning,
        'banned' || 'rejected' || 'revoked' || 'hidden' => AdminPalette.danger,
        'admin' => AdminPalette.info,
        _ => AdminPalette.muted,
      };

  @override
  Widget build(BuildContext context) {
    final c = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label ?? capitalize(status),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

/// Network image that falls back to an `<img>` element when the host has no
/// CORS headers, and to a placeholder when it fails to load.
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.fallbackIcon = Icons.image_outlined,
  });
  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: const Color(0xFFF0EEF5),
      alignment: Alignment.center,
      child: Icon(fallbackIcon, size: 18, color: AdminPalette.muted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (url == null || url!.isEmpty)
          ? placeholder
          : Image.network(
              url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Round avatar with the user's initials as fallback.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, required this.name, this.size = 36});
  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final fallback = Container(
      width: size,
      height: size,
      color: AdminPalette.accentSoft,
      alignment: Alignment.center,
      child: Text(initials.isEmpty ? '?' : initials,
          style: TextStyle(
              fontSize: size * 0.36,
              fontWeight: FontWeight.w600,
              color: AdminPalette.accent)),
    );
    return ClipOval(
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// Wide tables: horizontal scroll when narrower than the table, otherwise
/// stretch to the available width.
class WideTable extends StatelessWidget {
  const WideTable({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: child,
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                destructive ? AdminPalette.danger : AdminPalette.accent,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

void showToast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      width: 420,
      backgroundColor: error ? AdminPalette.danger : AdminPalette.ink,
    ));
}

String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Scrollable page body with responsive outer padding and a max width.
class PageScroll extends StatelessWidget {
  const PageScroll({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w < 700 ? 16.0 : 28.0;
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── Shared extras ───────────────────────── */

/// e.g. "Nov 13, 2026, 14:05".
String formatDateTime(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${formatDate(d)}, ${two(d.hour)}:${two(d.minute)}';
}

/// A "nice" axis step giving roughly four gridlines up to [max].
double niceChartInterval(double max) {
  if (max <= 4) return 1;
  final raw = max / 4;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final norm = raw / mag;
  final step = norm <= 1
      ? 1
      : norm <= 2
          ? 2
          : norm <= 5
              ? 5
              : 10;
  return step * mag;
}

/// 7d / 30d / 90d segmented control used by analytics pages.
class RangeSelector extends StatelessWidget {
  const RangeSelector({super.key, required this.days, required this.onChanged});
  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: 7, label: Text('7d')),
        ButtonSegment(value: 30, label: Text('30d')),
        ButtonSegment(value: 90, label: Text('90d')),
      ],
      selected: {days},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Centered "Load more" button for cursor-paginated lists.
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({super.key, required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.expand_more_rounded),
          label: const Text('Load more'),
        ),
      ),
    );
  }
}

/// Small KPI tile: coloured icon, label and a big value.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AdminPalette.accent,
    this.loading = false,
    this.caption,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool loading;
  final String? caption;

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
                    : Text(value,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.1)),
                if (caption != null && !loading) ...[
                  const SizedBox(height: 4),
                  Text(caption!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AdminPalette.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays [children] out in equal-width columns ([minItemWidth] each at least).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 260,
    this.maxColumns = 4,
    this.gap = 16,
  });
  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = ((c.maxWidth + gap) / (minItemWidth + gap))
          .floor()
          .clamp(1, maxColumns);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}
