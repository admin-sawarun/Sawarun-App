import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/outfit_analysis.dart';

/// A radar / "spider web" chart of the five Fit Score factors (CR-2 graphics).
/// Turns the analysis breakdown into one glanceable visual instead of plain
/// text, so the result screen reads as a real report, not a monotonous list.
class FactorRadarChart extends StatelessWidget {
  const FactorRadarChart({super.key, required this.factors});

  final List<ScoreFactor> factors;

  @override
  Widget build(BuildContext context) {
    final shown = factors.take(6).toList();
    // A radar needs at least a triangle to make sense.
    if (shown.length < 3) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(painter: _RadarPainter(shown)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.factors);
  final List<ScoreFactor> factors;

  static const _startAngle = -math.pi / 2; // first vertex at the top
  static const _rings = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final n = factors.length;
    final center = Offset(size.width / 2, size.height / 2);
    // Leave a margin for the labels painted outside the outer ring.
    final radius = math.min(size.width, size.height) / 2 - 40;
    if (radius <= 0) return;
    final step = 2 * math.pi / n;

    Offset vertex(int i, double r) {
      final a = _startAngle + i * step;
      return Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.line
      ..strokeWidth = 1;

    // Concentric polygon rings.
    for (var ring = 1; ring <= _rings; ring++) {
      final r = radius * ring / _rings;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = vertex(i, r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, grid);
    }

    // Spokes from the centre to each vertex.
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, vertex(i, radius), grid);
    }

    // The data polygon.
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final v = factors[i].score.clamp(0, 100) / 100;
      final p = vertex(i, radius * v);
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.primary.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.primary
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Vertices.
    final dot = Paint()..color = AppColors.primary;
    for (var i = 0; i < n; i++) {
      final v = factors[i].score.clamp(0, 100) / 100;
      canvas.drawCircle(vertex(i, radius * v), 3, dot);
    }

    // Labels (short factor name + score) just outside the outer ring.
    for (var i = 0; i < n; i++) {
      final p = vertex(i, radius + 20);
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
            text: '${_short(factors[i].name)}\n',
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.2,
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: '${factors[i].score}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 76);
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }
  }

  /// Compact labels so they fit around the chart.
  String _short(String name) {
    switch (name) {
      case 'Trend Match':
        return 'Trend';
      case 'Color Harmony':
        return 'Colour';
      case 'Style Consistency':
        return 'Style';
      case 'Silhouette Balance':
        return 'Fit';
      case 'Accessories':
        return 'Extras';
      default:
        return name.length > 8 ? name.substring(0, 8) : name;
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.factors != factors;
}
