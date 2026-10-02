import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/dummy/baseline_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/duration_chip.dart';
import '../../../../widgets/icon_info_tile.dart';
import '../../../../widgets/mascot_scene_card.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../widgets/security_card.dart';
import '../../../../widgets/tip_card.dart';
import '../../application/baseline_face_frames_provider.dart';
import '../../application/baseline_face_image_provider.dart';
import '../../application/baseline_recording_provider.dart';
import '../widgets/baseline_header.dart';

/// Screen 17 — 얼굴·음성 Baseline 안내. → 준비 체크.
class BaselineIntroScreen extends ConsumerWidget {
  const BaselineIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPendingMeasurement =
        ref.watch(baselineRecordingProvider) != null &&
        (ref.watch(baselineFaceImageProvider) != null ||
            ref.watch(baselineFaceFramesProvider).isNotEmpty);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: BaselineHeader(
                  title: '베이스라인 측정 1/2',
                  stepLabels: ['안내 진행', '측정 진행'],
                  activeStep: 0,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '얼굴과 음성 baseline을\n측정할게요',
                        style: AppTypography.display,
                      ),
                      Gap.h8,
                      const Text(
                        '정확한 감정 분석을 위해 현재 당신의\n표정과 음성 데이터를 수집해요.',
                        style: AppTypography.bodySecondary,
                      ),
                      Gap.h16,
                      // TODO: 클립보드를 든 안내 포즈로 교체 예정 (character_sheet 13.클립보드)
                      const MascotSceneCard(
                        pose: MascotPose.clipboard,
                        bubble: '몇 가지 상황에 대해\n자연스럽게 이야기해주세요!',
                      ),
                      Gap.h24,
                      const Text(
                        '측정 항목 및 시간 안내',
                        style: AppTypography.subtitle,
                      ),
                      Gap.h12,
                      OddoCard(
                        child: Column(
                          children: [
                            for (
                              var i = 0;
                              i < BaselineDummy.measureItems.length;
                              i++
                            ) ...[
                              if (i > 0)
                                const Divider(
                                  color: AppColors.divider,
                                  height: 1,
                                ),
                              IconInfoTile(
                                icon: BaselineDummy.measureItems[i].icon,
                                title: BaselineDummy.measureItems[i].title,
                                description:
                                    BaselineDummy.measureItems[i].description,
                                trailing: DurationChip(
                                  BaselineDummy.measureItems[i].duration,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Gap.h16,
                      const SecurityCard(
                        description: '모든 데이터는 안전하게 보호되며, 나만을 위한 분석에 사용돼요.',
                      ),
                      Gap.h12,
                      const TipCard(tips: BaselineDummy.introTips),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(
                      label: hasPendingMeasurement
                          ? '이전 측정 다시 저장하기'
                          : '측정 시작하기',
                      leadingIcon: hasPendingMeasurement
                          ? Icons.cloud_upload_rounded
                          : Icons.videocam_rounded,
                      onPressed: () => context.pushNamed(
                        hasPendingMeasurement
                            ? AppRoute.baselineAnalyzing
                            : AppRoute.baselineReady,
                      ),
                    ),
                    if (hasPendingMeasurement)
                      TextButton(
                        onPressed: () =>
                            context.pushNamed(AppRoute.baselineReady),
                        child: const Text('새로 측정하기'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
