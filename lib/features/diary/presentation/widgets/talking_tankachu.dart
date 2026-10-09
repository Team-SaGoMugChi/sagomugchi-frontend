import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/media/korean_lip_sync.dart';
import '../../../../core/media/tts_service.dart';

/// 통화 중 탄카츄가 지금 무엇을 하고 있나 — 표정과 자세가 바뀐다.
enum TankachuMood {
  /// 기본 — 화면을 보며 가만히.
  idle,

  /// 사용자가 말하는 중 — 살짝 앞으로 기울여 귀 기울인다.
  listening,

  /// 서버 응답을 기다리는 중 — 고개를 갸웃하고 위를 본다.
  thinking,
}

/// 눈 모양. 감정 대시보드가 현재 감정에 맞춰 바꿀 수 있다.
enum TankachuExpression { neutral, happy, worried }

/// 영상통화 화면의 탄카츄 — 몸통·머리 레이어 위에 눈과 입을 코드로 그린다.
///
/// - 입: [speech]가 알려주는 문장을 한글 음절 단위 입 모양([KoreanLipSync])으로
///   바꿔 TTS 소리에 맞춰 움직인다. TTS가 읽는 위치를 알려주면 그 자리로 다시 맞춘다.
/// - 눈: 2.5~5.5초마다 깜빡이고, 가끔 시선을 옮긴다.
/// - 몸: 숨쉬기만 한다. 몸 전체를 흔들면 떨림으로 보인다는 피드백이 있어서
///   (assets/animations/README.md) 움직임은 머리에만 작게 준다.
///
/// 레이어 원본은 눈·입을 지운 정면 상반신 탄카츄 한 장을 머리/몸통으로 나눈
/// `talk_head.png`·`talk_body.png`(1024×1613, 같은 좌표). 아래 좌표는 모두 그 기준.
/// 몸통은 아래로 길게 이어져 있어서, 화면 아래 끝에 걸쳐 두면 영상통화처럼
/// 화면 테두리에서 잘려 보인다.
class TalkingTankachu extends StatefulWidget {
  const TalkingTankachu({
    super.key,
    required this.speech,
    this.mood = TankachuMood.idle,
    this.expression = TankachuExpression.neutral,
    this.width = 300,
  });

  /// 지금 읽고 있는 문장 — 보통 [TtsService.utterance].
  final ValueListenable<TtsUtterance?> speech;
  final TankachuMood mood;
  final TankachuExpression expression;

  /// 위젯 폭. 높이는 [heightFactor]배.
  final double width;

  static const headAsset = 'assets/images/character/talk_head.png';
  static const bodyAsset = 'assets/images/character/talk_body.png';

  /// 높이 / 폭.
  static const heightFactor = _Geo.height / _Geo.width;

  /// 귀 끝의 높이(폭 대비) — 이 위로는 비어 있다.
  static const earTopFactor = 246.6 / _Geo.width;

  /// 입 아래 끝의 높이(폭 대비) — 말풍선에 가리지 않게 배치할 때 쓴다.
  static const mouthBottomFactor = 900 / _Geo.width;

  @override
  State<TalkingTankachu> createState() => _TalkingTankachuState();
}

