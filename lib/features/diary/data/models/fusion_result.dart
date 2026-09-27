/// baseline 대비 하나의 음성/표정 특징이 얼마나 달라졌는지 — 서버
/// `FeatureDeltaOut`과 1:1 대응.
class FeatureDelta {
  const FeatureDelta({
    required this.baselineValue,
    required this.currentValue,
    required this.delta,
    this.relativeDelta,
  });

  final double baselineValue;
  final double currentValue;
  final double delta;

  /// baseline이 0에 가까워 상대 변화율을 못 낼 때 null.
  final double? relativeDelta;

  factory FeatureDelta.fromJson(Map<String, dynamic> json) {
    final relativeDelta = json['relative_delta'];
    return FeatureDelta(
      baselineValue: _finiteDouble(json['baseline_value'], 'baseline_value'),
      currentValue: _finiteDouble(json['current_value'], 'current_value'),
      delta: _finiteDouble(json['delta'], 'delta'),
      relativeDelta: relativeDelta == null
          ? null
          : _finiteDouble(relativeDelta, 'relative_delta'),
    );
  }
}

/// `POST /diary/step2/analyze` 응답 — 일기 Step1 녹음/캡처를 baseline과
/// 비교해 뽑은 감정 키워드·점수. 서버 `FusionResponse`와 1:1 대응
/// (`server/app/models/fusion.py` 참고).
class FusionResult {
  const FusionResult({
    required this.emotionKeywords,
    required this.emotionScores,
    required this.emotionIntensity,
    required this.textEmotionScores,
    required this.voiceDelta,
    required this.faceDelta,
    this.signals = const [],
    this.incongruent = false,
  });

  final List<String> emotionKeywords;
  final Map<String, double> emotionScores;

  /// 0~100 — 텍스트 확신도 + 음성/표정 변화폭.
  final int emotionIntensity;
  final Map<String, double> textEmotionScores;
  final Map<String, FeatureDelta> voiceDelta;
  final Map<String, FeatureDelta> faceDelta;

  /// 서버가 baseline 대비 변화를 해석한 상담용 문장.
  /// 앱은 임계값이나 감정 의미를 다시 계산하지 않고 그대로 전달한다.
  final List<String> signals;

  /// 텍스트 감정과 음성·표정 신호가 서로 어긋난다고 서버가 판단한 경우.
  final bool incongruent;

  factory FusionResult.fromJson(Map<String, dynamic> json) {
    final emotionKeywords = _stringList(
      json['emotion_keywords'],
      'emotion_keywords',
    );
    final emotionScores = _toDoubleMap(
      json['emotion_scores'],
      fieldName: 'emotion_scores',
      min: 0,
      max: 100,
    );
    final intensity = json['emotion_intensity'];
    if (intensity is! int || intensity < 0 || intensity > 100) {
      throw const FormatException('emotion_intensity must be an integer from 0 to 100');
    }
    if (emotionKeywords.any((keyword) => !emotionScores.containsKey(keyword))) {
      throw const FormatException('emotion_keywords must exist in emotion_scores');
    }

    final rawIncongruent = json['incongruent'];
    if (rawIncongruent != null && rawIncongruent is! bool) {
      throw const FormatException('incongruent must be a boolean');
    }

    return FusionResult(
      emotionKeywords: emotionKeywords,
      emotionScores: emotionScores,
      emotionIntensity: intensity,
      textEmotionScores: _toDoubleMap(
        json['text_emotion_scores'],
        fieldName: 'text_emotion_scores',
        min: 0,
        max: 1,
      ),
      voiceDelta: _toDeltaMap(json['voice_delta'], 'voice_delta'),
      faceDelta: _toDeltaMap(json['face_delta'], 'face_delta'),
      signals: json['signals'] == null
          ? const []
          : _stringList(json['signals'], 'signals'),
      incongruent: rawIncongruent as bool? ?? false,
    );
  }

  static Map<String, double> _toDoubleMap(
    Object? raw, {
    required String fieldName,
    required double min,
    required double max,
  }) {
    if (raw is! Map) throw FormatException('$fieldName must be an object');
    return raw.map((key, value) {
      if (key is! String || key.trim().isEmpty) {
        throw FormatException('$fieldName keys must be non-empty strings');
      }
      final parsed = _finiteDouble(value, '$fieldName.$key');
      if (parsed < min || parsed > max) {
        throw FormatException('$fieldName.$key must be between $min and $max');
      }
      return MapEntry(key, parsed);
    });
  }

  static Map<String, FeatureDelta> _toDeltaMap(Object? raw, String fieldName) {
    if (raw is! Map) throw FormatException('$fieldName must be an object');
    return raw.map((key, value) {
      if (key is! String || value is! Map) {
        throw FormatException('$fieldName entries are invalid');
      }
      return MapEntry(
        key,
        FeatureDelta.fromJson(Map<String, dynamic>.from(value)),
      );
    });
  }
}

double _finiteDouble(Object? raw, String fieldName) {
  if (raw is! num) throw FormatException('$fieldName must be numeric');
  final value = raw.toDouble();
  if (!value.isFinite) throw FormatException('$fieldName must be finite');
  return value;
}

List<String> _stringList(Object? raw, String fieldName) {
  if (raw is! List || raw.any((value) => value is! String || value.trim().isEmpty)) {
    throw FormatException('$fieldName must contain non-empty strings');
  }
  return List<String>.unmodifiable(raw.cast<String>());
}
