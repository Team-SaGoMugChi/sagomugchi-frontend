import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/diary/application/pending_diary_provider.dart';
import '../../../../features/records/application/viewing_date_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/primary_button.dart';

Future<void> _showPendingNotice(
  BuildContext context,
  WidgetRef ref,
  DateTime pendingDate,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('마무리하지 않은 일기가 있어요', style: AppTypography.subtitle),
      content: Text(
        '${DateFormatter.monthDay(pendingDate)} 일기를 먼저 마무리해 주세요. '
        '영상을 보고 상담까지 마치면 새 일기를 쓸 수 있어요.',
        style: AppTypography.bodySecondary,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('닫기'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            ref.read(viewingDateProvider.notifier).set(pendingDate);
            context.goNamed(AppRoute.home);
          },
          child: const Text('그 일기로 가기'),
        ),
      ],
    ),
  );
}

/// Screen 35 — 일기 작성 시작 확인 모달. Centered card confirming writing for
/// [date] → Step 1 말하기 안내. On 시작하기, [date] becomes the focused diary
/// date so the whole write flow (and the final 기록 완료) targets it.
Future<void> showDiaryStartModal(
  BuildContext context,
  WidgetRef ref, {
  DateTime? date,
}) {
  final target = date ?? DateTime.now();
  final writeDate = DateTime(target.year, target.month, target.day);
  final now = DateTime.now();
  if (writeDate.isAfter(DateTime(now.year, now.month, now.day))) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('아직 오지 않은 날에는 일기를 쓸 수 없어요.')));
    return Future.value();
  }
  // 영상을 기다리는 일기는 한 편만 둔다 — 새로 쓰면 작성 중인 내용을 덮어쓴다.
  final pending = ref.read(pendingDiaryProvider);
  if (pending != null) {
    return _showPendingNotice(context, ref, pending.date);
  }
  final label = date != null ? DateFormatter.monthDay(date) : '오늘';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (dialogContext) => SafeArea(
      top: false,
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
            Text(
              '$label 이야기를 남겨 볼까요?',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle,
            ),
            Gap.h8,
            const Text(
              'AI와 대화하며\n오늘의 감정을 기록해볼게요.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary,
            ),
            Gap.h24,
            PrimaryButton(
              label: '시작하기',
              onPressed: () {
                ref.read(viewingDateProvider.notifier).set(writeDate);
                Navigator.of(dialogContext).pop();
                context.pushNamed(AppRoute.diaryStep1Intro);
              },
            ),
            Gap.h8,
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    ),
  );
}
