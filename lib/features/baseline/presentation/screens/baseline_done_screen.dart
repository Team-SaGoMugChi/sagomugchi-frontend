import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../../application/baseline_profile_provider.dart';
import '../../application/baseline_upload_controller.dart';
import '../../data/models/baseline_profile.dart';
import '../widgets/metric_tile.dart';

/// Screen 21 — Show the saved reference, including when opened after a restart.
class BaselineDoneScreen extends ConsumerWidget {
  const BaselineDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(baselineProfileProvider);
    // Hide the previous account's value while loading another user's profile.
    final profile = result.isLoading ? null : result.asData?.value;
    final complete = profile?.isComplete ?? false;

    void remeasure() {
      ref.read(baselineUploadControllerProvider.notifier).startMeasurement();
      context.pushReplacementNamed(AppRoute.baselineReady);
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  child: result.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : result.hasError
                      ? const _Notice(
                          text: '저장된 측정 결과를 불러오지 못했어요.',
                          description: '연결을 확인한 뒤 다시 시도해주세요.',
                        )
                      : complete
                      ? _SavedProfile(profile: profile!)
                      : _Notice(
                          text: profile == null
                              ? '아직 저장된 측정 결과가 없어요'
                              : '기준값을 다시 측정해주세요',
                          description: '목소리와 얼굴 기준이 모두 있어야\n감정 변화를 비교할 수 있어요.',
                        ),
                ),
              ),
              if (!result.isLoading)
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: PrimaryButton(
                    label: result.hasError
                        ? '다시 불러오기'
                        : complete
                        ? '심리테스트 시작하기'
                        : '다시 측정하기',
                    onPressed: result.hasError
                        ? () => ref.invalidate(baselineProfileProvider)
                        : complete
                        ? () => context.pushNamed(AppRoute.psychTestList)
                        : remeasure,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedProfile extends StatelessWidget {
  const _SavedProfile({required this.profile});

  final BaselineProfile profile;

  @override
  Widget build(BuildContext context) {
    final pitch = profile.voice['pitchMean']!;
    final speechRate = profile.voice['speechRate'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: MascotImage(pose: MascotPose.check, size: 140)),
        Gap.h16,
        const Text(
          '첫 측정이 완료됐어요!',
          textAlign: TextAlign.center,
          style: AppTypography.display,
        ),
        Gap.h8,
        const Text(
          '평소 목소리와 얼굴 특징을\n감정 변화의 비교 기준으로 저장했어요.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
        Gap.h24,
        const Text('나의 감정 기준 요약', style: AppTypography.subtitle),
        Gap.h12,
        Row(
          children: [
            Expanded(
              child: MetricTile(
                icon: Icons.graphic_eq_rounded,
                label: '평균 음성 높이',
                value: '${pitch.toStringAsFixed(0)} Hz',
              ),
            ),
            Gap.w12,
            Expanded(
              child: MetricTile(
                icon: Icons.mic_none_rounded,
                label: '발화 속도 (추정)',
                value: speechRate == null
                    ? '확인 불가'
                    : '${speechRate.toStringAsFixed(1)} 음절/초',
              ),
            ),
          ],
        ),
        Gap.h12,
        Row(
          children: [
            const Expanded(
              child: MetricTile(
                icon: Icons.face_rounded,
                label: '얼굴 기준',
                value: '저장 완료',
              ),
            ),
            Gap.w12,
            Expanded(
              child: MetricTile(
                icon: Icons.schedule_rounded,
                label: '측정 시각',
                value: DateFormat(
                  'M/d HH:mm',
                ).format(profile.measuredAt.toLocal()),
              ),
            ),
          ],
        ),
        Gap.h16,
        OddoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in const ['얼굴 기준 데이터 저장 완료', '음성 기준 데이터 저장 완료'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: AppSpacing.lg,
                        color: AppColors.success,
                      ),
                      Gap.w8,
                      Expanded(child: Text(line, style: AppTypography.body)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Gap.h16,
        const Text(
          '발화 속도는 소리의 변화로 추정한 값이에요.\n이 기준값은 이후 측정과 비교할 때 사용해요.',
          style: AppTypography.bodySecondary,
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.description});

  final String text;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const MascotImage(pose: MascotPose.thinking, size: 140),
      Gap.h20,
      Text(text, textAlign: TextAlign.center, style: AppTypography.title),
      Gap.h12,
      Text(
        description,
        textAlign: TextAlign.center,
        style: AppTypography.bodySecondary,
      ),
    ],
  );
}
