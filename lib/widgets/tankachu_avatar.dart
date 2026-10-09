import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/media/tts_service.dart';
import '../theme/app_colors.dart';
import 'talking_tankachu.dart';

/// 동그란 창 안의 탄카츄 얼굴 — 영상통화 상대의 작은 화면처럼, 안내 음성에
/// 맞춰 입이 움직인다. 화면의 주인공이 따로 있는 곳(베이스라인 측정 등)에서 쓴다.
class TankachuAvatar extends StatelessWidget {
  const TankachuAvatar({
    super.key,
    required this.speech,
    this.mood = TankachuMood.idle,
    this.size = 56,
  });

  final ValueListenable<TtsUtterance?> speech;
  final TankachuMood mood;
  final double size;

  /// 얼굴(눈과 입 사이)이 창 가운데 오게 한다 — 폭 대비 비율.
  static const _faceCenterX = 0.5;
  static const _faceCenterY = 780 / 1024;

  /// 창 지름 대비 탄카츄 폭 — 볼까지 들어오는 정도.
  static const _zoom = 1.25;

  @override
  Widget build(BuildContext context) {
    final width = size * _zoom;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.callSurface,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: size / 2 - width * _faceCenterX,
              top: size / 2 - width * _faceCenterY,
              child: TalkingTankachu(speech: speech, mood: mood, width: width),
            ),
          ],
        ),
      ),
    );
  }
}
