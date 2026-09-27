import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/primary_button.dart';

/// Screen 8 — Baseline 측정 필요 팝업. Centered card shown on first home entry
/// → permission rationale.
Future<void> showBaselineNeededDialog(
  BuildContext context, {
  bool hasPendingMeasurement = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            Gap.h16,
            Text(
              hasPendingMeasurement
                  ? '이전 측정 결과가\n아직 저장되지 않았어요.'
                  : '감정 분석을 위해\n첫 측정이 필요해요.',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle,
            ),
            Gap.h8,
            const Text(
              '얼굴과 음성 기준 데이터를 만들면\n오늘의 감정을 더 정확하게 이해할 수 있어요.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary,
            ),
            Gap.h24,
            PrimaryButton(
              label: hasPendingMeasurement ? '이전 측정 다시 저장하기' : '시작하기',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.pushNamed(
                  hasPendingMeasurement
                      ? AppRoute.baselineAnalyzing
                      : AppRoute.permission,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
