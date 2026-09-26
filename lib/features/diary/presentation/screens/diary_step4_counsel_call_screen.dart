import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/media/audio_recorder_service.dart';
import '../../../../core/media/tts_service.dart';
import '../../../../core/permissions/app_permissions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/dummy/diary_flow_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/help_sheet.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/video_call_widgets.dart';
import '../../../records/application/viewing_date_provider.dart';
import '../../application/counsel_controller.dart';
import '../../application/diary_draft_provider.dart';
import '../../data/diary_providers.dart';
import '../../data/models/counsel_session.dart';

/// Screen 44 — Step 4. 영상통화 상담. 상담 종료 → 리포트 생성.
///
/// 음성 대화는 Step1 말하기와 같은 재료를 쓴다 — [AudioRecorderService]로
/// 녹음하고 `POST /stt/transcribe`로 텍스트를 받는다. 상담봇 응답은 앱에서
/// [TtsService](flutter_tts)로 읽는다. 서버 TTS를 따로 두지 않는 이유는
/// 튜토리얼·baseline 안내가 이미 같은 방식으로 말하고 있어서다.
///
/// 마이크 버튼은 누를 때마다 녹음 시작/중지가 번갈아 일어난다(푸시투토크가
/// 아니라 토글) — 통화 중 한 손으로 쓰기 쉽고, 말이 느린 사용자가 눌린 채로
/// 기다리지 않아도 된다.
class DiaryStep4CounselCallScreen extends ConsumerStatefulWidget {
  const DiaryStep4CounselCallScreen({super.key});

  @override
  ConsumerState<DiaryStep4CounselCallScreen> createState() =>
      _DiaryStep4CounselCallScreenState();
}

