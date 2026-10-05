import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/app_exception.dart';
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
import '../../application/step1_analysis_controller.dart';
import '../widgets/loading_progress_card.dart';

/// Screen 38 — Step 1 처리 중. 녹음/얼굴 캡처를 baseline과 비교해 감정을
/// 뽑는 실제 서버 호출(step1AnalysisController)을 진행하고, 끝나면 Step 2
/// 확인하기로 넘어간다. 실패하면 재시도할 수 있다. 기다리는 동안 말하기
/// 대화에서 받은 AI 일기 요약을 보여준다(없으면 숨김).
///
/// 진행 카드는 컨트롤러가 실제로 거치는 단계([Step1Stage])를 따른다. 감정
/// 분석은 서버 한 번 호출이라 중간 진행률을 몰라서 그 몫만 기다린 시간으로
/// 채운다.
class DiaryStep1ProcessingScreen extends ConsumerStatefulWidget {
  const DiaryStep1ProcessingScreen({super.key});

  @override
  ConsumerState<DiaryStep1ProcessingScreen> createState() =>
      _DiaryStep1ProcessingScreenState();
}

class _DiaryStep1ProcessingScreenState
    extends ConsumerState<DiaryStep1ProcessingScreen>
    with SingleTickerProviderStateMixin {
  /// 진행 카드에 보여줄 단계 이름 — 위에서부터 이 순서로 보인다.
  static const Map<Step1Stage, String> _labels = {
    Step1Stage.baseline: '베이스라인 불러오기',
    Step1Stage.transcribe: '음성 변환',
    Step1Stage.analyze: '감정 분석',
    Step1Stage.refine: '일기 정리',
  };

  /// 막대에서 각 단계가 차지하는 몫. 표정·목소리·글을 함께 보는 감정 분석이
  /// 가장 오래 걸린다.
  static const Map<Step1Stage, double> _weights = {
    Step1Stage.baseline: 0.1,
    Step1Stage.transcribe: 0.2,
    Step1Stage.analyze: 0.6,
    Step1Stage.refine: 0.1,
  };

  /// 감정 분석 몫을 [_analysisCap]까지 채우는 시간(안내 문구 "10~20초").
  static const Duration _typicalAnalysis = Duration(seconds: 15);
  static const double _analysisCap = 0.9;

  /// 단계가 끝났을 때 막대를 따라 올리는 시간.
  static const Duration _stepFill = Duration(milliseconds: 300);

  late final AnimationController _bar = AnimationController(vsync: this);

  /// 이 화면에 들어온 뒤 바뀐 진행 상태만 쓴다 — provider에 남은 지난 일기의
  /// 진행 상태가 한 프레임이라도 보이지 않게.
  Step1Progress _progress = const Step1Progress();

  @override
  void initState() {
    super.initState();
    // initState 안에서 바로 submit()을 부르면 상태 변경이 빌드 도중 일어날 수
    // 있어 다음 마이크로태스크로 미룬다(baseline_analyzing_screen과 동일).
    Future.microtask(
      () => ref.read(step1AnalysisControllerProvider.notifier).submit(),
    );
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  void _follow(Step1Progress progress) {
    setState(() => _progress = progress);
    final done = progress.done.fold(0.0, (sum, stage) => sum + _weights[stage]!);
    if (progress.running.contains(Step1Stage.analyze)) {
      _bar.animateTo(
        done + _weights[Step1Stage.analyze]! * _analysisCap,
        duration: _typicalAnalysis,
        curve: Curves.easeOutCubic,
      );
    } else {
      _bar.animateTo(done, duration: _stepFill, curve: Curves.easeOut);
    }
  }

  LoadingStepState _stateOf(Step1Stage stage) {
    if (_progress.done.contains(stage)) return LoadingStepState.done;
    if (_progress.running.contains(stage)) return LoadingStepState.running;
    return LoadingStepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(step1AnalysisControllerProvider, (previous, next) {
      final result = next.value;
      if (result != null && mounted) {
        context.pushReplacementNamed(AppRoute.diaryStep2Confirm);
      }
    });
    ref.listen(step1ProgressProvider, (_, next) => _follow(next));

    final analysis = ref.watch(step1AnalysisControllerProvider);
    final summary = ref.watch(diaryDraftProvider).summary;

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
                      'Step 1. 말하기',
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
                    child: analysis.hasError
                        ? _ErrorContent(
                            message: _errorMessage(analysis.error),
                            onRetry: () => ref
                                .read(step1AnalysisControllerProvider.notifier)
                                .submit(),
                          )
                        : _LoadingContent(
                            progress: LoadingProgressCard(
                              title: '분석 진행 상황',
                              progress: _bar,
                              steps: [
                                for (final MapEntry(:key, :value)
                                    in _labels.entries)
                                  (value, _stateOf(key)),
                              ],
                            ),
                            summary: summary,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is AppException) return error.message;
    return '분석 중 문제가 발생했어요. 잠시 후 다시 시도해주세요.';
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent({required this.progress, this.summary});
  final Widget progress;

  /// 말하기 대화에서 받은 일기 요약. 없으면 카드를 숨긴다.
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
        ),
        Gap.h20,
        const Text(
          '처리 중이에요',
          textAlign: TextAlign.center,
          style: AppTypography.title,
        ),
        Gap.h8,
        const Text(
          '말씀해 주신 내용을 텍스트로 바꾸고\n감정을 확인하고 있어요.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
        Gap.h24,
        // TODO: 헤드폰 끼고 노트북을 보는 포즈로 교체 예정
        const Center(child: MascotImage(pose: MascotPose.thinking, size: 150)),
        Gap.h24,
        progress,
        if (summary.isNotEmpty) ...[
          Gap.h16,
          // 41번 영상 제작 로딩의 요약 카드와 같은 모양.
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
        Gap.h16,
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '잠시만 기다려 주세요! 보통 10~20초 정도 소요돼요.',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const MascotImage(pose: MascotPose.thinking, size: 150),
        Gap.h20,
        const Icon(
          Icons.error_outline_rounded,
          size: 32,
          color: AppColors.error,
        ),
        Gap.h12,
        const Text(
          '감정 분석을 완료하지 못했어요',
          textAlign: TextAlign.center,
          style: AppTypography.title,
        ),
        Gap.h8,
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
        Gap.h24,
        PrimaryButton(label: '다시 시도하기', onPressed: onRetry),
      ],
    );
  }
}
