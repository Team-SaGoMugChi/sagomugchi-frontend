import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/primary_button.dart';
import '../../../records/presentation/widgets/shortform_thumbnail.dart';
import '../../application/diary_draft_provider.dart';
import '../../application/video_job_controller.dart';
import '../../data/models/video_rating.dart';
import '../widgets/diary_step_header.dart';

/// Screen 42 — Step 3. 영상 제작 완료·영상 확인. 미리보기를 누르면 방금 만든
/// 영상을 전체화면 플레이어로 재생한다. 영상 평가는 기록 완료 때 일기와 함께
/// 저장된다.
class DiaryStep3VideoDoneScreen extends ConsumerWidget {
  const DiaryStep3VideoDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoUrl = ref.watch(videoJobControllerProvider).videoUrl;
    final rating = ref.watch(diaryDraftProvider.select((d) => d.videoRating));

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const DiaryStepHeader(currentStep: 2),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.sm,
                    AppSpacing.screenH,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _CompleteBanner(),
                      Gap.h16,
                      ShortformThumbnail(
                        videoUrl: videoUrl,
                        onTap: () => context.pushNamed(
                          AppRoute.shortformPlayer,
                          extra: videoUrl,
                        ),
                      ),
                      // TODO: 영상 요약 카드 — 서버가 영상 내용 요약을 주면 다시 넣는다
                      // (지금은 샘플 문장뿐이라 숨김, sagomugchi-backend#65).
                      Gap.h24,
                      const Text('이 영상은 어땠나요?', style: AppTypography.subtitle),
                      Gap.h12,
                      Row(
                        children: [
                          for (final option in VideoRating.values) ...[
                            if (option != VideoRating.values.first) Gap.w12,
                            Expanded(
                              child: _RatingChip(
                                emoji: option.emoji,
                                label: option.label,
                                selected: rating == option,
                                onTap: () => ref
                                    .read(diaryDraftProvider.notifier)
                                    .setVideoRating(option),
                              ),
                            ),
                          ],
                        ],
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
                child: SafeArea(
                  top: false,
                  child: PrimaryButton(
                    label: '다음 단계로',
                    onPressed: () =>
                        context.pushNamed(AppRoute.diaryStep4CounselIntro),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompleteBanner extends StatelessWidget {
  const _CompleteBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 22,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '영상이 완성되었어요!',
                  style: AppTypography.bodySecondary.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'AI가 제작한 영상을 확인해 보세요.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          // TODO: 기뻐하는 작은 포즈로 교체 예정
          const MascotImage(pose: MascotPose.celebrate, size: 44),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: AppRadius.button,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
