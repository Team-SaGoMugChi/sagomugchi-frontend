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
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../../application/big5_controller.dart';
import '../../data/psych_providers.dart';
import '../../domain/ipip_big5.dart';

/// Screen 27 — 심리테스트 중간 저장·이어하기. (Follows the doc spec; the 27
/// mockup file duplicates the 성향 분석 screen.) → 이어서 하기 / 처음부터.
class PsychTestResumeScreen extends ConsumerWidget {
  const PsychTestResumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(big5ControllerProvider);
    final savedResult = ref.watch(psychResultProvider).value;
    final big5Done = savedResult?.isComplete ?? false;
    final answered = progress.answeredCount;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () {
                      if (context.canPop()) context.pop();
                    },
                  ),
                  const Expanded(
                    child: Text(
                      '이어서 진행하기',
                      textAlign: TextAlign.center,
                      style: AppTypography.subtitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // TODO: 책갈피를 들고 있는 포즈로 교체 예정
                        const Center(
                          child: MascotImage(pose: MascotPose.front, size: 140),
                        ),
                        Gap.h16,
                        const Text(
                          '이어서 진행할 수 있어요',
                          textAlign: TextAlign.center,
                          style: AppTypography.display,
                        ),
                        Gap.h8,
                        Text(
                          big5Done
                              ? 'Big Five 검사를 완료했어요.'
                              : answered == 0
                              ? '아직 저장된 답변이 없어요.'
                              : 'Big Five $answered문항의 답변을 기기에 저장했어요.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySecondary,
                        ),
                        Gap.h24,
                        OddoCard(
                          child: Column(
                            children: [
                              _ProgressRow(
                                title: 'IPIP Big Five',
                                status: big5Done
                                    ? '완료'
                                    : '$answered / ${ipipBig5Items.length}',
                                color: big5Done
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                  children: [
                    PrimaryButton(
                      label: '이어서 하기',
                      enabled: big5Done || answered > 0,
                      onPressed: () => context.pushNamed(
                        big5Done
                            ? AppRoute.psychTestDone
                            : AppRoute.psychTestBig5,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(big5ControllerProvider.notifier).reset();
                        if (context.mounted) {
                          context.pushReplacementNamed(AppRoute.psychTestBig5);
                        }
                      },
                      child: const Text('처음부터 다시 하기'),
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

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.title,
    required this.status,
    required this.color,
  });
  final String title;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.body)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            status,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
