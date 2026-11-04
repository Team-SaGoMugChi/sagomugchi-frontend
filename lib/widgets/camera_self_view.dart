import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Live front-camera self view for the video-call style screens.
///
/// Handles the whole camera lifecycle and degrades gracefully: while
/// initializing, without permission, or on devices/tests without a camera it
/// shows [fallback] (defaults to the person-icon placeholder look).
class CameraSelfView extends StatefulWidget {
  const CameraSelfView({super.key, this.fallback});

  /// Shown when the preview isn't available. Defaults to a person icon on the
  /// call-surface color.
  final Widget? fallback;

  @override
  State<CameraSelfView> createState() => CameraSelfViewState();
}

/// Public so callers can grab a still frame via a `GlobalKey<CameraSelfViewState>`
/// (e.g. baseline 측정 종료 시 얼굴 사진 한 장 캡처).
class CameraSelfViewState extends State<CameraSelfView>
    with WidgetsBindingObserver {
  CameraController? _controller;

  /// 현재 프리뷰에서 정지 이미지 한 장을 캡처한다. 카메라가 준비되지 않았으면 null.
  Future<XFile?> takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    if (controller.value.isTakingPicture) return null;
    try {
      return await controller.takePicture();
    } catch (_) {
      return null;
    }
  }

  /// 카메라를 켤 때마다 1씩 오른다. 켜는 도중 화면을 나가거나 앱이 잠깐 비활성이 되면 숫자가 바뀌어,
  /// 늦게 끝난 초기화는 그 카메라를 바로 끈다. 예전에는 켜는 도중에 또 켜서 카메라를 여러 번 열었고,
  /// 끈 카메라를 플러그인이 계속 준비하다 오류가 나며 앱이 멈췄다(2026-11 에뮬레이터, ANR).
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final generation = ++_generation;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty || generation != _generation) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false, // 녹음은 AudioRecorderService가 담당.
      );
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      // No camera / no permission / test environment → keep the fallback.
    }
  }

  /// 켜져 있는 카메라를 끄고, 켜는 중인 초기화도 무효로 만든다.
  void _release() {
    _generation++;
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera in background; re-init on resume (plugin guidance).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_controller != null && mounted) setState(_release);
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return widget.fallback ??
          Container(
            color: AppColors.callSurface,
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_rounded,
              size: 34,
              color: AppColors.callTextSecondary,
            ),
          );
    }
    // Cover-fit the preview into whatever box the parent gives us.
    return LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? constraints.maxWidth,
            height:
                controller.value.previewSize?.width ?? constraints.maxHeight,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
