import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/dummy/diary_flow_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/help_sheet.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/video_call_widgets.dart';
import '../../application/counsel_controller.dart';
import '../../data/models/counsel_session.dart';

/// Screen 44 — Step 4. 영상통화 상담. 상담 종료 → 리포트 생성.
class DiaryStep4CounselCallScreen extends ConsumerStatefulWidget {
  const DiaryStep4CounselCallScreen({super.key});

  @override
  ConsumerState<DiaryStep4CounselCallScreen> createState() =>
      _DiaryStep4CounselCallScreenState();
}

class _DiaryStep4CounselCallScreenState
    extends ConsumerState<DiaryStep4CounselCallScreen> {
  // 시각 상태 토글 — 실제 오디오 입출력은 STT/TTS 연결 시 붙인다.
  bool _micMuted = false;
  bool _speakerOff = false;

  // TODO(Phase 5): STT 연결 후 제거 — 지금은 키보드로 대화 왕복을 확인한다.
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(counselControllerProvider.notifier).sendTurn(text);
  }

  @override
  Widget build(BuildContext context) {
    final counsel = ref.watch(counselControllerProvider);

    // 마지막 탄카츄 발화 — 아직 대화 전이면 기본 인사말.
    final lastOddo = counsel.messages.lastWhere(
      (m) => m.speaker == CounselSpeaker.oddo,
      orElse: () => const CounselMessage(
        speaker: CounselSpeaker.oddo,
        text: DiaryFlowDummy.counselBubble,
      ),
    );
    final bubbleText = counsel.sending ? '잠시만요, 생각하고 있어요…' : lastOddo.text;

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.callTextPrimary,
                  ),
                  onPressed: () {
                    if (context.canPop()) context.pop();
                  },
                ),
                const Expanded(
                  child: Text(
                    'Step 4. 상담하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.callTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.callTextPrimary,
                  ),
                  onPressed: () => showHelpSheet(
                    context,
                    title: '상담하기 도움말',
                    items: const [
                      '탄카츄가 오늘의 감정을 함께 돌아봐줘요.',
                      '떠오르는 대로 편하게 답하면 돼요. 정답은 없어요.',
                      '상담 종료를 누르면 감정 리포트가 만들어져요.',
                    ],
                  ),
                ),
              ],
            ),
            const CallStatusRow(
              label: DiaryFlowDummy.counselStatus,
              dotColor: AppColors.success,
            ),
            Expanded(
              child: Stack(
                children: [
                  const Center(
                    child: MascotImage(
                      pose: MascotPose.counselor,
                      size: 200,
                      onDark: true,
                    ),
                  ),
                  const Positioned(
                    top: 8,
                    right: AppSpacing.screenH,
                    child: CallAnalysisChip(),
                  ),
                  const Positioned(
                    top: 76,
                    right: AppSpacing.screenH,
                    child: CallUserPreview(width: 80, height: 106),
                  ),
                  // 위기 발화가 감지되면 상담을 멈추고 전문 기관 안내를 띄운다.
                  if (counsel.crisis)
                    const Positioned(
                      left: AppSpacing.screenH,
                      right: AppSpacing.screenH,
                      bottom: 244,
                      child: _CrisisBanner(),
                    ),
                  // 말풍선 — 입력줄과 컨트롤 버튼 위로 띄운다.
                  Positioned(
                    left: AppSpacing.screenH,
                    right: AppSpacing.screenH,
                    bottom: 172,
                    child: _OddoBubble(text: bubbleText),
                  ),
                  // TODO(Phase 5): STT 연결 후 이 입력줄 제거.
                  Positioned(
                    left: AppSpacing.screenH,
                    right: AppSpacing.screenH,
                    bottom: 104,
                    child: _TempInputBar(
                      controller: _input,
                      sending: counsel.sending,
                      enabled: !counsel.crisis,
                      onSend: _send,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CallControlButton(
                            icon: _micMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            label: _micMuted ? '음소거 중' : '마이크',
                            onTap: () => setState(() => _micMuted = !_micMuted),
                          ),
                          const SizedBox(width: 20),
                          CallControlButton(
                            icon: Icons.call_end_rounded,
                            label: '상담 종료',
                            danger: true,
                            onTap: () => context.pushReplacementNamed(
                              AppRoute.reportGenerating,
                            ),
                          ),
                          const SizedBox(width: 20),
                          CallControlButton(
                            icon: _speakerOff
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            label: '스피커',
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
          ],
        ),
      ),
    );
  }
}

class _OddoBubble extends StatelessWidget {
  const _OddoBubble({required this.text});

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

/// 위기 발화 감지 시 안내 — 상담 응답 대신 전문 기관 연결을 먼저 보여준다.
class _CrisisBanner extends StatelessWidget {
  const _CrisisBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '지금은 전문가와 이야기하는 게 좋겠어요.\n'
              '자살예방 상담전화 109 · 24시간 연결돼요.',
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// STT 연결 전 임시 입력줄. 대화 왕복 확인용.
class _TempInputBar extends StatelessWidget {
  const _TempInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  /// 위기 안내 중에는 입력을 막는다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled && !sending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: enabled ? '하고 싶은 말을 적어보세요' : '상담을 잠시 멈췄어요',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          if (sending)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: enabled ? onSend : null,
            ),
        ],
      ),
    );
  }
}
