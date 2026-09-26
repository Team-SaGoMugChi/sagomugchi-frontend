import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// 상담을 영상통화로 할지 채팅으로 할지 고르는 시트.
///
/// 두 화면은 같은 `counselControllerProvider`를 쓰기 때문에 중간에 방식을
/// 바꿔도 대화가 이어진다 — 말로 시작했다가 사람이 많은 곳으로 옮기면
/// 채팅으로 이어서 할 수 있다.
Future<void> showCounselModeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('어떻게 이야기할까요?', style: AppTypography.subtitle),
            Gap.h8,
            Text(
              '지금 편한 쪽으로 고르면 돼요. 중간에 바꿔도 대화는 이어져요.',
              style: AppTypography.bodySecondary,
            ),
            Gap.h20,
            _ModeTile(
              icon: Icons.videocam_rounded,
              title: '영상통화로 이야기하기',
              description: '목소리로 편하게 말하고 들어요.',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.pushNamed(AppRoute.diaryStep4CounselCall);
              },
            ),
            Gap.h12,
            _ModeTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: '채팅으로 이야기하기',
              description: '조용한 곳이 아니어도 괜찮아요. 글로 주고받아요.',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.pushNamed(AppRoute.diaryStep4CounselChat);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(description, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