class _TalkingTankachuState extends State<TalkingTankachu>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _rig = _Rig();
  final _random = Random();

  Duration _now = Duration.zero;
  Duration _last = Duration.zero;

  // 말하기
  KoreanLipSync? _lip;
  int? _serial;
  double _beatBase = 0;
  Duration _beatClock = Duration.zero;

  // 깜빡임·시선 예약
  Duration _nextBlink = const Duration(milliseconds: 1800);
  Duration? _blinkStart;
  bool _doubleBlink = false;
  Duration _nextGlance = const Duration(milliseconds: 2500);
  Offset _gazeTarget = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.speech.addListener(_onSpeech);
    _onSpeech();
    _ticker.start();
  }

  @override
  void didUpdateWidget(TalkingTankachu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speech != widget.speech) {
      oldWidget.speech.removeListener(_onSpeech);
      widget.speech.addListener(_onSpeech);
      _onSpeech();
    }
  }

  @override
  void dispose() {
    widget.speech.removeListener(_onSpeech);
    _ticker.dispose();
    _rig.dispose();
    super.dispose();
  }

  void _onSpeech() {
    final speech = widget.speech.value;
    if (speech == null) {
      _lip = null;
      _serial = null;
      return;
    }
    if (speech.serial != _serial || _lip?.text != speech.text) {
      _lip = KoreanLipSync(speech.text);
      _serial = speech.serial;
      _beatBase = 0;
      _beatClock = _now;
    }
    final index = speech.charIndex;
    if (index != null) {
      // TTS가 알려준 읽는 위치로 다시 맞춘다 — 추정이 빠르거나 느려도 단어마다 보정된다.
      _beatBase = _lip!.beatAtChar(index);
      _beatClock = _now;
    }
  }

  void _onTick(Duration now) {
    _now = now;
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    final t = now.inMicroseconds / 1e6;

    _rig.mouth = MouthShape.lerp(_rig.mouth, _mouthTarget(), _ease(dt, 26));
    _rig.eyeOpen = _blink(now);
    _rig.gaze = Offset.lerp(_rig.gaze, _gaze(now), _ease(dt, 14))!;

    // 고개: 평소엔 아주 느리게 갸웃, 말할 땐 박자에 맞춰 살짝 끄덕, 상태별 기울기.
    final speaking = _lip != null;
    final moodTilt = switch (widget.mood) {
      TankachuMood.idle => 0.0,
      TankachuMood.listening => -2.2,
      TankachuMood.thinking => 4.5,
    };
    _rig.tiltBase = _rig.tiltBase + (moodTilt - _rig.tiltBase) * _ease(dt, 3);
    final sway = 0.9 * sin(2 * pi * t / 5.3) + 0.4 * sin(2 * pi * t / 3.1 + 1);
    final nod = speaking ? 1.1 * sin(2 * pi * t / 1.7) : 0.0;
    _rig.tiltDeg = _rig.tiltBase + sway + nod;
    _rig.lift = speaking ? _rig.mouth.open * 6 : 0;
    final lean = widget.mood == TankachuMood.listening ? 0.018 : 0.0;
    _rig.lean = _rig.lean + (lean - _rig.lean) * _ease(dt, 4);
    _rig.breath = sin(2 * pi * t / 3.6);
    _rig.notify();
  }

  static double _ease(double dt, double rate) => 1 - exp(-dt * rate);

  MouthShape _mouthTarget() {
    final lip = _lip;
    if (lip == null || lip.totalBeats <= 0) return MouthShape.rest;
    final elapsed = (_now - _beatClock).inMicroseconds / 1e6;
    var beat = _beatBase + elapsed * KoreanLipSync.syllablesPerSecond;
    // 추정이 실제 소리보다 빨라 문장 끝을 넘었는데 아직 읽는 중이면,
    // 마지막 몇 음절을 되풀이해 입이 멈춰 보이지 않게 한다.
    final total = lip.totalBeats;
    if (beat >= total) {
      final tail = min(4.0, total);
      beat = total - tail + (beat - total) % tail;
    }
    return lip.shapeAt(beat);
  }

  double _blink(Duration now) {
    if (_blinkStart == null && now >= _nextBlink) _blinkStart = now;
    final start = _blinkStart;
    if (start == null) return 1;
    const duration = 150;
    final p = (now - start).inMilliseconds / duration;
    if (p >= 1) {
      _blinkStart = null;
      if (_doubleBlink) {
        _doubleBlink = false;
        _nextBlink = now + const Duration(milliseconds: 110);
      } else {
        _doubleBlink = _random.nextDouble() < 0.18;
        _nextBlink =
            now + Duration(milliseconds: 2500 + _random.nextInt(3000));
      }
      return 1;
    }
    // 감는 건 빠르게, 뜨는 건 조금 천천히.
    return p < 0.4 ? 1 - p / 0.4 : (p - 0.4) / 0.6;
  }

  Offset _gaze(Duration now) {
    if (widget.mood == TankachuMood.thinking) return const Offset(-0.7, -0.9);
    if (now >= _nextGlance) {
      // 대부분은 정면(화면 너머 사용자), 가끔 옆을 힐끗.
      _gazeTarget = _random.nextDouble() < 0.55
          ? Offset.zero
          : Offset(
              _random.nextDouble() * 1.6 - 0.8,
              _random.nextDouble() * 0.9 - 0.45,
            );
      _nextGlance = now + Duration(milliseconds: 1200 + _random.nextInt(2400));
    }
    return _gazeTarget;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.width * TalkingTankachu.heightFactor,
      child: FittedBox(
        child: SizedBox(
          width: _Geo.width,
          height: _Geo.height,
          child: AnimatedBuilder(
            animation: _rig,
            builder: (context, _) {
              final breath = _rig.breath;
              final bodyScale = 1 + 0.006 * breath;
              // 몸이 부풀면 그 위의 머리도 같이 올라간다.
              final headRise = (bodyScale - 1) * (_Geo.height - _Geo.pivot.dy);
              return Stack(
                children: [
                  Positioned.fill(
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(1, bodyScale, 1),
                      child: Image.asset(TalkingTankachu.bodyAsset),
                    ),
                  ),
                  Positioned.fill(
                    child: Transform(
                      transform: _headTransform(headRise),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(TalkingTankachu.headAsset),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _FacePainter(
                                mouth: _rig.mouth,
                                eyeOpen: _rig.eyeOpen,
                                gaze: _rig.gaze,
                                expression: widget.expression,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Matrix4 _headTransform(double headRise) {
    const p = _Geo.pivot;
    final scale = 1 + _rig.lean;
    return Matrix4.identity()
      ..translateByDouble(p.dx, p.dy - headRise - _rig.lift, 0, 1)
      ..rotateZ(_rig.tiltDeg * pi / 180)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-p.dx, -p.dy, 0, 1);
  }
}

/// 매 프레임 바뀌는 값 묶음 — 한 번만 알려서 한 번만 다시 그린다.
class _Rig extends ChangeNotifier {
  MouthShape mouth = MouthShape.rest;
  double eyeOpen = 1;
  Offset gaze = Offset.zero;
  double tiltBase = 0;
  double tiltDeg = 0;
  double lift = 0;
  double lean = 0;
  double breath = 0;

  void notify() => notifyListeners();
}

/// 레이어 이미지(1024×1613) 안의 실측 좌표. 눈은 상반신 그림에 눈이 없어서,
/// 눈이 있던 이전 base에서 잰 위치를 코·볼 기준 비율로 옮겨 왔다.
abstract final class _Geo {
  static const width = 1024.0;
  static const height = 1613.0;

  /// 목 — 머리가 기우는 중심.
  static const pivot = Offset(512, 1012.1);

  static const leftEye = Offset(384.9, 749.7);
  static const rightEye = Offset(646.9, 749.7);
  static const eyeSize = Size(87, 98.1);

  /// 코 아래 끝 — 입은 여기서 시작한다.
  static const noseBottom = Offset(512.3, 823.1);

  /// 입 크기 배율 — 입 모양 수치는 코 폭 66.6px 기준으로 잡았다(이 그림은 74px).
  static const mouthScale = 1.11;
}

class _FacePainter extends CustomPainter {
  _FacePainter({
    required this.mouth,
    required this.eyeOpen,
    required this.gaze,
    required this.expression,
  });

  final MouthShape mouth;
  final double eyeOpen;
  final Offset gaze;
  final TankachuExpression expression;

  // 원본 아트 실측 색. 앱 테마 색이 아니라 캐릭터 그림의 일부라 여기 둔다.
  static const _eyeDark = Color(0xFF39250F);
  static const _eyeMid = Color(0xFF4A3119);
  static const _fur = Color(0xFF744E2E);
  static const _line = Color(0xFF482F18);
  static const _mouthInside = Color(0xFF3A1D10);
  static const _tongue = Color(0xFFD9786B);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _Geo.width;
    canvas.save();
    canvas.scale(k);
    _eye(canvas, _Geo.leftEye, isLeft: true);
    _eye(canvas, _Geo.rightEye, isLeft: false);
    const nose = _Geo.noseBottom;
    canvas
      ..translate(nose.dx, nose.dy)
      ..scale(_Geo.mouthScale)
      ..translate(-nose.dx, -nose.dy);
    _mouth(canvas);
    canvas.restore();
  }

  void _eye(Canvas canvas, Offset center, {required bool isLeft}) {
    final w = _Geo.eyeSize.width;
    final h = _Geo.eyeSize.height;
    final c = center + Offset(gaze.dx * 6, gaze.dy * 5);

    if (expression == TankachuExpression.happy) {
      // 웃는 눈 ∩
      final path = Path()
        ..moveTo(c.dx - w * 0.42, c.dy + h * 0.1)
        ..quadraticBezierTo(c.dx, c.dy - h * 0.42, c.dx + w * 0.42, c.dy + h * 0.1);
      canvas.drawPath(path, _stroke(_eyeDark, 9));
      return;
    }

    if (eyeOpen < 0.15) {
      // 감은 눈 — 아래로 살짝 휜 선.
      final path = Path()
        ..moveTo(c.dx - w * 0.44, c.dy + h * 0.12)
        ..quadraticBezierTo(c.dx, c.dy + h * 0.34, c.dx + w * 0.44, c.dy + h * 0.12);
      canvas.drawPath(path, _stroke(_eyeDark, 7));
      return;
    }

    // 눈꺼풀이 위에서 내려오므로 아래쪽 끝은 그대로 두고 위쪽만 줄인다.
    final openH = h * eyeOpen;
    final rect = Rect.fromLTWH(c.dx - w / 2, c.dy + h / 2 - openH, w, openH);
    final fill = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.3),
        radius: 0.8,
        colors: [_eyeMid, _eyeDark],
      ).createShader(rect);
    canvas.drawOval(rect, fill);

    if (eyeOpen > 0.55) {
      final hl = Paint()..color = Colors.white.withValues(alpha: 0.95);
      canvas.drawCircle(
        Offset(c.dx + w * 0.15, c.dy - h * 0.31 + (1 - eyeOpen) * h * 0.5),
        w * 0.135,
        hl,
      );
      canvas.drawCircle(
        Offset(c.dx - w * 0.17, c.dy + h * 0.2),
        w * 0.05,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }

    if (expression == TankachuExpression.worried) {
      // 바깥쪽 위를 털색 눈꺼풀로 덮어 처진 눈.
      final outer = isLeft ? c.dx - w * 0.6 : c.dx + w * 0.6;
      final inner = isLeft ? c.dx + w * 0.6 : c.dx - w * 0.6;
      final lid = Path()
        ..moveTo(outer, c.dy - h * 0.7)
        ..lineTo(inner, c.dy - h * 0.7)
        ..lineTo(inner, c.dy - h * 0.5)
        ..lineTo(outer, c.dy - h * 0.05)
        ..close();
      canvas.drawPath(lid, Paint()..color = _fur);
    }
  }

  void _mouth(Canvas canvas) {
    final cx = _Geo.noseBottom.dx;
    final top = _Geo.noseBottom.dy;
    final j = Offset(cx, top + 14); // 인중이 끝나고 입이 갈라지는 점
    final open = mouth.open;
    final round = mouth.round;

    // 다문 입: 탄카츄 원래의 "人" 모양. 벌어질수록 양 끝이 위로 올라가 입이 열린다.
    final hw = (24 + 22 * mouth.width) * (1 - 0.3 * round);
    final cornerY = j.dy + 22 - 10 * round - 8 * open;
    final left = Offset(cx - hw, cornerY);
    final right = Offset(cx + hw, cornerY);
    final ctrlY = j.dy + 8 - 6 * round;

    final upper = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(cx - hw * 0.4, ctrlY, j.dx, j.dy)
      ..quadraticBezierTo(cx + hw * 0.4, ctrlY, right.dx, right.dy);

    final philtrum = Path()
      ..moveTo(cx, top - 2)
      ..lineTo(j.dx, j.dy);

    if (open > 0.04) {
      final depth = open * 84;
      final bottomY = cornerY + depth;
      final shape = Path.from(upper)
        ..cubicTo(
          right.dx + hw * 0.1 * round,
          bottomY,
          left.dx - hw * 0.1 * round,
          bottomY,
          left.dx,
          left.dy,
        )
        ..close();
      canvas.drawPath(shape, Paint()..color = _mouthInside);
      // 혀 — 입 안 아래쪽에만 보이게 입 모양으로 잘라 그린다.
      canvas.save();
      canvas.clipPath(shape);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, bottomY - depth * 0.05),
          width: hw * 1.3,
          height: depth * 0.75,
        ),
        Paint()..color = _tongue,
      );
      canvas.restore();
      canvas.drawPath(shape, _stroke(_line, 5));
    } else {
      canvas.drawPath(upper, _stroke(_line, 5.5));
    }
    canvas.drawPath(philtrum, _stroke(_line, 5.5));
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.mouth != mouth ||
      old.eyeOpen != eyeOpen ||
      old.gaze != gaze ||
      old.expression != expression;
}