class _DiaryStep4CounselCallScreenState
    extends ConsumerState<DiaryStep4CounselCallScreen> {
  /// 녹음 중 — 마이크 버튼으로 켜고 끈다.
  bool _recording = false;

  /// 녹음을 텍스트로 옮기는 중(STT 응답 대기).
  bool _transcribing = false;

  /// 상담봇 응답을 소리로 읽을지. 끄면 자막만 남는다.
  bool _speakerOff = false;

  /// 에뮬레이터처럼 마이크가 없는 환경에서 대화 왕복을 확인하기 위한 입력줄.
  /// 실기기 테스트가 끝나면 지운다.
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 같은 날 저장된 상담이 있으면 불러와 이어서 대화한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(counselControllerProvider.notifier)
          .restoreIfEmpty(ref.read(viewingDateProvider));
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// 상담 종료 — 대화를 draft에 넘기고 리포트 생성으로 넘어간다.
  /// 실제 저장은 46번 화면의 "기록 완료하기"에서 한 번에 이뤄진다.
  Future<void> _endCounsel() async {
    // 말하던 중에 눌러도 마이크와 스피커가 살아남지 않게 먼저 정리한다.
    if (_recording) await ref.read(audioRecorderProvider).stop();
    await ref.read(ttsServiceProvider).stop();

    final counsel = ref.read(counselControllerProvider);
    ref
        .read(diaryDraftProvider.notifier)
        .setCounsel(messages: counsel.messages, startedAt: counsel.startedAt);
    if (mounted) context.pushReplacementNamed(AppRoute.reportGenerating);
  }

  /// 마이크 버튼 — 녹음 시작/중지를 번갈아 한다.
  Future<void> _toggleRecording() async {
    if (_transcribing) return;
    if (_recording) {
      await _stopAndSend();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // 상담봇이 말하는 중이면 멈춘다 — 스피커 소리가 마이크로 다시 들어간다.
    await ref.read(ttsServiceProvider).stop();

    final recorder = ref.read(audioRecorderProvider);
    final fileName =
        'counsel_${DateFormatter.dateKey(DateTime.now())}'
        '_${DateTime.now().millisecondsSinceEpoch}';

    var started = await recorder.start(fileName: fileName);
    if (!started) {
      // 권한이 아직 없을 때만 한 번 더 — 거부한 사용자를 반복해서 조르지 않는다.
      final granted = await AppPermissions.requestCameraAndMic();
      if (granted) started = await recorder.start(fileName: fileName);
    }
    if (!mounted) return;
    if (!started) {
      _showMessage('마이크를 쓸 수 없어요. 설정에서 권한을 켜주세요.');
      return;
    }
    setState(() => _recording = true);
  }

  Future<void> _stopAndSend() async {
    final path = await ref.read(audioRecorderProvider).stop();
    if (!mounted) return;
    setState(() => _recording = false);

    if (path == null) {
      _showMessage('녹음을 가져오지 못했어요. 다시 한 번 눌러주세요.');
      return;
    }

    setState(() => _transcribing = true);
    String text;
    try {
      text = await ref
          .read(diaryAnalysisRepositoryProvider)
          .transcribe(voiceFilePath: path);
    } on AppException catch (e) {
      // 서버가 재녹음 안내 문구를 내려준다 — 있으면 그대로 보여준다.
      if (mounted) {
        setState(() => _transcribing = false);
        _showMessage(e.message);
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _transcribing = false);
        _showMessage('음성을 옮기지 못했어요. 잠시 후 다시 시도해주세요.');
      }
      return;
    }

    if (!mounted) return;
    setState(() => _transcribing = false);
    if (text.trim().isEmpty) {
      _showMessage('말소리를 알아듣지 못했어요. 조금 더 또박또박 말해주세요.');
      return;
    }
    await ref.read(counselControllerProvider.notifier).sendTurn(text);
  }

  Future<void> _toggleSpeaker() async {
    final turningOff = !_speakerOff;
    if (turningOff) await ref.read(ttsServiceProvider).stop();
    if (mounted) setState(() => _speakerOff = turningOff);
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(counselControllerProvider.notifier).sendTurn(text);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 새로 도착한 상담봇 응답만 읽는다 — 화면이 다시 그려질 때마다 반복해서
  /// 읽지 않도록 메시지가 늘어난 순간에만 부른다.
  void _speakIfNew(CounselState? previous, CounselState next) {
    if (_speakerOff) return;
    if (next.messages.length <= (previous?.messages.length ?? 0)) return;
    final last = next.messages.last;
    if (last.speaker != CounselSpeaker.oddo) return;
    ref.read(ttsServiceProvider).speak(last.text);
  }

  @override
  Widget build(BuildContext context) {
    // 둘 다 autoDispose라 아무도 watch하지 않으면 사용 도중 폐기될 수 있다 —
    // 이 화면이 살아있는 동안 붙잡아 둔다(Step1 말하기 화면과 같은 이유).
    ref.watch(audioRecorderProvider);
    ref.watch(ttsServiceProvider);

    ref.listen<CounselState>(counselControllerProvider, _speakIfNew);

    final counsel = ref.watch(counselControllerProvider);
    final busy = counsel.sending || _transcribing;

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
                      '마이크를 누르고 말한 뒤, 다 말했으면 다시 눌러주세요.',
                      '떠오르는 대로 편하게 답하면 돼요. 정답은 없어요.',
                      '상담 종료를 누르면 감정 리포트가 만들어져요.',
                    ],
                  ),
                ),
              ],
            ),
            CallStatusRow(
              label: _recording
                  ? '듣고 있어요'
                  : _transcribing
                  ? '말을 옮기고 있어요'
                  : DiaryFlowDummy.counselStatus,
              dotColor: _recording ? AppColors.error : AppColors.success,
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
                  // TODO: 실기기 음성 테스트가 끝나면 이 입력줄 제거.
                  Positioned(
                    left: AppSpacing.screenH,
                    right: AppSpacing.screenH,
                    bottom: 104,
                    child: _TempInputBar(
                      controller: _input,
                      sending: busy,
                      enabled: !counsel.crisis && !_recording,
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
                            icon: _recording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            label: _recording
                                ? '다 말했어요'
                                : _transcribing
                                ? '옮기는 중'
                                : '말하기',
                            onTap: counsel.crisis || _transcribing
                                ? null
                                : _toggleRecording,
                          ),
                          const SizedBox(width: 20),
                          CallControlButton(
                            icon: Icons.call_end_rounded,
                            label: '상담 종료',
                            danger: true,
                            onTap: _endCounsel,
                          ),
                          const SizedBox(width: 20),
                          CallControlButton(
                            icon: _speakerOff
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            label: _speakerOff ? '소리 꺼짐' : '스피커',
                            onTap: _toggleSpeaker,
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

/// 마이크가 없는 환경(에뮬레이터)에서 대화 왕복을 확인하기 위한 입력줄.
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

  /// 위기 안내 중이거나 녹음 중에는 입력을 막는다.
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
                hintText: enabled ? '하고 싶은 말을 적어보세요' : '지금은 듣고 있어요',
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