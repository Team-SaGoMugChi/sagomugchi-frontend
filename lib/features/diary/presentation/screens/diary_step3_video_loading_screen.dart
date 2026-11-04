import 'dart:async';

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
import '../../../../widgets/card_section_header.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/oddo_card.dart';
import '../../../../widgets/primary_button.dart';
import '../../application/diary_draft_provider.dart';
import '../../application/video_job_controller.dart';
import '../widgets/diary_step_header.dart';

/// Screen 41 — Step 3. 영상 제작 로딩. 서버에 영상 생성 작업을 등록하고
/// 진행률을 보여주다가, 완성되면 42번 화면으로 넘어간다. 실패하면 다시
/// 시도하거나 홈으로 간다 — 상담은 영상을 본 뒤에 하므로 영상 없이 넘어가지 않는다.
class DiaryStep3VideoLoadingScreen extends ConsumerStatefulWidget {
  const DiaryStep3VideoLoadingScreen({super.key});

  @override
  ConsumerState<DiaryStep3VideoLoadingScreen> createState() =>
      _DiaryStep3VideoLoadingScreenState();
}

class _DiaryStep3VideoLoadingScreenState
    extends ConsumerState<DiaryStep3VideoLoadingScreen> {
  static const Map<String, String> _stageLabels = {
    'storyboard': '이야기를 장면으로 나누고 있어요',
    'images': '장면을 그리고 있어요',
    'videos': '장면을 영상으로 만들고 있어요',
    'narration': '나레이션을 입히고 있어요',
    'compose': '영상을 이어 붙이고 있어요',
    'done': '영상이 완성됐어요',
  };

  static const _tick = Duration(milliseconds: 500);

  Timer? _ticker;
  double _shown = 0;

  void _advance() {
    final job = ref.read(videoJobControllerProvider).job;
    if (job == null) {
      _shown = 0; // 다시 시도하면 처음부터 센다.
      return;
    }
    setState(() {
      _shown = nextDisplayedProgress(
        current: _shown,
        serverProgress: job.progress,
        stage: job.stage,
        elapsed: _tick,
      );
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(_tick, (_) => _advance());
    // initState 안에서 바로 start()를 부르면 상태 변경이 빌드 도중 일어날 수
    // 있어 다음 마이크로태스크로 미룬다(step1 처리 화면과 동일).
    Future.microtask(
      () => ref.read(videoJobControllerProvider.notifier).start(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(videoJobControllerProvider, (previous, next) {
      if (next.isDone && !(previous?.isDone ?? false) && mounted) {
        context.pushReplacementNamed(AppRoute.diaryStep3VideoDone);
      }
    });

    final video = ref.watch(videoJobControllerProvider);
    final job = video.job;
    final summary =
        ref.watch(diaryDraftProvider.select((d) => d.summary))?.trim() ?? '';

    final page = Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const DiaryStepHeader(currentStep: 2, showBack: false),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Step 3. 영상 제작',
                          style: AppTypography.bodySecondary.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Gap.h8,
                      const Text(
                        '영상을 만들고 있어요',
                        textAlign: TextAlign.center,
                        style: AppTypography.title,
                      ),
                      Gap.h8,
                      const Text(
                        '모든 내용을 종합해\n오늘의 이야기를 영상으로 제작하고 있어요.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySecondary,
                      ),
                      Gap.h24,
                      // TODO: 카메라/노트북으로 영상을 만드는 포즈로 교체 예정
                      const Center(
                        child: MascotImage(pose: MascotPose.camera, size: 160),
                      ),
                      Gap.h24,
                      if (video.isFailed)
                        _ErrorContent(
                          message: video.error!,
                          onRetry: () => ref
                              .read(videoJobControllerProvider.notifier)
                              .retry(),
                          onHome: () => context.goNamed(AppRoute.home),
                        )
                      else ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            // 등록 전(job == null)에는 움직이는 막대로 보여준다.
                            value: job == null ? null : _shown,
                            minHeight: 8,
                            backgroundColor: AppColors.primarySoftBorder,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        Gap.h8,
                        Center(
                          child: Text(
                            job == null
                                ? '영상 제작을 준비하고 있어요'
                                : '${_stageLabels[job.stage] ?? '영상을 만들고 있어요'}'
                                      ' · ${(_shown * 100).floor()}%',
                            style: AppTypography.caption,
                          ),
                        ),
                        Gap.h4,
                        const Center(
                          child: Text(
                            '영상은 몇 분 정도 걸릴 수 있어요.',
                            style: AppTypography.caption,
                          ),
                        ),
                        if (job != null) ...[
                          Gap.h16,
                          SecondaryButton(
                            label: '홈에서 기다리기',
                            onPressed: () => context.goNamed(AppRoute.home),
                          ),
                          Gap.h4,
                          const Center(
                            child: Text(
                              '다 만들어지면 홈에서 영상을 보고 이어서 할 수 있어요.',
                              textAlign: TextAlign.center,
                              style: AppTypography.caption,
                            ),
                          ),
                        ],
                      ],
                      if (summary.isNotEmpty) ...[
                        Gap.h24,
                        OddoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CardSectionHeader(
                                icon: Icons.auto_awesome_rounded,
                                title: 'AI 일기 요약',
                              ),
                              Gap.h8,
                              Text(summary, style: AppTypography.body),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // 일기를 고치러 돌아가면 영상을 새로 만들게 되어(비용 두 번) 뒤로 가지 않는다.
    // 뒤로가기는 "홈에서 기다리기"와 같다 — 작성 내용은 휴대폰에 남아 있다.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && job != null) context.goNamed(AppRoute.home);
      },
      child: page,
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.message,
    required this.onRetry,
    required this.onHome,
  });

  final String message;
  final VoidCallback onRetry;

  /// 일기는 휴대폰에 남아 있어 홈 카드에서 나중에 다시 시도할 수 있다.
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 32,
          color: AppColors.error,
        ),
        Gap.h12,
        const Text(
          '영상을 완성하지 못했어요',
          textAlign: TextAlign.center,
          style: AppTypography.subtitle,
        ),
        Gap.h8,
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
        Gap.h16,
        PrimaryButton(label: '다시 시도하기', onPressed: onRetry),
        Gap.h8,
        SecondaryButton(label: '홈으로 가기', onPressed: onHome),
        Gap.h4,
        const Text(
          '작성한 일기는 남아 있어요. 홈에서 다시 시도할 수 있어요.',
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
      ],
    );
  }
}
