import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/help_sheet.dart';
import '../../../../widgets/step_progress_bar.dart';
import '../../../../widgets/step_title.dart';

/// Top bar for the baseline flow: leading (back/close) + centered title + help
/// icon, with the labeled step-progress bar below (labels가 비어 있으면 숨김).
/// Light + dark variants.
class BaselineHeader extends StatelessWidget {
  const BaselineHeader({
    super.key,
    required this.title,
    this.stepLabels = const [],
    this.activeStep = 0,
    this.showLeading = true,
    this.previousStep,
    this.nextStep,
    this.dark = false,
    this.leadingIcon = Icons.arrow_back_ios_new_rounded,
    this.onLeading,
  });

  final String title;
  final List<String> stepLabels;
  final int activeStep;
  final bool dark;
  final IconData leadingIcon;
  final VoidCallback? onLeading;

  /// false면 뒤로가기 자리를 비워 둔다(제목은 가운데 그대로).
  final bool showLeading;

  /// 제목 왼쪽(지난 단계)·오른쪽(다음 단계)에 작고 흐리게 보여 줄 단계 이름([StepTitle]).
  final String? previousStep;
  final String? nextStep;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.callTextPrimary : AppColors.textStrong;
    return Column(
      children: [
        Row(
          children: [
            if (showLeading)
              IconButton(
                icon: Icon(leadingIcon, size: 20, color: fg),
                onPressed:
                    onLeading ??
                    () {
                      if (context.canPop()) context.pop();
                    },
              )
            else
              const SizedBox(width: kMinInteractiveDimension),
            Expanded(
              child: StepTitle(
                title: title,
                previous: previousStep,
                next: nextStep,
                style: AppTypography.bodyLarge.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.help_outline_rounded, size: 20, color: fg),
              onPressed: () => showHelpSheet(
                context,
                title: '베이스라인 측정 도움말',
                items: const [
                  '평소 표정과 목소리를 기준값으로 저장하는 단계예요.',
                  '밝은 곳에서 얼굴이 화면 중앙에 오게 해주세요.',
                  '조용한 환경에서 평소처럼 편하게 말하면 돼요.',
                  '측정값은 감정 분석의 비교 기준으로만 사용돼요.',
                ],
              ),
            ),
          ],
        ),
        if (stepLabels.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: StepProgressBar(
              labels: stepLabels,
              currentIndex: activeStep,
              onDark: dark,
            ),
          ),
        ],
      ],
    );
  }
}
