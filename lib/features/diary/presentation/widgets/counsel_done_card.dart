import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/primary_button.dart';

/// CBT 5단계(행동 가이드)까지 끝났을 때 — 상담을 마무리하고 리포트로 넘어가게 한다.
/// 통화형·채팅형 상담 화면이 같이 쓴다.
class CounselDoneCard extends StatelessWidget {
  const CounselDoneCard({
    super.key,
    required this.onFinish,
    this.mission,
    this.margin = EdgeInsets.zero,
  });

  /// 리포트 생성으로 넘어간다(각 화면의 상담 종료와 같은 동작).
  final VoidCallback onFinish;

  /// 이번 상담에서 정한 미션. 다음 상담에서 해 봤는지 묻는다.
  final String? mission;

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primarySoftBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('오늘 상담을 마무리했어요', style: AppTypography.subtitle),
          if (mission != null) ...[
            const SizedBox(height: 6),
            Text('내일의 미션 · $mission', style: AppTypography.bodySecondary),
          ],
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(label: '감정 리포트 보기', onPressed: onFinish),
        ],
      ),
    );
  }
}