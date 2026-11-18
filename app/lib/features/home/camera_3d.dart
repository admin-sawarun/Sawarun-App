import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../core/theme/app_colors.dart';

/// The Home hero (CR-7): a REAL, rotatable 3D camera model (model_viewer).
/// The user can drag to spin it; it also auto-rotates. A tappable CTA below
/// opens the camera to analyse an outfit.
///
/// The model is a BUNDLED compact camera built in-house (assets/camera.glb,
/// ~42 KB, no brand logos) so it loads instantly and offline. model_viewer
/// renders it via a native WebView on Android/iOS; it does NOT render in the
/// newest Flutter *web* build, so test on a real device, not the Chrome preview.
class Camera3DHero extends StatelessWidget {
  const Camera3DHero({super.key, required this.onTap});
  final VoidCallback onTap;

  static const _modelSrc = 'assets/camera.glb';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          height: 300,
          // Draggable: the user can spin the camera with their finger; it also
          // auto-rotates. (No tap overlay, so gestures reach the model.)
          child: ModelViewer(
            src: _modelSrc,
            alt: 'A 3D camera',
            autoRotate: true,
            cameraControls: true,
            disableZoom: true,
            cameraOrbit: '0deg 80deg 105%',
            backgroundColor: Color(0x00000000),
          ),
        ),
        const SizedBox(height: 8),
        // Separate button to open the camera and analyze an outfit.
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.center_focus_weak_rounded,
                    size: 18, color: AppColors.white),
                SizedBox(width: 8),
                Text(
                  'Analyze your outfit',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
