import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The Home hero (CR-7): an interactive 3D-style orb. It gently floats and
/// sways on its own, tilts in 3D when dragged (with the light highlight
/// shifting like a real lit sphere), and runs the outfit analysis on tap.
///
/// Built entirely in Flutter — no 3D asset or network — so it's light, works
/// offline on web and mobile, and stays on-brand. A real .glb garment model
/// can be dropped in later via model_viewer if the client provides one.
class AnalyzeHero3D extends StatefulWidget {
  const AnalyzeHero3D({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<AnalyzeHero3D> createState() => _AnalyzeHero3DState();
}

class _AnalyzeHero3DState extends State<AnalyzeHero3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  // User-added tilt from dragging (radians), eased back toward the idle sway.
  double _dragX = 0;
  double _dragY = 0;
  bool _dragging = false;
  bool _pressed = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _dragging = true;
      _dragY = (_dragY + d.delta.dx * 0.012).clamp(-0.6, 0.6);
      _dragX = (_dragX - d.delta.dy * 0.012).clamp(-0.5, 0.5);
    });
  }

  void _onPanEnd() {
    setState(() => _dragging = false);
    // Ease the tilt back toward centre.
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted || _dragging) return false;
      setState(() {
        _dragX *= 0.9;
        _dragY *= 0.9;
      });
      return _dragX.abs() > 0.002 || _dragY.abs() > 0.002;
    });
  }

  @override
  Widget build(BuildContext context) {
    const size = 268.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onPanUpdate: _onPanUpdate,
      onPanEnd: (_) => _onPanEnd(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * math.pi;
          final idle = _dragging ? 0.0 : 1.0;
          final rotY = _dragY + math.sin(t) * 0.16 * idle;
          final rotX = _dragX + math.sin(t * 0.7) * 0.06 * idle;
          final floatY = math.sin(t) * 6 * idle;
          final scale = _pressed ? 0.95 : 1.0;

          return SizedBox(
            width: size,
            height: size + 26,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft drifting backdrop blobs for depth behind the orb.
                _backdropBlob(
                  color: AppColors.lilac,
                  d: size * 0.9,
                  offset: Offset(math.cos(t) * 14 - 16, math.sin(t) * 10),
                  opacity: 0.5,
                ),
                _backdropBlob(
                  color: AppColors.primaryLight,
                  d: size * 0.7,
                  offset: Offset(math.cos(t + math.pi) * 16 + 20,
                      math.sin(t + math.pi) * 8),
                  opacity: 0.4,
                ),
                // Ground shadow.
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: size * 0.5,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(colors: [
                        Colors.black.withValues(alpha: 0.22),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // The 3D orb.
                Transform.translate(
                  offset: Offset(0, floatY - 4),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0013)
                      ..rotateX(rotX)
                      ..rotateY(rotY)
                      ..scaleByDouble(scale, scale, 1, 1),
                    child: _orb(size * 0.72, rotX, rotY),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _orb(double d, double rotX, double rotY) {
    // The specular highlight shifts opposite to the tilt — the cue that sells
    // a lit, rounded, 3D surface.
    final hx = (-rotY * 70).clamp(-46.0, 46.0);
    final hy = (rotX * 70).clamp(-46.0, 46.0);

    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sphere body with top-left lighting.
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.35, -0.42),
                radius: 1.15,
                colors: [Color(0xFF574AA6), Color(0xFF261F49), Color(0xFF13112A)],
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDeep.withValues(alpha: 0.45),
                  blurRadius: 42,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
          ),
          // Darkening at the lower-right for roundness.
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(0.5, 0.55),
                radius: 0.9,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
          // Moving specular highlight.
          Transform.translate(
            offset: Offset(hx - d * 0.16, hy - d * 0.2),
            child: Container(
              width: d * 0.44,
              height: d * 0.44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),
          // Centre label.
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.center_focus_weak_rounded,
                  color: Colors.white, size: 30),
              SizedBox(height: 10),
              Text(
                'ANALYZE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              Text(
                'OUTFIT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _backdropBlob({
    required Color color,
    required double d,
    required Offset offset,
    required double opacity,
  }) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0.0),
          ]),
        ),
      ),
    );
  }
}
