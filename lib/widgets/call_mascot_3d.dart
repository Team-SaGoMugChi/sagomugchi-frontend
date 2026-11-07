import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../core/constants/app_assets.dart';
import '../core/media/call_lip_track.dart';
import '../core/media/tts_service.dart';
import 'call_face_driver.dart';
import 'talking_tankachu.dart' show TankachuMood;

/// Fixed frontal composition: the character accompanies reading, without
/// taking scroll gestures or rotating away from the user. The poster is a
/// studio render of the same model, used only on failure or unsupported hosts.
class CallMascot3d extends StatefulWidget {
  const CallMascot3d({
    super.key,
    required this.speech,
    this.mood = TankachuMood.idle,
    this.reaction = 0,
    this.onReady,
  });
  final ValueListenable<TtsUtterance?> speech;
  final TankachuMood mood;
  final int reaction;
  final VoidCallback? onReady;

  @override
  State<CallMascot3d> createState() => _CallMascot3dState();
}

class _CallMascot3dState extends State<CallMascot3d>
    with WidgetsBindingObserver {
  Timer? _timeout;
  bool _loaded = false;
  bool _failed = false;
  bool _active = true;
  bool _faceReady = false;
  bool _readyNotified = false;
  int? _sentSerial;
  String? _sentText;
  CallLipTrack? _lipTrack;
  int _speechRevision = 0;
  Future<void> Function(String)? _runScript;

  bool get _native => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool _acknowledging = false;
  bool get _speaking =>
      widget.speech.value != null && widget.speech.value!.serial >= 0;
  String get _clip => _speaking
      ? 'CallSpeak'
      : _acknowledging
      ? 'CallAck'
      : widget.mood == TankachuMood.idle
      ? 'CallWait'
      : 'CallListen';
  String get _portrait => 'listening';
  bool? _lastSpeaking;
  void _notifyReady() {
    if (!mounted || _readyNotified) return;
    _readyNotified = true;
    widget.onReady?.call();
  }

  void _speechChanged() {
    final speaking = _speaking;
    if (_lastSpeaking != speaking) {
      _lastSpeaking = speaking;
      if (speaking) _acknowledging = false;
      unawaited(_syncMotion());
    }
    unawaited(_syncSpeech());
  }

  Future<void> _syncSpeech({bool force = false}) async {
    if (!_loaded || !_faceReady || _runScript == null) return;
    final revision = ++_speechRevision;
    final speech = _speaking ? widget.speech.value : null;
    Object? packet;
    if (speech != null) {
      final fresh =
          force || _sentSerial != speech.serial || _sentText != speech.text;
      if (_lipTrack?.lip.text != speech.text) {
        _lipTrack = CallLipTrack(speech.text);
      }
      packet = {
        'serial': speech.serial,
        'rate': speech.syllablesPerSecond,
        'beat': speech.charIndex == null
            ? null
            : _lipTrack!.lip.beatAtChar(speech.charIndex!),
        if (fresh) 'track': _lipTrack!.toJson(),
      };
    }
    try {
      await _runScript!.call('window.oddoFace?.speech(${jsonEncode(packet)});');
      if (revision == _speechRevision) {
        _sentSerial = speech?.serial;
        _sentText = speech?.text;
      }
    } catch (_) {
      // Losing the WebView must not affect speech or measurement controls.
    }
  }

  @override
  void initState() {
    super.initState();
    widget.speech.addListener(_speechChanged);
    WidgetsBinding.instance.addObserver(this);
    if (_native) {
      _timeout = Timer(const Duration(seconds: 20), () {
        if (mounted && !_loaded) {
          setState(() => _failed = true);
          _notifyReady();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyReady());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_syncMotion());
  }

  @override
  void didUpdateWidget(covariant CallMascot3d oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reaction != widget.reaction &&
        widget.mood == TankachuMood.listening &&
        !_speaking) {
      _acknowledging = true;
    } else if (oldWidget.mood != widget.mood || _speaking) {
      _acknowledging = false;
    }
    if (oldWidget.speech != widget.speech) {
      oldWidget.speech.removeListener(_speechChanged);
      widget.speech.addListener(_speechChanged);
      _lastSpeaking = null;
      _sentSerial = null;
      _sentText = null;
      unawaited(_syncSpeech(force: true));
    }
    if (oldWidget.speech != widget.speech ||
        oldWidget.mood != widget.mood ||
        oldWidget.reaction != widget.reaction) {
      unawaited(_syncMotion());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    unawaited(_syncMotion());
  }

  Future<void> _syncMotion() async {
    if (!mounted) return;
    final animate =
        _active &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    try {
      await _runScript?.call('''
        (async () => {
          const m = document.querySelector('model-viewer');
          if (!m || !m.loaded) return;
          window.oddoFace?.setActive($animate);
          const revision = (window.oddoMotionRevision || 0) + 1;
          window.oddoMotionRevision = revision;
          m.animationCrossfadeDuration = 300;
          if (m.animationName !== '$_clip') {
            m.pause();
            m.animationName = '$_clip';
            await m.updateComplete;
            if (revision !== window.oddoMotionRevision) return;
            m.currentTime = 0;
          }
          ${animate ? (_acknowledging ? 'm.play({repetitions: 1});' : 'm.play();') : 'm.pause();'}
        })();
      ''');
    } catch (_) {
      // A disappearing WebView must never block the preparation controls.
    }
  }

  @override
  void dispose() {
    widget.speech.removeListener(_speechChanged);
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    unawaited(_disposeFace());
    super.dispose();
  }

  Future<void> _disposeFace() async {
    try {
      await _runScript?.call('window.oddoFace?.dispose();');
    } catch (_) {
      // The platform may already have removed the WebView.
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '대화하는 3D 오또',
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_failed || !_native)
              Image.asset(
                'assets/images/oddo_guide_$_portrait.png',
                fit: BoxFit.contain,
              ),
            if (_native && !_failed)
              AnimatedOpacity(
                opacity: _loaded ? 1 : 0,
                onEnd: _notifyReady,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 550),
                child: ModelViewer(
                  src: AppAssets.callMascotModel,
                  alt: '오또',
                  backgroundColor: Colors.transparent,
                  animationName: _clip,
                  innerModelViewerHtml:
                      '<div slot="progress-bar" style="display:none"></div>',
                  relatedCss: '''
                    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
                    ::-webkit-scrollbar { display: none; width: 0; height: 0; }
                    model-viewer { width: 100%; height: 100%; --progress-bar-color: transparent; }
                  ''',
                  // Start only after load and state selection; autoplay would
                  // restart one-shot reactions as a loop when clips change.
                  autoPlay: false,
                  autoRotate: false,
                  cameraControls: false,
                  disableZoom: true,
                  interactionPrompt: InteractionPrompt.none,
                  cameraOrbit: '0deg 85deg 2.25m',
                  cameraTarget: '0m 0.56m 0m',
                  fieldOfView: '28deg',
                  shadowIntensity: 0.5,
                  onWebViewCreated: (controller) =>
                      _runScript = controller.runJavaScript,
                  relatedJs:
                      '''
                  $callFaceDriver
                  const model = document.querySelector('model-viewer');
                  function ready() {
                    window.installOddoFace(model, message => OddoCall.postMessage(message));
                    requestAnimationFrame(() => requestAnimationFrame(() => OddoCall.postMessage('loaded')));
                  }
                  model.addEventListener('load', ready);
                  model.addEventListener('error', () => OddoCall.postMessage('error'));
                  model.addEventListener('finished', () => {
                    if (model.animationName === 'CallAck') OddoCall.postMessage('acknowledged');
                  });
                  if (model.loaded) ready();
                ''',
                  javascriptChannels: {
                    JavascriptChannel(
                      'OddoCall',
                      onMessageReceived: (message) {
                        if (!mounted) return;
                        if (message.message == 'face-ready' ||
                            message.message == 'face-unavailable') {
                          _faceReady = message.message == 'face-ready';
                          if (_faceReady) unawaited(_syncSpeech(force: true));
                          return;
                        }
                        if (message.message == 'acknowledged') {
                          _acknowledging = false;
                          unawaited(_syncMotion());
                          return;
                        }
                        _timeout?.cancel();
                        setState(() {
                          _loaded = message.message == 'loaded';
                          _failed = !_loaded;
                        });
                        if (_loaded) {
                          unawaited(_syncMotion());
                          unawaited(_syncSpeech(force: true));
                          if (MediaQuery.disableAnimationsOf(context)) {
                            _notifyReady();
                          }
                        } else {
                          _notifyReady();
                        }
                      },
                    ),
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
