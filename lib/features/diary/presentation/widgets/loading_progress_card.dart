import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/oddo_card.dart';

/// 로딩 진행 카드의 단계 상태.
enum LoadingStepState { pending, running, done, failed }

/// 38번(Step1 처리 중)·45번(리포트 생성) 로딩 화면의 진행 카드.
///
/// 체크는 실제로 끝난 단계에만 붙는다. 서버가 중간 진행률을 주지 않는 구간은
/// 화면이 기다린 시간으로 막대를 채우므로 % 숫자는 띄우지 않는다.
class LoadingProgressCard extends StatelessWidget {
  const LoadingProgressCard({
    super.key,
    required this.title,
    required this.progress,
    required this.steps,
  });

  final String title;

  /// 막대 값 0~1.
  final Animation<double> progress;

  /// (단계 이름, 상태). 위에서부터 순서대로 보여준다.
  final List<(String, LoadingStepState)> steps;

  @override
  Widget build(BuildContext context) {
    return OddoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.bodySecondary
                  .copyWith(fontWeight: FontWeight.w700)),
          Gap.h8,
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: AnimatedBuilder(
              animation: progress,
              builder: (_, _) => LinearProgressIndicator(
                value: progress.value,
                minHeight: 8,
                backgroundColor: AppColors.primarySoftBorder,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          Gap.h12,
          for (final (label, state) in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _StepIcon(state: state),
                  const SizedBox(width: 8),
                  Text(label,
                      style: state == LoadingStepState.pending
                          ? AppTypography.bodySecondary
                              .copyWith(color: AppColors.textTertiary)
                          : AppTypography.bodySecondary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.state});
  final LoadingStepState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      LoadingStepState.done => const Icon(Icons.check_circle_rounded,
          size: 16, color: AppColors.primary),
      LoadingStepState.running => const SizedBox(
          width: 16,
          height: 16,
          child: Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      LoadingStepState.pending => const Icon(
          Icons.radio_button_unchecked_rounded,
          size: 16,
          color: AppColors.textTertiary),
      // 실패는 다음 화면이 안내하므로 여기선 조용히 표시만 한다.
      LoadingStepState.failed => const Icon(Icons.error_outline_rounded,
          size: 16, color: AppColors.textSecondary),
    };
  }
}
