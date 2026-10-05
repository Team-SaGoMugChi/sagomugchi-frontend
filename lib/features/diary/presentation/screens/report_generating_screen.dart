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
import '../../application/counsel_report_controller.dart';

/// Screen 45 — 상담 후 리포트 생성. 상담이 끝나면 서버에 대화를 보내 리포트를
/// 만들고, 완성되면 46번 화면으로 넘어간다.
///
/// 생성에 실패하거나 30초를 넘겨도 46번으로 넘어간다 — 그쪽이 실패 배너와
/// 다시 시도를 띄우고, 카드는 샘플로 채워져 화면이 비지 않는다.
///
/// 리포트는 서버가 LLM을 한 번 불러 한꺼번에 돌려주므로 중간 진행률을 알 수
/// 없다. 앱이 아는 건 요청을 보낸 때와 응답이 온 때뿐이라, 단계는 그 두 시점만
/// 표시하고 막대는 기다린 시간으로 채운다(그래서 % 숫자는 띄우지 않는다).
class ReportGeneratingScreen extends ConsumerStatefulWidget {
  const ReportGeneratingScreen({super.key});

  @override
  ConsumerState<ReportGeneratingScreen> createState() =>
      _ReportGeneratingScreenState();
}

class _ReportGeneratingScreenState extends ConsumerState<ReportGeneratingScreen>
    with SingleTickerProviderStateMixin {
  bool _advanced = false;

  /// 서버 응답(성공·실패·타임아웃)이 왔는지.
  bool _responded = false;

  /// 기다린 시간으로 채우는 막대 — 응답 전에는 [_waitingCap]에서 멈춘다.
  late final AnimationController _progress = AnimationController(vsync: this);

  static const List<String> _items = ['상담 대화 전달', 'AI 리포트 작성', '리포트 완성'];

  /// 응답이 너무 빨리 오면 화면이 깜빡이므로 최소한 이만큼은 보여준다.
  static const Duration _minimumVisible = Duration(milliseconds: 1500);

  /// 보통 걸리는 시간(안내 문구 "10~20초"). 이 시간에 걸쳐 [_waitingCap]까지 찬다.
  static const Duration _typicalWait = Duration(seconds: 15);
  static const double _waitingCap = 0.9;

  /// 응답이 온 뒤 남은 막대를 채우는 시간.
  static const Duration _finishFill = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _progress.animateTo(_waitingCap,
        duration: _typicalWait, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final startedAt = DateTime.now();
    // 30초 타임아웃은 컨트롤러가 건다 — 여기서 무한정 기다리지 않는다.
    await ref.read(counselReportControllerProvider.notifier).generate();
    if (!mounted) return;
    setState(() => _responded = true);
    await _progress.animateTo(1, duration: _finishFill, curve: Curves.easeOut);
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < _minimumVisible) {
      await Future<void>.delayed(_minimumVisible - elapsed);
    }
    _advance();
  }

  void _advance() {
    if (_advanced || !mounted) return;
    _advanced = true;
    context.pushReplacementNamed(AppRoute.reportGuide);
  }

  @override
  Widget build(BuildContext context) {
    final failed = ref.watch(counselReportControllerProvider).failed;
    final steps = [
      _StepState.done,
      _responded
          ? (failed ? _StepState.failed : _StepState.done)
          : _StepState.running,
      _responded && !failed ? _StepState.done : _StepState.pending,
    ];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () {
                      if (context.canPop()) context.pop();
                    },
                  ),
                  const Expanded(
                    child: Text('상담 후 리포트 생성',
                        textAlign: TextAlign.center,
                        style: AppTypography.subtitle),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: AppColors.primary),
                          ),
                        ),
                        Gap.h20,
                        const Text('리포트를 만들고 있어요',
                            textAlign: TextAlign.center,
                            style: AppTypography.title),
                        Gap.h8,
                        const Text('상담 내용을 바탕으로\n나만의 맞춤 리포트를 만들고 있어요.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySecondary),
                        Gap.h24,
                        // TODO: 차트를 정리하는 포즈로 교체 예정
                        const Center(
                            child: MascotImage(
                                pose: MascotPose.clipboard, size: 150)),
                        Gap.h24,
                        _ProgressCard(
                            items: _items, steps: steps, progress: _progress),
                        Gap.h16,
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text('잠시만 기다려 주세요! 보통 10~20초 정도 소요돼요.',
                                    style: AppTypography.caption),
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
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                    AppSpacing.xs, AppSpacing.screenH, AppSpacing.xs),
                child: _StatusButton(onTap: _advance),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StepState { pending, running, done, failed }

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.items,
    required this.steps,
    required this.progress,
  });
  final List<String> items;
  final List<_StepState> steps;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return OddoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('리포트 생성 상황',
              style: AppTypography.bodySecondary
                  .copyWith(fontWeight: FontWeight.w700)),
          Gap.h8,
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: AnimatedBuilder(
              animation: progress,
              builder: (_, _) => LinearProgressIndicator(
                value: progress.value,
                minHeight: 8,
                backgroundColor: AppColors.primarySoftBorder,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          Gap.h12,
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _StepIcon(state: steps[i]),
                  const SizedBox(width: 8),
                  Text(items[i],
                      style: steps[i] == _StepState.pending
                          ? AppTypography.bodySecondary
                              .copyWith(color: AppColors.textTertiary)
                          : AppTypography.bodySecondary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.state});
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      _StepState.done => const Icon(Icons.check_circle_rounded,
          size: 16, color: AppColors.primary),
      _StepState.running => const SizedBox(
          width: 16,
          height: 16,
          child: Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      _StepState.pending => const Icon(Icons.radio_button_unchecked_rounded,
          size: 16, color: AppColors.textTertiary),
      // 실패해도 46번이 배너와 다시 시도를 띄우므로 여기선 조용히 표시만 한다.
      _StepState.failed => const Icon(Icons.error_outline_rounded,
          size: 16, color: AppColors.textSecondary),
    };
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundAlt,
      borderRadius: AppRadius.button,
      child: InkWell(
        borderRadius: AppRadius.button,
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Text('리포트 보기 (잠시 후 자동으로 이동해요)',
              style: AppTypography.button
                  .copyWith(color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}
