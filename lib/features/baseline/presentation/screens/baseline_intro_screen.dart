import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../../application/baseline_face_frames_provider.dart';
import '../../application/baseline_face_image_provider.dart';
import '../../application/baseline_recording_provider.dart';
import '../widgets/baseline_companion.dart';
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
                  title: '나의 기준 만들기',
                  stepLabels: ['안내', '준비', '측정'],
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
                        '오또와 함께,\n평소의 나를 알려주세요',
                        style: AppTypography.display,
                      ),
                      Gap.h8,
                      const Text(
                        '문장 6개를 평소 목소리로 읽어주세요.',
                        style: AppTypography.bodyLarge,
                      ),
                      const SizedBox(
                        height: 180,
                        child: BaselineCompanion(welcome: true),
                      ),
                      const Text(
                        '천천히 읽어도 괜찮아요.',
                        textAlign: TextAlign.center,
                        style: AppTypography.subtitle,
                      ),
                      Gap.h20,
                      OddoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.xs,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: AppSpacing.lg,
                                      color: AppColors.primary,
                                    ),
                                    Gap.w8,
                                    Text(
                                      '약 1~2분',
                                      style: AppTypography.subtitle.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  '문장 6개',
                                  style: AppTypography.bodySecondary,
                                ),
                              ],
                            ),
                            Gap.h16,
                            const Text('무엇을 기록하나요?', style: AppTypography.body),
                            Gap.h4,
                            const Text(
                              '읽는 동안의 목소리와 얼굴 표정을 함께 기록해요.',
                              style: AppTypography.bodySecondary,
                            ),
                            const Divider(
                              height: AppSpacing.xl,
                              color: AppColors.divider,
                            ),
                            const Text('왜 필요한가요?', style: AppTypography.body),
                            Gap.h4,
                            const Text(
                              '앞으로의 감정 변화를 평소의 나와 비교하기 위해서예요.',
                              style: AppTypography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
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
                          : '오또와 준비하기',
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
