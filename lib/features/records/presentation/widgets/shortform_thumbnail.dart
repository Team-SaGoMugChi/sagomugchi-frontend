import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';

/// 숏폼 영상 미리보기 카드 — 첫 장면, 재생 버튼, 실제 길이만 보여준다.
/// 누르면 [onTap](전체 플레이어)으로 간다. 재생·탐색은 플레이어에서만 한다.
///
/// [videoUrl]이 없거나 불러오지 못하면 가짜 시간·재생바 대신 상태 문구를 보여준다.
class ShortformThumbnail extends StatefulWidget {
  const ShortformThumbnail({super.key, required this.videoUrl, this.onTap});

  final String? videoUrl;
  final VoidCallback? onTap;

  /// 세로 숏폼(9:16)을 화면에 다 넣으면 너무 길어 카드 높이를 제한한다.
  static const double maxHeight = 360;

  @override
  State<ShortformThumbnail> createState() => _ShortformThumbnailState();
}

class _ShortformThumbnailState extends State<ShortformThumbnail> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ShortformThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.videoUrl;
    if (url == null) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      // 재생하지 않고 첫 프레임만 띄운다.
      await controller.initialize();
    } catch (_) {
      if (mounted && _controller == controller) setState(() => _failed = true);
      return;
    }
    if (mounted && _controller == controller) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static String _length(Duration d) {
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final missing = widget.videoUrl == null || _failed;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: ShortformThumbnail.maxHeight,
        ),
        child: AspectRatio(
          aspectRatio: ready ? controller.value.aspectRatio : 9 / 16,
          child: GestureDetector(
            onTap: missing ? null : widget.onTap,
            child: ClipRRect(
              borderRadius: AppRadius.card,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.callBackground),
                  if (ready) VideoPlayer(controller),
                  if (missing)
                    const _Message(
                      icon: Icons.videocam_off_rounded,
                      text: '영상을 불러오지 못했어요.',
                    )
                  else if (!ready)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  else ...[
                    const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.overlayDim,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.sm),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 40,
                            color: AppColors.callTextPrimary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppColors.overlayDim,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppRadius.pill),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          child: Text(
                            _length(controller.value.duration),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.callTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.callTextSecondary),
          Gap.h8,
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: AppColors.callTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
