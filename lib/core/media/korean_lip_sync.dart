import 'dart:ui' show lerpDouble;

/// 탄카츄 입 모양 한 순간 — 그리는 쪽(painter)은 이 세 값만 본다.
///
/// [open] 위아래로 벌어진 정도, [width] 옆으로 벌어진 정도, [round] 입술을
/// 동그랗게 오므린 정도. 모두 0~1.
class MouthShape {
  const MouthShape({this.open = 0, this.width = 0.5, this.round = 0});

  final double open;
  final double width;
  final double round;

  /// 다문 입 — 쉼표·문장 사이, 듣는 중.
  static const rest = MouthShape();

  /// ㅁ·ㅂ·ㅍ — 입술이 닫히는 순간. [rest]와 같지만 의미를 나눠 둔다.
  static const closed = MouthShape(width: 0.45);

  static MouthShape lerp(MouthShape a, MouthShape b, double t) => MouthShape(
    open: lerpDouble(a.open, b.open, t)!,
    width: lerpDouble(a.width, b.width, t)!,
    round: lerpDouble(a.round, b.round, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is MouthShape &&
      other.open == open &&
      other.width == width &&
      other.round == round;

  @override
  int get hashCode => Object.hash(open, width, round);

  @override
  String toString() => 'MouthShape(open: $open, width: $width, round: $round)';
}

/// 한글 문장을 입 모양 시간표로 바꾼다.
///
/// 기기 TTS는 음성 파형이나 발음(viseme) 정보를 주지 않는다. 대신 한글은
/// 음절 하나에 모음이 하나씩 들어 있어서, 글자만 보고도 입 모양을 꽤 정확히
/// 고를 수 있다 — 초성 ㅁㅂㅍ이면 잠깐 다물었다가, 모음 모양으로 벌리고,
/// 받침 ㅁㅂㅍ이면 다시 다문다. 문장부호는 쉼(다문 입)으로 둔다.
///
/// 위치는 "음절 단위 박자"로 센다: 한글 음절 1, 띄어쓰기 0.4, 문장부호 1.5.
/// 화면은 경과 시간 × [syllablesPerSecond]로 지금 박자를 구하고, TTS가 읽는
/// 위치를 알려주면([beatAtChar]) 그 자리로 다시 맞춘다.
class KoreanLipSync {
  KoreanLipSync(this.text) : _beats = _measure(text);

  final String text;

  /// 각 글자가 시작되는 박자(누적). 길이는 text.length + 1.
  final List<double> _beats;

  /// 기기 TTS 한국어, 말하기 속도 0.45 기준 대략값. 실기기에서 맞춘다.
  static const double syllablesPerSecond = 5.2;

  static const double _spaceBeat = 0.4;
  static const double _pauseBeat = 1.5;

  /// 문장 전체를 읽는 데 드는 박자.
  double get totalBeats => _beats.last;

  /// [index]번째 글자가 시작되는 박자 — TTS 진행 위치에 다시 맞출 때 쓴다.
  double beatAtChar(int index) => _beats[index.clamp(0, text.length)];

  /// [beat] 시점의 입 모양. 문장 밖이면 [MouthShape.rest].
  MouthShape shapeAt(double beat) {
    if (beat < 0 || beat >= totalBeats || text.isEmpty) return MouthShape.rest;
    // 박자가 속한 글자 찾기 (글자 수가 적어서 선형 탐색으로 충분).
    var i = 0;
    while (i < text.length - 1 && _beats[i + 1] <= beat) {
      i++;
    }
    final span = _beats[i + 1] - _beats[i];
    final phase = span <= 0 ? 0.0 : (beat - _beats[i]) / span;
    return _shapeOfChar(text.codeUnitAt(i), phase);
  }

  static List<double> _measure(String text) {
    final beats = List<double>.filled(text.length + 1, 0);
    for (var i = 0; i < text.length; i++) {
      beats[i + 1] = beats[i] + _beatOf(text.codeUnitAt(i));
    }
    return beats;
  }

  static double _beatOf(int code) {
    if (_isHangul(code)) return 1;
    if (code == 0x20 || code == 0x0A) return _spaceBeat;
    if (_isPause(code)) return _pauseBeat;
    // 영문·숫자 등은 음절 하나 정도로 친다.
    return 0.6;
  }

  static bool _isHangul(int code) => code >= 0xAC00 && code <= 0xD7A3;

  static bool _isPause(int code) =>
      const {0x2E, 0x2C, 0x21, 0x3F, 0x7E, 0x2026, 0x3002}.contains(code);

  // 초성 ㅁ ㅂ ㅃ ㅍ — 입술이 닫혔다 열린다.
  static const _bilabialInitials = {6, 7, 8, 17};

  // 받침 ㄻ ㄼ ㄿ ㅁ ㅂ ㅄ ㅍ — 끝에 입술이 닫힌다.
  static const _bilabialFinals = {10, 11, 14, 16, 17, 18, 26};

  static MouthShape _shapeOfChar(int code, double phase) {
    if (!_isHangul(code)) {
      if (_isPause(code) || code == 0x20 || code == 0x0A) {
        return MouthShape.rest;
      }
      return _eo;
    }
    final syllable = code - 0xAC00;
    final initial = syllable ~/ 588;
    final medial = (syllable % 588) ~/ 28;
    final finalIndex = syllable % 28;

    if (phase < 0.2 && _bilabialInitials.contains(initial)) {
      return MouthShape.closed;
    }
    if (phase > 0.78 && _bilabialFinals.contains(finalIndex)) {
      return MouthShape.closed;
    }
    // 받침이 있으면 끝에서 입이 조금 덜 벌어진다.
    final vowel = _vowelShape(medial, phase);
    if (finalIndex != 0 && phase > 0.7) {
      return MouthShape.lerp(vowel, MouthShape.rest, 0.45);
    }
    return vowel;
  }

  static const _a = MouthShape(open: 0.95, width: 0.6);
  static const _ae = MouthShape(open: 0.65, width: 0.8);
  static const _eo = MouthShape(open: 0.6, width: 0.5);
  static const _o = MouthShape(open: 0.55, width: 0.35, round: 0.8);
  static const _u = MouthShape(open: 0.35, width: 0.25, round: 1);
  static const _eu = MouthShape(open: 0.22, width: 0.8);
  static const _i = MouthShape(open: 0.28, width: 0.95);

  /// 중성 번호(ㅏ=0 … ㅣ=20) → 입 모양. 이중모음은 앞 모음에서 뒤 모음으로 넘어간다.
  static MouthShape _vowelShape(int medial, double phase) {
    MouthShape glide(MouthShape from, MouthShape to) =>
        MouthShape.lerp(from, to, ((phase - 0.15) / 0.35).clamp(0.0, 1.0));
    return switch (medial) {
      0 || 2 => _a, // ㅏ ㅑ
      1 || 3 || 5 || 7 => _ae, // ㅐ ㅒ ㅔ ㅖ
      4 || 6 => _eo, // ㅓ ㅕ
      8 || 12 => _o, // ㅗ ㅛ
      9 => glide(_o, _a), // ㅘ
      10 || 11 => glide(_o, _ae), // ㅙ ㅚ
      13 || 17 => _u, // ㅜ ㅠ
      14 => glide(_u, _eo), // ㅝ
      15 => glide(_u, _ae), // ㅞ
      16 => glide(_u, _i), // ㅟ
      18 => _eu, // ㅡ
      19 => glide(_eu, _i), // ㅢ
      _ => _i, // ㅣ
    };
  }
}
