import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/config/app_config_provider.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/dummy/dummy_seed.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/card_section_header.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/oddo_chip.dart';
import '../../../../widgets/primary_button.dart';
import '../../application/diary_draft_provider.dart';
import '../widgets/diary_step_header.dart';

/// Screen 39 — Step 2. 확인하기. Review/edit STT + summary + keywords + scores.
class DiaryStep2ConfirmScreen extends ConsumerStatefulWidget {
  const DiaryStep2ConfirmScreen({super.key});

  @override
  ConsumerState<DiaryStep2ConfirmScreen> createState() =>
      _DiaryStep2ConfirmScreenState();
}

class _DiaryStep2ConfirmScreenState
    extends ConsumerState<DiaryStep2ConfirmScreen> {
  // Step1 처리에서 받은 STT 원문. 화면 시연용 더미 모드에서만 샘플로 폴백.
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(diaryDraftProvider).transcript ??
        (ref.read(appConfigProvider).useDummyData
            ? DummySeed.diaryJan14.transcript
            : ''),
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = DummySeed.diaryJan14;
    final useDummyData = ref.watch(appConfigProvider).useDummyData;
    // 실제 모드에서는 서버가 계산한 값만 보여준다. AI 요약과 감정 안정도는
    // 아직 서버 출력에 없으므로 더미 모드가 아니면 표시하지 않는다.
    final fusionResult = ref.watch(diaryDraftProvider).fusionResult;
    final emotionKeywords = fusionResult?.emotionKeywords ??
        (useDummyData ? entry.emotionKeywords : const <String>[]);
    final emotionIntensity =
        fusionResult?.emotionIntensity ?? (useDummyData ? entry.emotionIntensity : 0);
    final canContinue =
        (useDummyData || fusionResult != null) && _controller.text.trim().isNotEmpty;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const DiaryStepHeader(currentStep: 1),
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
                      Text(
                        'Step 2. 확인하기',
                        style: AppTypography.bodySecondary.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Gap.h4,
                      const Text(
                        'AI가 정리한 내용을 확인해주세요',
                        style: AppTypography.title,
                      ),
                      Gap.h8,
                      const Text(
                        'STT가 잘 변환되었는지 확인하고, 틀린 부분은 직접 수정할 수 있어요.',
                        style: AppTypography.bodySecondary,
                      ),
                      Gap.h16,
                      _TranscriptCard(controller: _controller),
                      Gap.h12,
                      if (useDummyData) ...[
                        OddoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CardSectionHeader(
                                icon: Icons.auto_awesome_rounded,
                                title: 'AI 요약',
                              ),
                              Gap.h8,
                              Text(entry.summary, style: AppTypography.body),
                            ],
                          ),
                        ),
                        Gap.h12,
                      ],
                      OddoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CardSectionHeader(
                              icon: Icons.tag_rounded,
                              title: '감정 키워드',
                            ),
                            Gap.h12,
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final kw in emotionKeywords)
                                  OddoChip(label: kw, selected: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Gap.h12,
                      OddoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CardSectionHeader(
                              icon: Icons.monitor_heart_outlined,
                              title: '감정 점수',
                            ),
                            Gap.h12,
                            _ScoreBar(label: '감정 강도', value: emotionIntensity),
                            if (useDummyData) ...[
                              Gap.h12,
                              _ScoreBar(
                                label: '감정 안정도',
                                value: entry.emotionStability,
                              ),
                            ],
                          ],
                        ),
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
                  child: Column(
                    children: [
                      SecondaryButton(
                        label: '추가 정보가 필요해요!',
                        onPressed: () =>
                            context.pushNamed(AppRoute.diaryStep2Chat),
                      ),
                      Gap.h8,
                      PrimaryButton(
                        label: '저장하고 다음 단계',
                        enabled: canContinue,
                        onPressed: () {
                          // 수정한 원문을 완료 시 저장할 draft로 보관.
                          ref
                              .read(diaryDraftProvider.notifier)
                              .setTranscript(_controller.text);
                          context.pushNamed(AppRoute.diaryStep3VideoLoading);
                        },
                      ),
                    ],
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

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return OddoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CardSectionHeader(
                icon: Icons.record_voice_over_outlined,
                title: '대화 원문',
              ),
              Spacer(),
              // TODO: 노트를 든 포즈로 교체 예정
              MascotImage(pose: MascotPose.writing, size: 44),
            ],
          ),
          Gap.h8,
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              maxLength: 2000,
              style: AppTypography.body,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                counterText: '',
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${controller.text.characters.length} / 2000',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTypography.bodySecondary),
            const Spacer(),
            Text(
              '$value / 100',
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            backgroundColor: AppColors.primarySoftBorder,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}
