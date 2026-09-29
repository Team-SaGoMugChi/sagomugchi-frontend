import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../data/dummy/diary_flow_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/mascot_image.dart';

/// Auxiliary — 숏폼 전체화면 플레이어. Full-screen player for the generated
/// short-form clip.
///
/// [videoUrl]이 있으면(Step3 완료 화면에서 방금 만든 영상) 실제로 재생한다.
/// 없으면(홈 등 — 지난 영상은 아직 저장되지 않음) 기존 플레이스홀더 프레임과
/// 더미 시간을 보여준다.
class ShortformPlayerScreen extends StatefulWidget {
  const ShortformPlayerScreen({super.key, this.videoUrl});

  final String? videoUrl;

  @override
  State<ShortformPlayerScreen> createState() => _ShortformPlayerScreenState();
}

class _ShortformPlayerScreenState extends State<ShortformPlayerScreen> {
  // Dummy playback position (00:03 of 01:32 ≈ 0.03) — 영상이 없을 때만.
  static const double _dummyProgress = 0.03;
  bool _dummyPlaying = true;

  VideoPlayerController? _controller;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    final url = widget.videoUrl;
    if (url != null) _load(url);
  }

  Future<void> _load(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
      await controller.play();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  bool get _hasVideo => _controller?.value.isInitialized ?? false;

  bool get _playing =>
      _hasVideo ? _controller!.value.isPlaying : _dummyPlaying;

  double get _progress {
    if (!_hasVideo) return _dummyProgress;
    final total = _controller!.value.duration.inMilliseconds;
    if (total == 0) return 0;
    return (_controller!.value.position.inMilliseconds / total).clamp(0, 1);
  }

  void _togglePlay() {
    final controller = _controller;
    if (!_hasVideo || controller == null) {
      setState(() => _dummyPlaying = !_dummyPlaying);
      return;
    }
    final value = controller.value;
    if (value.isPlaying) {
      controller.pause();
    } else {
      // 끝까지 본 뒤 누르면 처음부터 다시 재생한다.
      if (value.position >= value.duration) controller.seekTo(Duration.zero);
      controller.play();
    }
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _surface() {
    final controller = _controller;
    if (_hasVideo && controller != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }
    if (controller != null && !_loadFailed) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    // TODO: 지난 날짜 숏폼은 Storage 저장 후 재생 예정
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MascotImage(pose: MascotPose.front, size: 200, onDark: true),
          if (_loadFailed) ...[
            Gap.h12,
            Text(
              '영상을 불러오지 못했어요.',
              style: AppTypography.caption.copyWith(
                color: AppColors.callTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── The video surface (or placeholder frame), centered ───────────
          _surface(),

          // ── Bottom scrim so controls stay legible over the frame ──────────
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
          ),

          // ── Center play / pause control ───────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0x55000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // ── Top bar: back + title ─────────────────────────────────────────
          SafeArea(
            child: Row(
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
                const Expanded(
                  child: Text(
                    '숏폼 플레이어',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.callTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // ── Bottom controls: caption + scrubber + times ───────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘의 이야기를 담은 영상',
                      style: TextStyle(
                        color: AppColors.callTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap.h12,
                    _Scrubber(progress: _progress),
                    Gap.h8,
                    Row(
                      children: [
                        Text(
                          _hasVideo
                              ? _format(_controller!.value.position)
                              : DiaryFlowDummy.videoPosition,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.callTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _hasVideo
                              ? _format(_controller!.value.duration)
                              : DiaryFlowDummy.videoDuration,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.callTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.fullscreen_rounded,
                          size: 18,
                          color: AppColors.callTextPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A static progress scrubber: filled track up to [progress] with a round thumb.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Background track.
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          // Filled portion.
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          // Thumb (centered on the playhead position).
          Align(
            alignment: Alignment(progress * 2 - 1, 0),
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
