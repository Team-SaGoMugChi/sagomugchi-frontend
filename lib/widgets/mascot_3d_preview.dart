import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../core/constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Interactive preview of 3D 오또, preserving the original connected arms.
///
/// [AppAssets.mascotModel]은 Tripo의 인간형(Mixamo) 뼈대 대신 체형에 맞춘
/// 11개 뼈(몸통·머리·양 귀·양 팔·양 손·양 발)로 다시 스키닝한 모델이며
/// `Idle`·`Wave`·`Nod`·`Hop` 클립을 포함한다. 미리보기는 인사(`Wave`)를 반복한다.
class Mascot3dPreview extends StatefulWidget {
  const Mascot3dPreview({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.authBackground,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => const SafeArea(
      top: false,
      child: FractionallySizedBox(heightFactor: 0.75, child: Mascot3dPreview()),
    ),
  );

  @override
  State<Mascot3dPreview> createState() => _Mascot3dPreviewState();
}

class _Mascot3dPreviewState extends State<Mascot3dPreview> {
  Timer? _timeout;
  bool _loaded = false;
  bool _failed = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_supported) {
      _timeout = Timer(const Duration(seconds: 20), () {
        if (mounted && !_loaded) setState(() => _failed = true);
      });
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        child: Row(
          children: [
            const Expanded(
              child: Text('오또를 3D로 보기', style: AppTypography.subtitle),
            ),
            IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
      Expanded(
        child: !_supported || _failed
            ? const Center(
                child: Icon(
                  Icons.view_in_ar_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: ModelViewer(
                      src: AppAssets.mascotModel,
                      alt: '손을 흔들며 인사하는 오또',
                      animationName: 'Wave',
                      autoPlay: !MediaQuery.disableAnimationsOf(context),
                      backgroundColor: AppColors.authBackground,
                      cameraControls: true,
                      autoRotate: !MediaQuery.disableAnimationsOf(context),
                      disableZoom: true,
                      innerModelViewerHtml:
                          '<div slot="progress-bar" style="display:none"></div>',
                      relatedCss:
                          'html,body { margin:0; overflow:hidden; } ::-webkit-scrollbar { display:none; }',
                      relatedJs: """
            const model = document.querySelector('model-viewer');
            model.addEventListener('load', () => OddoPreview.postMessage('loaded'));
            model.addEventListener('error', () => OddoPreview.postMessage('error'));
            if (model.loaded) OddoPreview.postMessage('loaded');
          """,
                      javascriptChannels: {
                        JavascriptChannel(
                          'OddoPreview',
                          onMessageReceived: (message) {
                            if (!mounted) return;
                            _timeout?.cancel();
                            setState(() {
                              _loaded = message.message == 'loaded';
                              _failed = !_loaded;
                            });
                          },
                        ),
                      },
                    ),
                  ),
                  if (!_loaded)
                    const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: '오또를 불러오는 중',
                      ),
                    ),
                ],
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Text(
          _failed
              ? '지금은 3D를 불러오지 못했어요. 잠시 후 다시 열어주세요.'
              : !_supported
              ? '오또가 함께할게요.'
              : '손가락으로 돌려서 살펴보세요.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
      ),
    ],
  );
}
