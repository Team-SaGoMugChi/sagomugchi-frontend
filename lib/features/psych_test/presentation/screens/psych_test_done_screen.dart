import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/dummy/psych_test_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/card_section_header.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../widgets/step_progress_bar.dart';
import '../../data/psych_providers.dart';

/// Screen 28 — 심리테스트 완료 → 챗봇 페르소나 설정.
class PsychTestDoneScreen extends ConsumerWidget {
  const PsychTestDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(psychResultProvider);
    final hasResult = result.value?.isComplete ?? false;
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
                      '심리테스트 완료',
                      textAlign: TextAlign.center,
                      style: AppTypography.subtitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: StepProgressBar(
                  labels: PsychTestDummy.journeySteps,
                  currentIndex: 2,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.lg,
                    AppSpacing.screenH,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: 'Big Five 검사가\n'),
                                      TextSpan(
                                        text: '완료',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      TextSpan(text: '되었어요!'),
                                    ],
                                  ),
                                  style: AppTypography.display,
                                ),
                                Gap.h8,
                                Text(
                                  '정성껏 답변해주셔서 감사합니다.\n응답 범위 안에서 계산한 결과예요.',
                                  style: AppTypography.bodySecondary,
                                ),
                              ],
                            ),
                          ),
                          // TODO: 반짝이는 체크 표시를 들고 있는 포즈로 교체 예정
                          MascotImage(pose: MascotPose.check, size: 84),
                        ],
                      ),
                      Gap.h20,
                      OddoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CardSectionHeader(
                              icon: Icons.task_alt_rounded,
                              title: '완료된 테스트',
                            ),
                            Gap.h8,
                            for (
                              var i = 0;
                              i < PsychTestDummy.testList.length;
                              i++
                            ) ...[
                              if (i > 0)
                                const Divider(
                                  color: AppColors.divider,
                                  height: 1,
                                ),
                              _CompletedRow(info: PsychTestDummy.testList[i]),
                            ],
                          ],
                        ),
                      ),
                      Gap.h16,
                      OddoCard(
                        child: result.when(
                          data: (value) => value?.isComplete != true
                              ? const Text(
                                  '검증 가능한 Big Five 결과를 찾지 못했어요.',
                                  style: AppTypography.bodySecondary,
                                )
                              : _Big5Results(scores: value!.big5!),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => Column(
                            children: [
                              const Text(
                                '결과를 불러오지 못했어요.',
                                style: AppTypography.bodySecondary,
                              ),
                              TextButton(
                                onPressed: () =>
                                    ref.invalidate(psychResultProvider),
                                child: const Text('다시 불러오기'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Gap.h12,
                      const Text(
                        '이 점수는 응답 가능한 범위(10~50)를 0~100으로 바꾼 값이며, '
                        '다른 사람과 비교한 백분위나 의학적 진단이 아니에요.',
                        style: AppTypography.caption,
                      ),
                      Gap.h16,
                      const _NextStepBanner(),
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
                child: PrimaryButton(
                  label: '챗봇 페르소나 설정하기',
                  enabled: hasResult,
                  onPressed: () => context.pushNamed(AppRoute.personaIntro),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Big5Results extends StatelessWidget {
  const _Big5Results({required this.scores});

  final Map<String, int> scores;

  static const _labels = {
    'O': '개방성',
    'C': '성실성',
    'E': '외향성',
    'A': '우호성',
    'N': '정서 민감성',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CardSectionHeader(
          icon: Icons.insights_rounded,
          title: 'Big Five 결과',
        ),
        Gap.h12,
        for (final entry in _labels.entries) ...[
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(entry.value, style: AppTypography.body),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: (scores[entry.key] ?? 0) / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.primarySoftBorder,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 30,
                child: Text(
                  '${scores[entry.key] ?? 0}',
                  textAlign: TextAlign.right,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (entry.key != 'N') Gap.h12,
        ],
      ],
    );
  }
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.info});
  final PsychTestInfo info;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(info.icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('${info.questionCount}문항', style: AppTypography.caption),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '완료',
              style: AppTypography.caption.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepBanner extends StatelessWidget {
  const _NextStepBanner();

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
            Icons.auto_awesome_rounded,
            size: 22,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '다음 단계 준비 완료',
                  style: AppTypography.bodySecondary.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '검사 결과는 상담의 보조 맥락으로만 사용돼요. 이제 원하는 말투와 성격을 직접 설정해보세요.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
