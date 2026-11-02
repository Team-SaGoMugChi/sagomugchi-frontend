import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/storage/local_store.dart';
import '../../../../features/auth/application/auth_controller.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/primary_button.dart';

/// 첫 실행 소개: 3D 탄카츄가 나오는 27초 브랜드 영상 → 시작하기.
///
/// - 로그인 전에도 열린다(splash가 처음 설치한 기기를 여기로 보낸다).
/// - 영상은 화면을 꽉 채운다(BoxFit.cover). 기기 비율에 따라 좌우가 조금
///   잘리므로 영상 속 글자·카드는 가운데 안전 영역 안에 배치해 렌더했다.
/// - 조작 바는 평소 숨겨 두고, 화면을 탭하면 즉시 멈추고 바를 보여 준다.
///   바에서 재생/멈춤 · 진행 막대 드래그 탐색 · 소리 크기를 조절한다.
/// - 끝까지 보거나 건너뛰면 기기에 '봤음'을 기록하고, 마지막 장면(오또 로고)
///   위에 시작 버튼을 띄운다. 영상 하단 27%는 버튼 자리로 비어 있다.
/// - 영상을 열 수 없는 환경(테스트, 코덱 오류)에서는 마지막 장면 이미지와
///   버튼만 보여 주므로 다음 단계로 막힘 없이 넘어갈 수 있다.
class AppIntroductionScreen extends ConsumerStatefulWidget {
  const AppIntroductionScreen({super.key});

  @override
  ConsumerState<AppIntroductionScreen> createState() =>
      _AppIntroductionScreenState();
}

