import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Interactive preview of the team's rigged 3D Oddo model.
/// The model has a skeleton but no authored animation clips yet, so regular
/// conversation screens continue to use the lightweight speaking mascot.
class Mascot3dPreview extends StatelessWidget {
  const Mascot3dPreview({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.authBackground,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => const SafeArea(
      top: false,
      child: SizedBox(height: 460, child: Mascot3dPreview()),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        child: Row(
          children: [
            const Expanded(child: Text('오또를 3D로 보기', style: AppTypography.subtitle)),
            IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
      const Expanded(
        child: ModelViewer(
          src: 'assets/models/oddo_rigged.glb',
          backgroundColor: AppColors.authBackground,
          cameraControls: true,
          autoRotate: true,
          disableZoom: true,
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Text('손가락으로 돌려서 살펴보세요.', style: AppTypography.bodySecondary),
      ),
    ],
  );
}
