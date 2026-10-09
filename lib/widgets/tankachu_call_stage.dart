import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/media/tts_service.dart';
import '../theme/app_colors.dart';
import 'talking_tankachu.dart';

/// 영상통화 화면의 탄카츄 자리 — 상반신을 크게 두고, 입이 말풍선 바로 위에
/// 오도록 맞춘다. 몸통은 화면 아래 끝 밖까지 이어져 테두리에서 잘린다.
///
/// 통화 화면의 `Stack` 안에 말풍선·버튼보다 먼저 넣는다. 아래쪽은 어둡게 덮어
/// 말풍선·버튼이 잘 보이게 한다. 말풍선(bottom 104)·버튼(bottom 12) 배치가
/// Step1 말하기·Step4 상담 통화와 같다는 전제다.
class TankachuCallStage extends StatelessWidget {
  const TankachuCallStage({
    super.key,
    required this.speech,
    this.mood = TankachuMood.idle,
  });

  final ValueListenable<TtsUtterance?> speech;
  final TankachuMood mood;

  /// 화면 아래 ~ 입 (말풍선·버튼 높이).
  static const _mouthGap = 186.0;

  /// 화면 위 ~ 귀 끝 (상단 칩).
  static const _earGap = 56.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              final width = min(
                box.maxWidth * 1.22,
                (box.maxHeight - _mouthGap - _earGap) /
                    (TalkingTankachu.mouthBottomFactor -
                        TalkingTankachu.earTopFactor),
              );
              return Stack(
                children: [
                  Positioned(
                    left: (box.maxWidth - width) / 2,
                    top:
                        box.maxHeight -
                        _mouthGap -
                        width * TalkingTankachu.mouthBottomFactor,
                    child: TalkingTankachu(
                      speech: speech,
                      mood: mood,
                      width: width,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // 아래쪽을 어둡게 — 말풍선·버튼이 잘 보이고 몸통이 화면 끝으로 이어진다.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.callBackground.withValues(alpha: 0),
                    AppColors.callBackground.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
