import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/media/audio_recorder_service.dart';
import '../../../../core/media/tts_service.dart';
import '../../../../core/media/wav_merger.dart';
import '../../../../core/permissions/app_permissions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/camera_self_view.dart';
import '../../../../widgets/help_sheet.dart';
import '../../../../widgets/mascot_image.dart';
import '../../../../widgets/video_call_widgets.dart';
import '../../application/diary_draft_provider.dart';
import '../../application/diary_interview_controller.dart';
import '../../data/diary_providers.dart';
import '../../data/models/diary_interview.dart';
import '../widgets/diary_interview_copy.dart';

/// Screen 37 — Step 1. 말하기. 탄카츄와 영상통화처럼 주고받으며 오늘을 기록한다.
///
/// 차례 넘기기는 Step4 상담 통화와 같은 토글 버튼이다(말하기 → 다 말했어요).
/// 한 차례가 끝나면 그 녹음을 STT로 옮기고, `POST /diary/interview/turn`이
/// 일기에 빠진 사실(육하원칙·경과 시간)을 골라 다음 질문을 준다. 탄카츄가 말하는
/// 동안은 녹음하지 않아서, 탄카츄 목소리가 감정 분석(음성·원문)에 섞이지 않는다.
///
/// 통화 종료 → 얼굴을 캡처하고, 차례별 녹음을 하나로 이어 붙여 답변만 모은
/// 원문과 함께 draft에 싣는다. 처리 화면은 원문이 이미 있으니 STT를 다시 부르지
/// 않고 감정 분석만 한다 — 추가 질문에 대한 답도 분석에 들어간다.
class DiaryStep1LiveScreen extends ConsumerStatefulWidget {
  const DiaryStep1LiveScreen({super.key});

  @override
  ConsumerState<DiaryStep1LiveScreen> createState() =>
      _DiaryStep1LiveScreenState();
}

class _DiaryStep1LiveScreenState extends ConsumerState<DiaryStep1LiveScreen> {
  final _cameraKey = GlobalKey<CameraSelfViewState>();

  /// 녹음 중 — 마이크 버튼으로 켜고 끈다.
  bool _recording = false;

  /// 녹음을 텍스트로 옮기는 중(STT 응답 대기).
  bool _transcribing = false;

  /// 통화 종료 처리 중(캡처·녹음 합치기) — 버튼을 다시 못 누르게 한다.
  bool _ending = false;

  /// 탄카츄의 말을 소리로 읽을지. 끄면 자막만 남는다.
  bool _speakerOff = false;

