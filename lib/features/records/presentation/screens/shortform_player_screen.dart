import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/mascot_image.dart';
import '../../application/viewing_date_provider.dart';

/// 플레이어로 넘기는 영상 — 자막(WebVTT)이 있으면 같이 넘긴다.
class ShortformVideo {
  const ShortformVideo({required this.videoUrl, this.subtitlesUrl});

  final String? videoUrl;
  final String? subtitlesUrl;
}

/// Auxiliary — 숏폼 전체화면 플레이어.
///
/// [videoUrl]이 있으면(Step3 완료 화면에서 방금 만든 영상) 재생한다. 화면을
/// 누르면 조작부(재생/일시정지·재생바·시간)가 나타나고, 재생 중에는
/// [controlsTimeout] 뒤 사라진다. 끝까지 보면 다시 보기 버튼이 남는다.
/// [videoUrl]이 없으면(그날 보관된 영상이 없을 때) 가짜 재생 화면 대신 볼 수 있는
/// 영상이 없다고 알린다. 지난 날짜 영상은 홈이 Firebase Storage 주소를 넘겨준다.
/// [subtitlesUrl]이 있으면 자막을 화면 아래에 띄우고, 위쪽 버튼으로 켜고 끈다
/// (영상에는 글자를 박지 않는다).
class ShortformPlayerScreen extends ConsumerStatefulWidget {
  const ShortformPlayerScreen({super.key, this.videoUrl, this.subtitlesUrl});

  final String? videoUrl;
  final String? subtitlesUrl;

  static const controlsTimeout = Duration(seconds: 3);

  @override
  ConsumerState<ShortformPlayerScreen> createState() =>
      _ShortformPlayerScreenState();
}

class _ShortformPlayerScreenState extends ConsumerState<ShortformPlayerScreen> {
  VideoPlayerController? _controller;
  bool _loadFailed = false;
  bool _controlsVisible = true;
  bool _captionsOn = true;
  Timer? _hideTimer;

  /// 재생바를 끄는 동안의 위치(0~1). 손을 뗄 때 그 위치로 이동한다.
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 실패 후 "다시 시도" — 이전 컨트롤러를 버리고 새로 불러온다.
  Future<void> _retry() async {
    final old = _controller;
    setState(() {
      _controller = null;
      _loadFailed = false;
    });
    old?.removeListener(_onTick);
    await old?.dispose();
    await _load();
  }

