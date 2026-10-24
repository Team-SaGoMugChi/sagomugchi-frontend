import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/media/audio_recorder_service.dart';
import '../../../../core/media/guided_conversation_controller.dart';
import '../../../../core/media/mascot_speech.dart';
import '../../../../core/media/tts_service.dart';
import '../../../../data/dummy/baseline_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/call_room_background.dart';
import '../../../../widgets/camera_self_view.dart';
import '../../../../widgets/speech_bubble.dart';
import '../../../../widgets/talking_tankachu.dart';
import '../../../../widgets/tankachu_call_stage.dart';
import '../../../../widgets/video_call_widgets.dart';
import '../../application/baseline_camera_guidance.dart';
import '../../application/baseline_face_frames_provider.dart';
import '../../application/baseline_face_image_provider.dart';
import '../../application/baseline_recording_provider.dart';
import '../../application/baseline_upload_controller.dart';

/// Screen 19 — 얼굴·음성 Baseline 측정 중. Video-call style: live front camera
/// + mic recording. Uploads only the files captured in this measurement.
class BaselineMeasuringScreen extends ConsumerStatefulWidget {
  const BaselineMeasuringScreen({super.key});

  @override
  ConsumerState<BaselineMeasuringScreen> createState() =>
      _BaselineMeasuringScreenState();
}