  @override
  void initState() {
    super.initState();
    // 첫 인사는 대화 기록에 들어가야 서버가 무엇을 물었는지 안다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(diaryInterviewControllerProvider.notifier)
          .start(DiaryInterviewCopy.greeting);
    });
  }

  /// 마이크 버튼 — 녹음 시작/중지를 번갈아 한다. 중지하면 다음 질문을 받는다.
  Future<void> _toggleRecording() async {
    if (_transcribing || _ending) return;
    if (!_recording) {
      await _startRecording();
      return;
    }
    final turn = await _finishTurn();
    if (turn == null || !mounted) return;
    await ref
        .read(diaryInterviewControllerProvider.notifier)
        .addAnswer(
          recordingPath: turn.path,
          text: turn.text,
          keepGoing: DiaryInterviewCopy.keepGoing,
        );
  }

  Future<void> _startRecording() async {
    // 탄카츄가 말하는 중이면 멈춘다 — 스피커 소리가 녹음에 섞인다.
    await ref.read(ttsServiceProvider).stop();

    final recorder = ref.read(audioRecorderProvider);
    final turn =
        ref.read(diaryInterviewControllerProvider).recordingPaths.length + 1;
    final fileName =
        'diary_${DateFormatter.dateKey(DateTime.now())}_step1_$turn';

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

  /// 녹음을 멈추고 원문으로 옮긴다. 옮기지 못하면 null — 그 차례는 버린다.
  Future<({String path, String text})?> _finishTurn() async {
    final path = await ref.read(audioRecorderProvider).stop();
    if (!mounted) return null;
    setState(() => _recording = false);
    if (path == null) {
      _showMessage('녹음을 가져오지 못했어요. 다시 한 번 눌러주세요.');
      return null;
    }

    setState(() => _transcribing = true);
    try {
      final text = await ref
          .read(diaryAnalysisRepositoryProvider)
          .transcribe(voiceFilePath: path);
      if (text.trim().isEmpty) {
        _showMessage('말소리를 알아듣지 못했어요. 조금 더 또박또박 말해주세요.');
        return null;
      }
      return (path: path, text: text.trim());
    } on AppException catch (e) {
      // 서버가 재녹음 안내 문구를 내려준다 — 있으면 그대로 보여준다.
      _showMessage(e.message);
      return null;
    } catch (_) {
      _showMessage('음성을 옮기지 못했어요. 잠시 후 다시 시도해주세요.');
      return null;
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _endCall() async {
    if (_ending || _transcribing) return;
    setState(() => _ending = true);
    await ref.read(ttsServiceProvider).stop();

    // 정지 이미지 캡처를 녹음 정지보다 먼저 — 녹음을 멈추는 사이 프레임이
    // 바뀌는 걸 방지(baseline 측정과 같은 순서).
    final photo = await _cameraKey.currentState?.takePicture();
    if (_recording) {
      final turn = await _finishTurn();
      if (turn != null && mounted) {
        await ref
            .read(diaryInterviewControllerProvider.notifier)
            .addAnswer(
              recordingPath: turn.path,
              text: turn.text,
              keepGoing: DiaryInterviewCopy.keepGoing,
              askNext: false,
            );
      }
    }
    if (!mounted) return;

    final interview = ref.read(diaryInterviewControllerProvider);
    if (interview.recordingPaths.isEmpty) {
      setState(() => _ending = false);
      _showMessage('아직 들은 이야기가 없어요. 말하기를 눌러 오늘 있었던 일을 들려주세요.');
      return;
    }

    final String recordingPath;
    try {
      recordingPath = await WavMerger.mergeFiles(
        interview.recordingPaths,
        fileName: 'diary_${DateFormatter.dateKey(DateTime.now())}_step1',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _ending = false);
      _showMessage('녹음을 합치지 못했어요. 다시 시도해주세요.');
      return;
    }
    if (!mounted) return;

    // 새 녹음 경로가 이전 원문·요약·분석 결과를 지우므로 원문과 요약은 그 뒤에 싣는다.
    final draft = ref.read(diaryDraftProvider.notifier);
    if (photo != null) draft.setFaceImagePath(photo.path);
    draft
      ..setRecordingPath(recordingPath)
      ..setTranscript(interview.transcript);
    final summary = interview.summary;
    if (summary != null) draft.setSummary(summary);
    context.pushReplacementNamed(AppRoute.diaryStep1Processing);
  }

  Future<void> _toggleSpeaker() async {
    final turningOff = !_speakerOff;
    if (turningOff) await ref.read(ttsServiceProvider).stop();
    if (mounted) setState(() => _speakerOff = turningOff);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 새로 도착한 탄카츄의 말만 읽는다 — 화면이 다시 그려질 때마다 반복해서
  /// 읽지 않도록 메시지가 늘어난 순간에만 부른다. 육하원칙 칸이 다 차서
  /// 마무리 인사가 오면, 다 읽은 뒤 통화를 끝내고 원문 확인으로 넘어간다.
  void _onInterviewChanged(
    DiaryInterviewState? previous,
    DiaryInterviewState next,
  ) {
    if (next.messages.length <= (previous?.messages.length ?? 0)) return;
    final last = next.messages.last;
    if (last.speaker != InterviewSpeaker.oddo) return;
    final finished = next.done && !(previous?.done ?? false);
    _say(last.text, thenEnd: finished);
  }

  Future<void> _say(String text, {required bool thenEnd}) async {
    if (!_speakerOff && !_recording) {
      await ref.read(ttsServiceProvider).speak(text);
    } else if (thenEnd) {
      // 소리를 껐으면 말풍선을 읽을 시간을 준다.
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (thenEnd && mounted) await _endCall();
  }

  @override
  Widget build(BuildContext context) {
    // 둘 다 autoDispose라 아무도 watch하지 않으면 사용 도중 폐기될 수 있다 —
    // 이 화면이 살아있는 동안 붙잡아 둔다.
    ref.watch(audioRecorderProvider);
    ref.watch(ttsServiceProvider);

    ref.listen<DiaryInterviewState>(
      diaryInterviewControllerProvider,
      _onInterviewChanged,
    );

    final interview = ref.watch(diaryInterviewControllerProvider);

    // 마지막 탄카츄의 말 — 대화를 열기 전이면 첫 인사.
    final lastOddo = interview.messages.lastWhere(
      (m) => m.speaker == InterviewSpeaker.oddo,
      orElse: () => const InterviewMessage(
        speaker: InterviewSpeaker.oddo,
        text: DiaryInterviewCopy.greeting,
      ),
    );
    final bubbleText = interview.waiting
        ? DiaryInterviewCopy.thinking
        : lastOddo.text;
    final micLocked =
        interview.crisis ||
        interview.waiting ||
        interview.done ||
        _transcribing ||
        _ending;

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.callTextPrimary,
                  ),
                  onPressed: () {
                    if (context.canPop()) context.pop();
                  },
                ),
                Expanded(
                  child: Text(
                    'Step 1. 말하기',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.help_outline_rounded,
                    size: 20,
                    color: AppColors.callTextPrimary,
                  ),
                  onPressed: () => showHelpSheet(
                    context,
                    title: '말하기 도움말',
                    items: const [
                      '탄카츄가 묻는 말에 통화하듯 편하게 답해주세요.',
                      '마이크를 누르고 말한 뒤, 다 말했으면 다시 눌러주세요.',
                      '탄카츄가 빠진 내용을 몇 가지 더 물어볼 수 있어요.',
                      '통화 종료를 누르면 대화가 끝나고 분석이 시작돼요.',
                    ],
                  ),
                ),
              ],
            ),
            CallStatusRow(
              label: DiaryInterviewCopy.callStatus(
                recording: _recording,
                transcribing: _transcribing,
                waiting: interview.waiting,
                ending: _ending,
                done: interview.done,
                crisis: interview.crisis,
              ),
              dotColor: _recording ? AppColors.error : AppColors.success,
            ),
            Expanded(
              child: Stack(
                children: [
                  // TODO: 큰 상담 상대처럼 손 흔드는 포즈로 교체 예정
                  const Center(
                    child: MascotImage(
                      pose: MascotPose.waving,
                      size: 200,
                      onDark: true,
                    ),
                  ),
                  if (_recording)
                    const Positioned(
                      top: 8,
                      left: AppSpacing.screenH,
                      child: CallChip(
                        icon: Icons.graphic_eq_rounded,
                        label: '음성 인식 중',
                      ),
                    ),
                  const Positioned(
                    top: 8,
                    right: AppSpacing.screenH,
                    child: CallAnalysisChip(),
                  ),
                  // 우상단(실시간 감정 분석 칩 아래) — 하단 버튼과 겹치지 않게.
                  Positioned(
                    top: 76,
                    right: AppSpacing.screenH,
                    child: CallUserPreview(cameraKey: _cameraKey),
                  ),
                  // 위기 발화가 감지되면 대화를 멈추고 전문 기관 안내를 띄운다.
                  if (interview.crisis)
                    const Positioned(
                      left: AppSpacing.screenH,
                      right: AppSpacing.screenH,
                      bottom: 176,
                      child: _CrisisBanner(),
                    ),
                  // 말풍선 — 컨트롤 버튼 위로 띄운다.
                  Positioned(
                    left: AppSpacing.screenH,
                    right: AppSpacing.screenH,
                    bottom: 104,
                    child: _OddoBubble(text: bubbleText),
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
                            onTap: micLocked ? null : _toggleRecording,
                          ),
                          const SizedBox(width: 20),
                          CallControlButton(
                            icon: Icons.call_end_rounded,
                            label: '통화 종료',
                            danger: true,
                            onTap: _ending || _transcribing ? null : _endCall,
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

// TODO(다경과 합의 후): Step4 통화 화면의 같은 위젯과 함께 lib/widgets로 추출.
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

/// 위기 발화 감지 시 안내 — 질문 대신 전문 기관 연결을 먼저 보여준다.
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
