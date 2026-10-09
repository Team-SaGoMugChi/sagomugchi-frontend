import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/media/guided_conversation_controller.dart';
import '../../../../core/media/mascot_speech.dart';
import '../../../../core/media/tts_service.dart';
import '../../../../data/dummy/baseline_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/call_room_background.dart';
import '../../../../widgets/help_sheet.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../widgets/talking_tankachu.dart';
import '../../../../widgets/tankachu_call_stage.dart';
import '../../../../widgets/video_call_widgets.dart';

/// Screen 11 — 튜토리얼 통화 연습 (1/5). Video-call style practice → 2/5.
///
/// 실제 일기 말하기(37번)와 같은 영상통화 화면이다 — 말하는 탄카츄가 안내
/// 대본을 소리로 읽고, 사용자가 대답하는 동안 기다렸다가 다음 줄로 넘어간다.
class TutorialCallScreen extends ConsumerStatefulWidget {
  const TutorialCallScreen({super.key});

  @override
  ConsumerState<TutorialCallScreen> createState() =>
      _TutorialCallScreenState();
}

class _TutorialCallScreenState extends ConsumerState<TutorialCallScreen> {
  // 연습용 시각 상태 토글 (실제 녹음 없음).
  bool _micMuted = false;
  bool _speakerOff = false;

  /// 통화를 시작한 시각 — 낮/밤 배경을 고른다.
  final _startedAt = DateTime.now();

  /// 탄카츄 입이 따라갈 문장.
  late final MascotSpeech _speech;

  /// 지금 탄카츄가 말하는 중인지, 사용자의 대답을 기다리는 중인지.
  ConversationTurn? _turn;

  @override
  void initState() {
    super.initState();
    _speech = MascotSpeech(ref.read(ttsServiceProvider));
    Future.microtask(_run);
  }

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (!mounted) return;
    await ref
        .read(guidedConversationControllerProvider)
        .run(
          BaselineDummy.guideScript,
          onTurn: (turn) {
            if (mounted) setState(() => _turn = turn);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    // autoDispose 서비스 체인(TTS+STT)이 이 화면이 떠 있는 동안 계속 살아있게
    // 붙잡아 둔다.
    ref.watch(guidedConversationControllerProvider);
    final turn = _turn;

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: CallRoomBackground(
        startedAt: _startedAt,
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.callTextPrimary),
                    onPressed: () {
                      if (context.canPop()) context.pop();
                    },
                  ),
                  const Expanded(
                    child: Text('튜토리얼 1/5',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.callTextPrimary)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded,
                        color: AppColors.callTextPrimary),
                    onPressed: () => showHelpSheet(
                      context,
                      title: '통화 연습 도움말',
                      items: const [
                        '실제 일기 작성과 같은 영상통화 화면이에요.',
                        '연습이니까 아무 말이나 편하게 해봐도 돼요.',
                        '아래 통화 종료 버튼을 누르면 다음 단계로 넘어가요.',
                      ],
                    ),
                  ),
                ],
              ),
              const CallStatusRow(label: 'AI와 실시간 대화 중'),
              Gap.h8,
              Expanded(
                child: Stack(
                  children: [
                    // 탄카츄 — 실제 말하기 화면과 같은 상반신 배치.
                    Positioned.fill(
                      child: TankachuCallStage(
                        speech: _speech,
                        mood: turn != null && !turn.speaking
                            ? TankachuMood.listening
                            : TankachuMood.idle,
                      ),
                    ),
                    const Positioned(
                      top: 8,
                      left: AppSpacing.screenH,
                      child: CallChip(
                          icon: Icons.graphic_eq_rounded, label: '음성 인식 중'),
                    ),
                    Positioned(
                      top: 4,
                      right: AppSpacing.screenH,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                            color: AppColors.callSurface, shape: BoxShape.circle),
                        child: const Icon(Icons.cameraswitch_rounded,
                            size: 18, color: AppColors.callTextSecondary),
                      ),
                    ),
                    // 우상단(카메라 전환 버튼 아래) — 하단 버튼과 겹치지 않게.
                    const Positioned(
                        top: 56,
                        right: AppSpacing.screenH,
                        child: CallUserPreview()),
                    // 탄카츄가 읽는 안내(또는 대답을 기다리는 안내) 자막.
                    if (turn != null)
                      Positioned(
                        left: AppSpacing.screenH,
                        right: AppSpacing.screenH,
                        bottom: 104,
                        child: _CaptionBubble(text: turn.caption),
                      ),
                    Positioned(
                      right: 0,
                      left: 0,
                      bottom: 12,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CallControlButton(
                              icon: _micMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              onTap: () =>
                                  setState(() => _micMuted = !_micMuted),
                            ),
                            const SizedBox(width: 20),
                            const CallControlButton(
                                icon: Icons.call_end_rounded, danger: true),
                            const SizedBox(width: 20),
                            CallControlButton(
                              icon: _speakerOff
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              onTap: () =>
                                  setState(() => _speakerOff = !_speakerOff),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                    AppSpacing.xs, AppSpacing.screenH, AppSpacing.xs),
                child: Column(
                  children: [
                    const _GuidePanel(),
                    Gap.h12,
                    PrimaryButton(
                      label: '대화 시작하기',
                      trailingIcon: Icons.chevron_right_rounded,
                      onPressed: () =>
                          context.pushNamed(AppRoute.tutorialSelfIntro),
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

/// 말풍선 자막 — 말하기 화면(37번)의 말풍선과 같은 모양.
class _CaptionBubble extends StatelessWidget {
  const _CaptionBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        style: AppTypography.bodySecondary.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.videocam_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('지금부터 간단한 대화를 통해 당신의 평소 상태를 파악할 거예요.',
                    style: AppTypography.bodySecondary
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text('약 5~7분 정도 소요돼요. 편하게 이야기해주세요.',
                    style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
