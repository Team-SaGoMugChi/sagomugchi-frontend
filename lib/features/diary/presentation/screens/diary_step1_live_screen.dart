import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/media/audio_recorder_service.dart';
import '../../../../core/media/mascot_speech.dart';
import '../../../../core/media/tts_service.dart';
import '../../../../core/media/wav_merger.dart';
import '../../../../core/permissions/app_permissions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/call_room_background.dart';
import '../../../../widgets/camera_self_view.dart';
import '../../../../widgets/help_sheet.dart';
import '../../../../widgets/talking_tankachu.dart';
import '../../../../widgets/tankachu_call_stage.dart';
import '../../../../widgets/video_call_widgets.dart';
import '../../application/diary_draft_provider.dart';
import '../../application/diary_interview_controller.dart';
import '../../data/diary_providers.dart';
import '../../data/models/diary_interview.dart';
import '../widgets/answer_emotion_gauge.dart';
import '../widgets/diary_interview_copy.dart';

/// Screen 37 — Step 1. 말하기. 탄카츄와 영상통화처럼 주고받으며 오늘을 기록한다.
///
/// 버튼을 누르지 않는다 — 탄카츄 말이 끝나면 바로 듣기 시작하고, 말한 뒤 잠깐
/// 조용하면 차례를 넘긴다("다 말했어요"로 바로 넘길 수도 있다). 한 차례가 끝나면 그 녹음을 STT로 옮기고, `POST /diary/interview/turn`이
/// 일기에 빠진 사실(육하원칙·경과 시간)을 골라 다음 질문을 준다. 탄카츄가 말하는
/// 동안은 녹음하지 않아서, 탄카츄 목소리가 감정 분석(음성·원문)에 섞이지 않는다.
///
/// 답변을 녹음하는 동안 얼굴을 주기적으로 캡처하고, 통화 종료 시 차례별 녹음을 이어 붙여
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
  final Map<String, List<({String path, int timeMs})>> _turnFaces = {};
  final List<({String path, int timeMs})> _currentFaces = [];
  Timer? _faceTimer;
  Future<void>? _faceCapture;
  Stopwatch? _turnClock;
  bool _handedToDraft = false;

  /// 통화를 시작한 시각 — 낮/밤 배경을 고른다.
  final _startedAt = DateTime.now();

  /// 탄카츄 입이 따라갈 문장 — 소리로 읽을 땐 TTS가 알려주고, 소리를 끄면
  /// 말풍선 문장을 그대로 넣어 입만 움직인다.
  late final MascotSpeech _speech;

  @override
  void dispose() {
    _speech.dispose();
    _faceTimer?.cancel();
    _voiceWatch?.cancel();
    if (!_handedToDraft) {
      for (final face in [
        ..._currentFaces,
        for (final faces in _turnFaces.values) ...faces,
      ]) {
        unawaited(_deleteCapture(face.path));
      }
    }
    super.dispose();
  }

  Future<void> _deleteCapture(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Temporary image was already removed.
    }
  }

  Future<void> _captureFace() =>
      _faceCapture ??= _takeFace().whenComplete(() => _faceCapture = null);

  Future<void> _takeFace() async {
    final savedCount = _turnFaces.values.fold<int>(
      0,
      (total, faces) => total + faces.length,
    );
    if (!_recording || savedCount + _currentFaces.length >= 400) return;
    final photo = await _cameraKey.currentState?.takePicture();
    if (photo == null) return;
    if (!mounted || !_recording) {
      try {
        await File(photo.path).delete();
      } on FileSystemException {
        // Capture was already removed while leaving the screen.
      }
      return;
    }
    _currentFaces.add((
      path: photo.path,
      timeMs: _turnClock?.elapsedMilliseconds ?? 0,
    ));
  }

  /// 녹음 중 — 마이크 버튼으로 켜고 끈다.
  bool _recording = false;

  /// 녹음을 텍스트로 옮기는 중(STT 응답 대기).
  bool _transcribing = false;

  /// 통화 종료 처리 중(캡처·녹음 합치기) — 버튼을 다시 못 누르게 한다.
  bool _ending = false;

  /// 하단 버튼 줄의 양옆 칸 너비 — 통화 종료를 가운데에 두고, 오른쪽 칸에
  /// 차례 넘기기 글자 버튼이 나타났다 사라진다.
  static const double _sideSlotWidth = 120;

  @override
  void initState() {
    super.initState();
    _speech = MascotSpeech(ref.read(ttsServiceProvider));
    // 첫 인사는 대화 기록에 들어가야 서버가 무엇을 물었는지 안다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(diaryInterviewControllerProvider.notifier)
          .start(DiaryInterviewCopy.greeting);
    });
  }

  /// 말소리 판단 — 베이스라인 측정(`AmplitudePacedConversationController`)과
  /// 같은 문턱. record 패키지 dBFS는 대략 -160(무음)~0(최대).
  static const _voiceThreshold = -35.0;

  /// 말을 시작한 뒤 이만큼 조용하면 다 말한 것으로 보고 다음 질문을 받는다.
  /// 너무 짧으면 생각하며 쉬는 사이에 끊기고, 길면 다 말하고도 오래 기다린다
  /// (실기기에서 4초는 길었음 — 2026-10-18).
  static const _endOfTurnSilence = Duration(seconds: 2);

  /// 진폭은 약 300ms마다 온다 — 문턱을 이만큼 연달아 넘어야(약 0.6초) 말로 본다.
  static const _voiceFramesToStart = 2;

  StreamSubscription<double>? _voiceWatch;
  bool _heardVoice = false;
  int _voiceFrames = 0;
  DateTime? _silenceSince;

  /// 탄카츄가 말하는 중 — 이때는 듣지 않는다.
  bool _tankachuSpeaking = false;

  /// 차례를 넘기는 중 — 침묵 감지와 "다 말했어요"가 겹쳐 두 번 넘기지 않게.
  bool _submitting = false;

  /// 자동으로 듣기 시작하지 못했다(마이크 권한 등) — 이때만 "말하기" 버튼을
  /// 보여준다. 탄카츄 말이 끝나고 녹음이 켜지기까지의 짧은 틈에는 띄우지 않는다.
  bool _listenFailed = false;

  /// 탄카츄 말이 끝나면 자동으로 듣기 시작한다 — 마이크 버튼을 누를 필요가 없다.
  /// 마무리·위기 안내 뒤나 통화를 끝내는 중이면 듣지 않는다.
  Future<void> _listen() async {
    final interview = ref.read(diaryInterviewControllerProvider);
    if (!mounted ||
        _recording ||
        _transcribing ||
        _ending ||
        interview.waiting ||
        interview.done ||
        interview.crisis) {
      return;
    }
    await _startRecording();
    if (!mounted) return;
    setState(() => _listenFailed = !_recording);
    if (!_recording) return;
    _heardVoice = false;
    _voiceFrames = 0;
    _silenceSince = null;
    await _voiceWatch?.cancel();
    _voiceWatch = ref
        .read(audioRecorderProvider)
        .amplitudeStream()
        .listen(_onAmplitude);
  }

  /// 말을 시작하기 전에는 얼마든지 기다리고, 말한 뒤 [_endOfTurnSilence]만큼
  /// 조용하면 그 차례를 보낸다.
  void _onAmplitude(double db) {
    if (!_recording) return;
    if (db > _voiceThreshold) {
      // 숨소리·물건 소리처럼 한 번 튄 소리로는 말을 시작한 것으로 보지 않는다 —
      // 그러면 말하기 전에 차례가 넘어가 STT가 말소리를 못 찾는다(422).
      _voiceFrames++;
      if (_voiceFrames >= _voiceFramesToStart) _heardVoice = true;
      _silenceSince = null;
      return;
    }
    if (!_heardVoice) _voiceFrames = 0;
    if (!_heardVoice) return;
    _silenceSince ??= DateTime.now();
    if (DateTime.now().difference(_silenceSince!) >= _endOfTurnSilence) {
      unawaited(_submitTurn());
    }
  }

  /// 차례를 끝내고 다음 질문을 받는다 — 말이 멈췄을 때 자동으로, 또는
  /// "다 말했어요"를 눌렀을 때. 말을 옮기지 못했으면 다시 듣는다.
  Future<void> _submitTurn() async {
    if (_submitting || !_recording || _transcribing || _ending) return;
    _submitting = true;
    final ({String path, String text})? turn;
    try {
      await _voiceWatch?.cancel();
      _voiceWatch = null;
      turn = await _finishTurn();
    } finally {
      _submitting = false;
    }
    if (!mounted || _ending) return;
    if (turn == null) {
      await _listen();
      return;
    }
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
    _speech.stopMouthOnly();
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
    _currentFaces.clear();
    _turnClock = Stopwatch()..start();
    _faceTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _captureFace(),
    );
  }

  /// 녹음을 멈추고 원문으로 옮긴다. 옮기지 못하면 null — 그 차례는 버린다.
  Future<({String path, String text})?> _finishTurn() async {
    _faceTimer?.cancel();
    await _faceCapture;
    _turnClock?.stop();
    final path = await ref.read(audioRecorderProvider).stop();
    if (!mounted) return null;
    setState(() => _recording = false);
    if (path == null) {
      for (final face in _currentFaces) {
        try {
          await File(face.path).delete();
        } on FileSystemException {
          /* temporary image already gone */
        }
      }
      _currentFaces.clear();
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
      _turnFaces[path] = List.of(_currentFaces);
      _currentFaces.clear();
      return (path: path, text: text.trim());
    } on AppException catch (e) {
      // 서버가 재녹음 안내 문구를 내려준다 — 있으면 그대로 보여준다.
      _showMessage(e.message);
      return null;
    } catch (_) {
      _showMessage('음성을 옮기지 못했어요. 잠시 후 다시 시도해주세요.');
      return null;
    } finally {
      for (final face in _currentFaces) {
        try {
          await File(face.path).delete();
        } on FileSystemException {
          /* temporary image already gone */
        }
      }
      _currentFaces.clear();
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _endCall() async {
    if (_ending || _transcribing) return;
    setState(() => _ending = true);
    await _voiceWatch?.cancel();
    _voiceWatch = null;
    _speech.stopMouthOnly();
    await ref.read(ttsServiceProvider).stop();

    // 정지 이미지 캡처를 녹음 정지보다 먼저 — 녹음을 멈추는 사이 프레임이
    // 바뀌는 걸 방지(baseline 측정과 같은 순서).
    if (_recording) await _captureFace();
    final photo = _recording
        ? null
        : await _cameraKey.currentState?.takePicture();
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
    final facePaths = <String>[];
    final faceTimes = <int>[];
    var offsetMs = 0;
    for (final path in interview.recordingPaths) {
      for (final face
          in _turnFaces[path] ?? const <({String path, int timeMs})>[]) {
        facePaths.add(face.path);
        faceTimes.add(offsetMs + face.timeMs);
      }
      offsetMs += await WavMerger.durationMs(path);
    }
    draft
      ..setRecordingPath(recordingPath)
      ..setTranscript(interview.transcript)
      ..setInterviewMessages(interview.messages)
      ..setInterviewSlots(interview.slots);
    if (facePaths.isNotEmpty) {
      draft.setFaceTimeline(facePaths, faceTimes);
      if (photo != null) {
        try {
          await File(photo.path).delete();
        } on FileSystemException {
          /* temporary image already gone */
        }
      }
    } else if (photo != null) {
      draft.setFaceImagePath(photo.path);
    } else {
      draft.clearFace();
    }
    final summary = interview.summary;
    if (summary != null) draft.setSummary(summary);
    _handedToDraft = true;
    if (mounted) context.pushReplacementNamed(AppRoute.diaryStep1Processing);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  /// 탄카츄의 말을 읽고, 다 읽으면 바로 사용자의 말을 듣기 시작한다.
  Future<void> _say(String text, {required bool thenEnd}) async {
    if (mounted) setState(() => _tankachuSpeaking = true);
    if (!_recording) {
      await ref.read(ttsServiceProvider).speak(text);
    } else if (thenEnd) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;
    setState(() => _tankachuSpeaking = false);
    if (thenEnd) {
      await _endCall();
    } else {
      await _listen();
    }
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
      body: CallRoomBackground(
        startedAt: _startedAt,
        child: SafeArea(
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
                        '탄카츄 말이 끝나면 바로 말하면 돼요. 잠깐 조용하면 다음 질문으로 넘어가요.',
                        '빨리 넘기고 싶으면 다 말했어요를 눌러주세요.',
                        '탄카츄가 빠진 내용을 몇 가지 더 물어볼 수 있어요.',
                        '통화 종료를 누르면 대화가 끝나고 분석이 시작돼요.',
                      ],
                    ),
                  ),
                ],
              ),
              CallStatusRow(
                label: DiaryInterviewCopy.callStatus(
                  speaking: _tankachuSpeaking,
                  listenFailed: _listenFailed,
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
                    // 탄카츄 — 영상통화 상대처럼 상반신을 크게(입은 말풍선 바로 위).
                    Positioned.fill(
                      child: TankachuCallStage(
                        speech: _speech,
                        mood: _recording
                            ? TankachuMood.listening
                            : interview.waiting || _transcribing
                            ? TankachuMood.thinking
                            : TankachuMood.idle,
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
                    // 좌상단(음성 인식 중 칩 아래) — 답변마다 갱신되는 감정
                    // 인식 게이지와 감정 이름. 일기에 집중하도록 이것만 띄운다.
                    Positioned(
                      top: 44,
                      left: AppSpacing.screenH,
                      child: AnswerEmotionGauge(
                        records: interview.answerEmotions,
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
                            // 통화 종료는 가운데에 고정한다 — 옆 버튼이 나타났다
                            // 사라져도 움직이지 않아야 잘못 눌러 끊지 않는다.
                            const SizedBox(width: _sideSlotWidth),
                            const SizedBox(width: 20),
                            CallControlButton(
                              icon: Icons.call_end_rounded,
                              label: '통화 종료',
                              danger: true,
                              onTap: _ending || _transcribing ? null : _endCall,
                            ),
                            const SizedBox(width: 20),
                            // 마이크 버튼 대신 글자 버튼 — 음소거와 헷갈리지 않게.
                            // 듣는 중에는 빨리 넘기기, 자동으로 듣지 못했을 때만
                            // 다시 듣기를 보여준다.
                            SizedBox(
                              width: _sideSlotWidth,
                              child: Center(
                                child: _recording
                                    ? _TurnButton(
                                        label: '다 말했어요',
                                        onTap: _submitTurn,
                                      )
                                    : _listenFailed && !micLocked
                                    ? _TurnButton(
                                        label: '말하기',
                                        onTap: _listen,
                                      )
                                    : null,
                              ),
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
      ),
    );
  }
}

/// 차례 넘기기 글자 버튼 — 아이콘 버튼(통화 종료)과 모양을 달리해
/// 마이크 음소거로 오해하지 않게 한다.
class _TurnButton extends StatelessWidget {
  const _TurnButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: AppRadius.chip,
      child: InkWell(
        borderRadius: AppRadius.chip,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: AppTypography.bodySecondary.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
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
