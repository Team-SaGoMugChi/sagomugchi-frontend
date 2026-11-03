import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../theme/app_colors.dart';

/// Fixed frontal composition: the character accompanies reading, without
/// taking scroll gestures or rotating away from the user. The poster is a
/// studio render of the same model, used during loading and on failure.
class BaselineCompanion extends StatefulWidget {
  const BaselineCompanion({
    super.key,
    this.ready = false,
    this.welcome = false,
  });
  final bool ready;
  final bool welcome;

  @override
  State<BaselineCompanion> createState() => _BaselineCompanionState();
}

class _BaselineCompanionState extends State<BaselineCompanion>
    with WidgetsBindingObserver {
  Timer? _timeout;
  bool _loaded = false;
  bool _failed = false;
  bool _active = true;
  Future<void> Function(String)? _runScript;

  bool get _native => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  String get _clip => widget.ready
      ? 'Ready'
      : widget.welcome
      ? 'Welcome'
      : 'Listen';
  String get _portrait => widget.ready
      ? 'ready'
      : widget.welcome
      ? 'welcome'
      : 'listening';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_native) {
      _timeout = Timer(const Duration(seconds: 20), () {
        if (mounted && !_loaded) setState(() => _failed = true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_syncMotion());
  }

  @override
  void didUpdateWidget(covariant BaselineCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready ||
        oldWidget.welcome != widget.welcome) {
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
        (() => {
          const m = document.querySelector('model-viewer');
          if (!m) return;
          m.animationName = '$_clip';
          ${animate ? (widget.ready ? 'm.play({repetitions: 1});' : 'm.play();') : 'm.pause();'}
        })();
      ''');
    } catch (_) {
      // A disappearing WebView must never block the preparation controls.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: widget.ready ? '고개를 끄덕이며 준비를 함께하는 오또' : '편안하게 기다리는 오또',
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/oddo_guide_$_portrait.png',
              fit: BoxFit.contain,
            ),
            if (_native && !_failed)
              AnimatedOpacity(
                opacity: _loaded ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                child: ModelViewer(
                  src: AppAssets.mascotModel,
                  alt: '오또',
                  backgroundColor: AppColors.background,
                  animationName: _clip,
                  innerModelViewerHtml:
                      '<div slot="progress-bar" style="display:none"></div>',
                  relatedCss: '''
                    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
                    ::-webkit-scrollbar { display: none; width: 0; height: 0; }
                    model-viewer { width: 100%; height: 100%; --progress-bar-color: transparent; }
                  ''',
                  autoPlay:
                      _active &&
                      TickerMode.valuesOf(context).enabled &&
                      !MediaQuery.disableAnimationsOf(context),
                  autoRotate: false,
                  cameraControls: false,
                  disableZoom: true,
                  interactionPrompt: InteractionPrompt.none,
                  cameraOrbit: '0deg 85deg 2.5m',
                  cameraTarget: '0m 0.48m 0m',
                  fieldOfView: '28deg',
                  shadowIntensity: 0.5,
                  onWebViewCreated: (controller) =>
                      _runScript = controller.runJavaScript,
                  relatedJs: '''
                  const model = document.querySelector('model-viewer');
                  model.addEventListener('load', () => OddoGuide.postMessage('loaded'));
                  model.addEventListener('error', () => OddoGuide.postMessage('error'));
                  if (model.loaded) OddoGuide.postMessage('loaded');
                ''',
                  javascriptChannels: {
                    JavascriptChannel(
                      'OddoGuide',
                      onMessageReceived: (message) {
                        if (!mounted) return;
                        _timeout?.cancel();
                        setState(() {
                          _loaded = message.message == 'loaded';
                          _failed = !_loaded;
                        });
                        if (_loaded) unawaited(_syncMotion());
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