class _AppIntroductionScreenState extends ConsumerState<AppIntroductionScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _ended = false;
  bool _controlsVisible = false;
  double _volume = 1;
  double _volumeBeforeMute = 1;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.asset(
      AppAssets.introFilm,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      if (!mounted) {
        unawaited(_safeDispose(controller));
        return;
      }
      controller.addListener(_onTick);
      _controller = controller;
      setState(() => _ready = true);
      await controller.play();
    } catch (_) {
      unawaited(_safeDispose(controller));
      if (mounted) _finish();
    }
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized || _ended) return;
    final remaining = value.duration - value.position;
    if (!value.isPlaying && remaining < const Duration(milliseconds: 150)) {
      _finish();
    }
  }

  /// 끝까지 봤거나 건너뜀 → 로고 장면에서 멈추고 버튼을 띄운다.
  void _finish() {
    if (_ended) return;
    _hideTimer?.cancel();
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.pause());
      unawaited(
        controller.seekTo(
          controller.value.duration - const Duration(milliseconds: 40),
        ),
      );
    }
    setState(() {
      _ended = true;
      _controlsVisible = false;
    });
    unawaited(_markSeen());
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _ended = false);
    await controller.seekTo(Duration.zero);
    await controller.play();
  }

  /// 화면 탭: 재생 중이면 즉시 멈추고 조작 바를 보여 준다.
  /// 멈춘 상태에서 다시 탭하면 이어서 재생하고 바를 숨긴다.
  void _onScreenTap() {
    final controller = _controller;
    if (controller == null || _ended) return;
    _hideTimer?.cancel();
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
      setState(() => _controlsVisible = true);
    } else {
      unawaited(controller.play());
      setState(() => _controlsVisible = false);
    }
  }

  /// 조작 바의 재생/멈춤 버튼. 재생을 누르면 잠시 뒤 바가 사라진다.
  void _togglePlay() {
    final controller = _controller;
    if (controller == null || _ended) return;
    _hideTimer?.cancel();
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
    } else {
      unawaited(controller.play());
      _hideTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
    setState(() {});
  }

  void _seekTo(double fraction) {
    final controller = _controller;
    if (controller == null) return;
    final total = controller.value.duration.inMilliseconds;
    unawaited(
      controller.seekTo(Duration(milliseconds: (total * fraction).round())),
    );
  }

  void _setVolume(double value) {
    final controller = _controller;
    setState(() => _volume = value);
    if (controller != null) unawaited(controller.setVolume(value));
  }

  void _toggleMute() {
    if (_volume > 0) {
      _volumeBeforeMute = _volume;
      _setVolume(0);
    } else {
      _setVolume(_volumeBeforeMute == 0 ? 1 : _volumeBeforeMute);
    }
  }

  Future<void> _markSeen() async {
    try {
      await ref
          .read(localStoreProvider)
          .setBool(LocalStore.kIntroFilmSeen, true);
    } catch (_) {
      // 기록 실패는 다음 실행에 영상을 한 번 더 보여 줄 뿐이다.
    }
  }

  Future<void> _start() async {
    await _markSeen();
    if (!mounted) return;
    final loggedIn = ref.read(authControllerProvider).isLoggedIn;
    if (loggedIn) {
      context.pushReplacementNamed(AppRoute.personaIntro);
    } else {
      context.goNamed(AppRoute.signup);
    }
  }

  Future<void> _haveAccount() async {
    await _markSeen();
    if (mounted) context.goNamed(AppRoute.login);
  }

  static Future<void> _safeDispose(VideoPlayerController c) async {
    try {
      await c.dispose();
    } catch (_) {
      // 초기화에 실패한 컨트롤러는 정리 중에도 예외가 날 수 있어 무시한다.
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onTick);
      unawaited(_safeDispose(controller));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final loggedIn = ref.watch(authControllerProvider).isLoggedIn;
    final showFilm = _ready && controller != null;
    final showControls = showFilm && _controlsVisible && !_ended;
    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 영상 — 화면을 꽉 채운다(위아래 여백 없음).
          Semantics(
            label:
                '오또 소개 영상. 탄카츄와 3분 대화하면 목소리, 표정, 말을 '
                '평소와 비교해 감정을 읽고, 하루를 짧은 영상과 리포트로 남겨요. '
                '화면을 누르면 멈추고 조작 버튼이 나타나요.',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onScreenTap,
              child: ClipRect(
                child: showFilm
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      )
                    : (_ended
                          ? Image.asset(
                              AppAssets.introFilmEndCard,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(),
                            )
                          : const SizedBox()),
              ),
            ),
          ),
          // 멈췄을 때 화면을 살짝 어둡게 해 조작 중임을 보여 준다.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: showControls ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: ColoredBox(
                color: AppColors.textStrong.withValues(alpha: .18),
              ),
            ),
          ),
          // 상단 오른쪽: 건너뛰기는 항상 보인다.
          Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  0,
                ),
                child: AnimatedOpacity(
                  opacity: _ended ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: _ended ? null : _finish,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surface.withValues(alpha: .85),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('건너뛰기'),
                  ),
                ),
              ),
            ),
          ),
          // 하단: 탭했을 때만 나타나는 조작 바
          if (showFilm)
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                offset: showControls ? Offset.zero : const Offset(0, .3),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          0,
                          AppSpacing.screenH,
                          AppSpacing.sm,
                        ),
                        child: _FilmControls(
                          controller: controller,
                          volume: _volume,
                          onTogglePlay: _togglePlay,
                          onSeek: _seekTo,
                          onVolume: _setVolume,
                          onToggleMute: _toggleMute,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 하단: 끝나면 시작 버튼(로고 장면의 비어 있는 하단 영역)
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: _ended ? Offset.zero : const Offset(0, .4),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _ended ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_ended,
                  child: _StartPanel(
                    loggedIn: loggedIn,
                    canReplay: showFilm,
                    onStart: _start,
                    onHaveAccount: _haveAccount,
                    onReplay: _replay,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 영상 하단 조작 바: 재생/멈춤 · 진행 막대(드래그 탐색) · 시간 · 소리 크기.
class _FilmControls extends StatefulWidget {
  const _FilmControls({
    required this.controller,
    required this.volume,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onVolume,
    required this.onToggleMute,
  });

  final VideoPlayerController controller;
  final double volume;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onVolume;
  final VoidCallback onToggleMute;

  @override
  State<_FilmControls> createState() => _FilmControlsState();
}

class _FilmControlsState extends State<_FilmControls> {
  /// 드래그하는 동안의 위치(0~1). 드래그 중에는 재생 위치 대신 이 값을 그린다.
  double? _dragging;

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: widget.controller,
        builder: (context, v, _) {
          final total = v.duration.inMilliseconds;
          final played = total == 0 ? 0.0 : v.position.inMilliseconds / total;
          final value = (_dragging ?? played).clamp(0.0, 1.0);
          final theme = SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primarySoftBorder,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: .12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: .94),
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.primarySoftBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxs,
                AppSpacing.xxs,
                AppSpacing.sm,
                AppSpacing.xxs,
              ),
              child: SliderTheme(
                data: theme,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1줄: 재생/멈춤 · 진행 막대 · 시간
                    Row(
                      children: [
                        IconButton(
                          tooltip: v.isPlaying ? '일시정지' : '재생',
                          onPressed: widget.onTogglePlay,
                          icon: Icon(
                            v.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppColors.primary,
                            size: 30,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: value,
                            semanticFormatterCallback: (_) =>
                                '${_clock(v.position)} / ${_clock(v.duration)}',
                            onChangeStart: (x) => setState(() => _dragging = x),
                            onChanged: (x) {
                              setState(() => _dragging = x);
                              widget.onSeek(x);
                            },
                            onChangeEnd: (x) {
                              widget.onSeek(x);
                              setState(() => _dragging = null);
                            },
                          ),
                        ),
                        Text(
                          '${_clock(Duration(milliseconds: (value * total).round()))}'
                          ' / ${_clock(v.duration)}',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                    // 2줄: 소리 끄기/켜기 · 소리 크기
                    Row(
                      children: [
                        IconButton(
                          tooltip: widget.volume == 0 ? '소리 켜기' : '소리 끄기',
                          onPressed: widget.onToggleMute,
                          icon: Icon(
                            widget.volume == 0
                                ? Icons.volume_off_rounded
                                : (widget.volume < .5
                                      ? Icons.volume_down_rounded
                                      : Icons.volume_up_rounded),
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: widget.volume,
                            semanticFormatterCallback: (x) =>
                                '소리 ${(x * 100).round()}%',
                            onChanged: widget.onVolume,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.loggedIn,
    required this.canReplay,
    required this.onStart,
    required this.onHaveAccount,
    required this.onReplay,
  });

  final bool loggedIn;
  final bool canReplay;
  final VoidCallback onStart;
  final VoidCallback onHaveAccount;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.authBackground.withValues(alpha: 0),
          AppColors.authBackground,
        ],
        stops: const [0, .35],
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.xxxl,
          AppSpacing.screenH,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(label: '시작하기', onPressed: onStart),
            if (!loggedIn) ...[
              Gap.h8,
              SecondaryButton(label: '이미 계정이 있어요', onPressed: onHaveAccount),
            ],
            if (canReplay)
              TextButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('다시 보기', style: AppTypography.caption),
              ),
          ],
        ),
      ),
    ),
  );
}