class _BaselineMeasuringScreenState
    extends ConsumerState<BaselineMeasuringScreen> {
  final _cameraKey = GlobalKey<CameraSelfViewState>();
  final _startedAt = DateTime.now();
  final _cameraHints = CameraHintStabilizer();
  CameraHint? _cameraHint;
  bool _checkingCamera = false;
  DateTime? _lastCameraCheck;
  bool _advanced = false;
  bool _aborted = false;
  bool _recording = false;
  ConversationTurn? _turn;
  Timer? _faceCaptureTimer;
  Future<void>? _faceCapture;
  Stopwatch? _recordingClock;

  int _sentenceIndex = 0;
  Completer<void>? _readDone;

  void _nextSentence() {
    if (_readDone?.isCompleted == false) _readDone!.complete();
  }

  /// 튜토리얼과 같은 통화 무대에서 탄카츄 입이 따라갈 문장.
  late final MascotSpeech _speech;

  @override
  void initState() {
    super.initState();
    _speech = MascotSpeech(ref.read(ttsServiceProvider));
    Future.microtask(() {
      if (!mounted) return;
      ref.read(baselineUploadControllerProvider.notifier).startMeasurement();
      _runGuideThenAdvance();
    });
  }

  Future<void> _runGuideThenAdvance() async {
    final recorder = ref.read(audioRecorderProvider);
    // 문장 읽기는 한 번의 연속 녹음으로 수집한다. 앱은 문장을 읽어주지 않는다.
    final started = await recorder.start(
      fileName: 'baseline_voice_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!mounted || _advanced) {
      await recorder.stop();
      return;
    }
    if (!started) {
      await _advance();
      return;
    }
    setState(() => _recording = true);
    _recordingClock = Stopwatch()..start();
    _faceCaptureTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lastCameraCheck != null &&
          DateTime.now().difference(_lastCameraCheck!) >
              const Duration(seconds: 6)) {
        _cameraHints.reset();
        if (mounted && _cameraHint != null) {
          setState(() => _cameraHint = null);
        }
      }
      _captureFace();
    });
    for (var i = 0; i < BaselineDummy.readingSentences.length; i++) {
      if (!mounted || _advanced) return;
      final done = Completer<void>();
      _readDone = done;
      setState(() {
        _sentenceIndex = i;
        _turn = ConversationTurn(
          caption: BaselineDummy.readingSentences[i],
          speaking: false,
        );
      });
      await done.future;
    }
    if (!mounted || _advanced) return;
    const closing = '감사합니다, 측정을 마칠게요.';
    setState(
      () => _turn = const ConversationTurn(caption: closing, speaking: true),
    );
    await _speakWithoutRecording(closing);
    if (!mounted || _advanced) return;
    setState(
      () => _turn = const ConversationTurn(caption: closing, speaking: false),
    );
    await _advance();
  }

  /// 앱 안내 음성이 사용자 음성 기준값에 섞이지 않게 녹음을 일시정지한다.
  /// 일시정지에 실패하면 음성 재생을 생략하고 화면의 안내 자막만 보여준다.
  Future<void> _speakWithoutRecording(String prompt) async {
    if (!mounted || _advanced) return;
    final recorder = ref.read(audioRecorderProvider);
    final paused = await recorder.pause();
    if (!paused) return;
    _recordingClock?.stop();
    try {
      if (mounted && !_advanced) {
        await ref.read(ttsServiceProvider).speak(prompt);
      }
    } finally {
      if (mounted && !_advanced) {
        final resumed = await recorder.resume();
        if (resumed) {
          _recordingClock?.start();
        } else {
          await _abortMeasurement();
        }
      }
    }
  }

  Future<void> _abortMeasurement() async {
    if (_advanced || !mounted) return;
    _aborted = true;
    setState(() {
      _advanced = true;
      _recording = false;
    });
    _nextSentence();
    _faceCaptureTimer?.cancel();
    _recordingClock?.stop();
    final images = ref.read(baselineFaceFramesProvider);
    final audio = await ref.read(audioRecorderProvider).stop();
    ref.read(baselineUploadControllerProvider.notifier).startMeasurement();
    for (final path in [...images, ?audio]) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // 임시 파일이 이미 정리된 경우.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('녹음을 다시 시작하지 못했어요. 측정을 다시 진행해주세요.')),
    );
    context.pushReplacementNamed(AppRoute.baselineReady);
  }

  @override
  void dispose() {
    // X 버튼 등으로 화면을 바로 나가면 _advance를 거치지 않으므로, 남아있는
    // 대화 대기 루프를 여기서 끊어준다.
    _nextSentence();
    _faceCaptureTimer?.cancel();
    _speech.dispose();
    super.dispose();
  }

  Future<void> _captureFace() => _faceCapture ??= _takeAndSaveFace()
      .whenComplete(() => _faceCapture = null);

  Future<void> _takeAndSaveFace() async {
    if (_turn?.speaking ?? false) return;
    if (ref.read(baselineFaceFramesProvider).length >=
        BaselineFaceFrames.maxFrameCount) {
      return;
    }
    final photo = await _cameraKey.currentState?.takePicture();
    if (photo == null) return;
    if (!mounted || _aborted) {
      try {
        await File(photo.path).delete();
      } on FileSystemException {
        // 임시 사진이 이미 정리된 경우.
      }
      return;
    }
    ref
        .read(baselineFaceFramesProvider.notifier)
        .add(
          photo.path,
          timestampMs: _recordingClock?.elapsedMilliseconds,
          promptSpeaking: _turn?.speaking ?? false,
        );
    ref.read(baselineFaceImageProvider.notifier).set(photo.path);
    if (!_advanced && !_checkingCamera) {
      unawaited(_checkCamera(photo.path));
    }
  }

  Future<void> _checkCamera(String path) async {
    _checkingCamera = true;
    try {
      final hint = await ref.read(baselineCameraGuidanceProvider).inspect(path);
      if (!mounted || _advanced) return;
      _lastCameraCheck = DateTime.now();
      setState(() => _cameraHint = _cameraHints.update(hint));
    } catch (_) {
      // 가이드 실패는 녹음/얼굴 수집/업로드를 막지 않는다.
      _cameraHints.reset();
      if (mounted && !_advanced) setState(() => _cameraHint = null);
    } finally {
      _checkingCamera = false;
    }
  }

  Future<void> _advance() async {
    if (_advanced || !mounted) return;
    setState(() {
      _advanced = true;
      _recording = false;
    });
    _nextSentence();
    _faceCaptureTimer?.cancel();
    await ref.read(ttsServiceProvider).stop();

    // 측정 중에는 1초마다 프레임을 수집하고 종료 직전에도 한 장을 촬영한다.
    final recorder = ref.read(audioRecorderProvider);
    await _captureFace();
    _recordingClock?.stop();
    final path = await recorder.stop();
    if (!mounted) return;

    if (path != null) {
      ref.read(baselineRecordingProvider.notifier).set(path);
    }
    if (mounted) context.pushReplacementNamed(AppRoute.baselineAnalyzing);
  }

  @override
  Widget build(BuildContext context) {
    // 화면이 살아있는 동안 녹음·TTS 서비스를 붙잡아 둔다.
    ref.watch(audioRecorderProvider);
    ref.watch(ttsServiceProvider);
    final listening = _recording && !_advanced && !(_turn?.speaking ?? true);
    final status = _advanced
        ? '측정을 마무리하고 있어요'
        : !_recording
        ? '통화를 준비하고 있어요'
        : listening
        ? '듣고 있어요 · 녹음 중'
        : '탄카츄가 안내하고 있어요';

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: CallRoomBackground(
        startedAt: _startedAt,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.lg,
                  AppSpacing.screenH,
                  AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    Text(
                      '탄카츄',
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.callTextPrimary,
                      ),
                    ),
                    Gap.h4,
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.callTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      Positioned.fill(
                        child: TankachuCallStage(
                          speech: _speech,
                          mood: listening
                              ? TankachuMood.listening
                              : TankachuMood.idle,
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.screenH,
                        child: Semantics(
                          label: '내 카메라',
                          child: CallUserPreview(cameraKey: _cameraKey),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.screenH,
                        right: AppSpacing.screenH,
                        bottom: AppSpacing.sm,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: box.maxHeight * 0.3,
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SpeechBubble(
                                      text: _advanced
                                          ? '고마워요. 읽어주신 목소리와 표정을 분석할게요.'
                                          : _turn?.caption ??
                                                '잠시만요, 녹음을 준비하고 있어요.',
                                    ),
                                    if (listening && _cameraHint != null) ...[
                                      Gap.h8,
                                      SpeechBubble(text: _cameraHint!.caption),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Gap.h20,
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.filled(
                                    tooltip: '다 읽었어요',
                                    onPressed: _recording && !_advanced
                                        ? _nextSentence
                                        : null,
                                    style: IconButton.styleFrom(
                                      fixedSize: const Size.square(
                                        AppSpacing.xxxl + AppSpacing.md,
                                      ),
                                      backgroundColor: AppColors.error,
                                      foregroundColor:
                                          AppColors.callTextPrimary,
                                      disabledBackgroundColor:
                                          AppColors.callSurface,
                                      disabledForegroundColor:
                                          AppColors.callTextSecondary,
                                    ),
                                    icon: _advanced
                                        ? const SizedBox.square(
                                            dimension: AppSpacing.xl,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.callTextPrimary,
                                            ),
                                          )
                                        : const Icon(Icons.check_rounded),
                                  ),
                                  Gap.h8,
                                  Text(
                                    _advanced
                                        ? '마무리 중'
                                        : '${_sentenceIndex + 1}/6 · 다 읽었어요',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.callTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