  Future<void> _load() async {
    final url = widget.videoUrl;
    if (url == null) return;
    final subtitles = widget.subtitlesUrl;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      closedCaptionFile: subtitles == null ? null : _loadCaptions(subtitles),
    );
    // initState에서도 불리므로 setState 없이 넣는다(첫 build가 곧 읽는다).
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
      await controller.play();
      _scheduleHide();
    } catch (_) {
      if (mounted && _controller == controller) {
        setState(() => _loadFailed = true);
      }
    }
  }

  /// 자막을 받지 못해도 영상은 그대로 재생한다(빈 자막).
  static Future<ClosedCaptionFile> _loadCaptions(String url) async {
    try {
      final response = await Dio().get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return WebVTTCaptionFile(response.data ?? 'WEBVTT');
    } on DioException {
      return WebVTTCaptionFile('WEBVTT');
    }
  }

  void _onTick() {
    if (!mounted) return;
    // 재생 중 오류(네트워크 끊김 등) — 로딩 표시만 계속 돌지 않게 다시 시도를 안내한다.
    if (_controller?.value.hasError ?? false) {
      if (!_loadFailed) setState(() => _loadFailed = true);
      return;
    }
    // 끝까지 보면 다시 보기 버튼을 계속 보여준다.
    if (_ended) {
      _hideTimer?.cancel();
      _controlsVisible = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller
      ?..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  bool get _ready =>
      !_loadFailed && (_controller?.value.isInitialized ?? false);

  bool get _playing => _controller?.value.isPlaying ?? false;

  bool get _ended {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return false;
    return !value.isPlaying &&
        value.duration > Duration.zero &&
        value.position >= value.duration;
  }

  double get _progress {
    final value = _controller!.value;
    final total = value.duration.inMilliseconds;
    if (total == 0) return 0;
    return (value.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(ShortformPlayerScreen.controlsTimeout, () {
      if (mounted && _playing && _dragValue == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible && _playing) _scheduleHide();
  }

  void _togglePlay() {
    final controller = _controller;
    if (!_ready || controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
      return;
    }
    if (_ended) controller.seekTo(Duration.zero);
    controller.play();
    _scheduleHide();
  }

  void _seekTo(double fraction) {
    final controller = _controller!;
    final total = controller.value.duration.inMilliseconds;
    controller.seekTo(Duration(milliseconds: (total * fraction).round()));
  }

  static String _format(Duration d) {
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(viewingDateProvider);
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else
            _status(),
          if (_ready && _captionsOn) _caption(),
          if (_ready)
            IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: _controls(),
              ),
            ),
          // 뒤로가기·제목은 상태와 상관없이 항상 누를 수 있어야 한다.
          AnimatedOpacity(
            opacity: !_ready || _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: _TopBar(
              title: '${DateFormatter.monthDay(date)}의 이야기',
              captionsOn: widget.subtitlesUrl == null ? null : _captionsOn,
              onToggleCaptions: () =>
                  setState(() => _captionsOn = !_captionsOn),
            ),
          ),
        ],
      ),
    );
  }

  /// 지금 시각의 자막 한 줄. 조작부(재생바) 위에 띄워 가리지 않게 한다.
  Widget _caption() {
    final text = _controller!.value.caption.text;
    if (text.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: AppSpacing.screenH,
      right: AppSpacing.screenH,
      bottom: _captionBottom,
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.overlayDim,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.callTextPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 재생바·시간 표시가 차지하는 높이만큼 자막을 띄운다.
  static const double _captionBottom = 120;

  /// 영상이 없거나·불러오는 중이거나·실패했을 때.
  Widget _status() {
    if (widget.videoUrl == null) {
      return const _StatusMessage(
        title: '아직 볼 수 있는 영상이 없어요',
        body: '이 날은 저장된 영상이 없어요.',
      );
    }
    if (_loadFailed) {
      return _StatusMessage(
        title: '영상을 불러오지 못했어요',
        body: '네트워크를 확인하고 다시 시도해주세요.',
        action: TextButton(onPressed: _retry, child: const Text('다시 시도')),
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _controls() {
    final value = _controller!.value;
    final progress = _dragValue ?? _progress;
    final shown = _dragValue == null
        ? value.position
        : value.duration * _dragValue!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 조작부가 영상 위에서도 읽히도록 위·아래를 어둡게 한다.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.overlayDim,
                  Colors.transparent,
                  Colors.transparent,
                  AppColors.overlayDim,
                ],
                stops: [0, 0.18, 0.72, 1],
              ),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
        ),
        Center(
          child: IconButton(
            iconSize: 64,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.overlayDim,
              foregroundColor: AppColors.callTextPrimary,
            ),
            tooltip: _ended ? '다시 보기' : (_playing ? '일시정지' : '재생'),
            onPressed: _togglePlay,
            icon: Icon(
              _ended
                  ? Icons.replay_rounded
                  : (_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.callSurface,
                      thumbColor: AppColors.callTextPrimary,
                      overlayColor: AppColors.overlayDim,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                    ),
                    child: Slider(
                      value: progress,
                      onChangeStart: (v) {
                        _hideTimer?.cancel();
                        setState(() => _dragValue = v);
                      },
                      onChanged: (v) => setState(() => _dragValue = v),
                      onChangeEnd: (v) {
                        _seekTo(v);
                        setState(() => _dragValue = null);
                        if (_playing) _scheduleHide();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _format(shown),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.callTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _format(value.duration),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.callTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.captionsOn, this.onToggleCaptions});

  final String title;

  /// 자막이 없으면 null — 버튼을 숨긴다.
  final bool? captionsOn;
  final VoidCallback? onToggleCaptions;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              tooltip: '뒤로',
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
                title,
                textAlign: TextAlign.center,
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.callTextPrimary,
                ),
              ),
            ),
            if (captionsOn == null)
              const SizedBox(width: 48)
            else
              IconButton(
                tooltip: captionsOn! ? '자막 끄기' : '자막 켜기',
                icon: Icon(
                  captionsOn!
                      ? Icons.closed_caption_rounded
                      : Icons.closed_caption_off_outlined,
                  color: AppColors.callTextPrimary,
                ),
                onPressed: onToggleCaptions,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.title, required this.body, this.action});

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotImage(pose: MascotPose.front, size: 160, onDark: true),
            Gap.h16,
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.subtitle.copyWith(
                color: AppColors.callTextPrimary,
              ),
            ),
            Gap.h8,
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.callTextSecondary,
              ),
            ),
            if (action != null) ...[Gap.h12, action!],
          ],
        ),
      ),
    );
  }
}
