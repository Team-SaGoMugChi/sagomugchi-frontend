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

  factory FeatureDelta.fromJson(Map<String, dynamic> json) => FeatureDelta(
    baselineValue: (json['baseline_value'] as num).toDouble(),
    currentValue: (json['current_value'] as num).toDouble(),
    delta: (json['delta'] as num).toDouble(),
    relativeDelta: (json['relative_delta'] as num?)?.toDouble(),
  );
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

  factory FusionResult.fromJson(Map<String, dynamic> json) => FusionResult(
    emotionKeywords: (json['emotion_keywords'] as List<dynamic>).cast<String>(),
    emotionScores: _toDoubleMap(json['emotion_scores']),
    emotionIntensity: json['emotion_intensity'] as int,
    textEmotionScores: _toDoubleMap(json['text_emotion_scores']),
    voiceDelta: _toDeltaMap(json['voice_delta']),
    faceDelta: _toDeltaMap(json['face_delta']),
    signals: (json['signals'] as List<dynamic>? ?? const []).cast<String>(),
    incongruent: json['incongruent'] as bool? ?? false,
  );

  static Map<String, double> _toDoubleMap(Object? raw) {
    final map = raw as Map<String, dynamic>? ?? {};
    return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  static Map<String, FeatureDelta> _toDeltaMap(Object? raw) {
    final map = raw as Map<String, dynamic>? ?? {};
    return map.map(
      (k, v) => MapEntry(k, FeatureDelta.fromJson(v as Map<String, dynamic>)),
    );
  }
}
