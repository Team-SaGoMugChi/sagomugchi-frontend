import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

/// 통화 화면 배경 — 일기를 쓰기 시작한 시각에 따라 낮 방 / 밤 방을 깐다.
///
/// 시각은 화면에 들어온 순간 한 번만 정한다(통화 도중 18시를 넘겨도 배경이
/// 갑자기 바뀌지 않게). 위쪽은 살짝 어둡게 덮어 상단 제목·상태 글자가 밝은
/// 낮 배경에서도 읽히게 한다. 아래쪽은 화면이 말풍선 뒤에 따로 덮는다.
class CallRoomBackground extends StatelessWidget {
  const CallRoomBackground({
    super.key,
    required this.startedAt,
    required this.child,
  });

  final DateTime startedAt;
  final Widget child;

  static const dayAsset = 'assets/images/call_room_day.jpg';
  static const nightAsset = 'assets/images/call_room_night.jpg';

  /// 18:00~05:59는 밤.
  static bool isNight(DateTime time) => time.hour < 6 || time.hour >= 18;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          isNight(startedAt) ? nightAsset : dayAsset,
          fit: BoxFit.cover,
        ),
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.callBackground.withValues(alpha: 0.7),
                    AppColors.callBackground.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
