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
/// - 끝까지 보거나 건너뛰면 기기에 '봤음'을 기록하고, 영상의 마지막 장면
///   (오또 로고) 위에 시작 버튼을 띄운다. 영상 하단 27%는 버튼 자리로 비어 있다.
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
  bool _muted = false;

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
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.pause());
      unawaited(
        controller.seekTo(
          controller.value.duration - const Duration(milliseconds: 40),
        ),
      );
    }
    setState(() => _ended = true);
    unawaited(_markSeen());
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _ended = false);
    await controller.seekTo(Duration.zero);
    await controller.play();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || _ended) return;
    unawaited(
      controller.value.isPlaying ? controller.pause() : controller.play(),
    );
    setState(() {});
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    final controller = _controller;
    if (controller != null) unawaited(controller.setVolume(_muted ? 0 : 1));
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
    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 영상(9:16) — 세로가 더 긴 기기에서는 위아래가 아이보리로 이어진다.
          Semantics(
            label:
                '오또 소개 영상. 탄카츄와 3분 대화하면 목소리, 표정, 말을 '
                '평소와 비교해 감정을 읽고, 하루를 짧은 영상과 리포트로 남겨요.',
            child: GestureDetector(
              onTap: _togglePlay,
              child: ColoredBox(
                color: AppColors.authBackground,
                child: showFilm
                    ? FittedBox(
                        child: SizedBox(
                          width: controller.value.size.width,
                          height: controller.value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      )
                    : (_ended
                          ? Image.asset(
                              AppAssets.introFilmEndCard,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const SizedBox(),
                            )
                          : const SizedBox()),
              ),
            ),
          ),
          if (showFilm && !controller.value.isPlaying && !_ended)
            const Center(child: _PlayBadge()),
          // 상단 오른쪽: 건너뛰기만 둔다(영상 내용을 가리지 않게).
          Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, AppSpacing.sm, 0),
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
          // 하단: 재생/멈춤 · 진행 막대 · 소리 (영상이 끝나면 시작 버튼으로 교체)
          if (showFilm)
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: _ended ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: _ended,
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
                        muted: _muted,
                        onTogglePlay: _togglePlay,
                        onToggleMute: _toggleMute,
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

/// 영상 하단 조작 바: 재생/멈춤 · 진행 막대 · 소리.
class _FilmControls extends StatelessWidget {
  const _FilmControls({
    required this.controller,
    required this.muted,
    required this.onTogglePlay,
    required this.onToggleMute,
  });

  final VideoPlayerController controller;
  final bool muted;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (_, v, _) {
          final total = v.duration.inMilliseconds;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: .88),
              borderRadius: AppRadius.chip,
              border: Border.all(color: AppColors.primarySoftBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: Row(
                children: [
                  IconButton(
                    tooltip: v.isPlaying ? '일시정지' : '재생',
                    onPressed: onTogglePlay,
                    icon: Icon(
                      v.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: _FilmProgress(
                      value: total == 0
                          ? 0
                          : v.position.inMilliseconds / total,
                    ),
                  ),
                  IconButton(
                    tooltip: muted ? '소리 켜기' : '소리 끄기',
                    onPressed: onToggleMute,
                    icon: Icon(
                      muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _FilmProgress extends StatelessWidget {
  const _FilmProgress({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: AppRadius.chip,
    child: LinearProgressIndicator(
      value: value.clamp(0, 1).toDouble(),
      minHeight: 4,
      color: AppColors.primary,
      backgroundColor: AppColors.primarySoftBorder,
    ),
  );
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: .9),
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.play_arrow_rounded,
      size: 40,
      color: AppColors.primary,
    ),
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
