/// The user's face/voice baseline, measured once during onboarding and used
/// as the comparison reference for every diary's emotion analysis.
///
/// Stored at `users/{uid}/meta/baseline` — see FIRESTORE_SCHEMA.md.
///
/// [voice]/[face] keys are defined by the AI server (Phase 4) — e.g.
/// `pitchMean`, `speechRate`, `energyMean` — the app only stores and forwards
/// them without interpreting.
class BaselineProfile {
  static const currentFeatureVersion = 1;

  static const requiredAnalysisVoiceKeys = {
    'pitchMean',
    'f0Std',
    'speechRate',
    'voicedRatio',
    'durationSec',
    'energyMean',
  };

  static const requiredAnalysisFaceKeys = {
    'eyeAspectRatio',
    'mouthAspectRatio',
    'mouthWidthRatio',
    'eyebrowRaiseRatio',
  };

  const BaselineProfile({
    required this.voice,
    required this.face,
    required this.measuredAt,
    this.featureVersion = 0,
  });

  final Map<String, double> voice;
  final Map<String, double> face;
  final DateTime measuredAt;

  /// Missing version means a legacy measurement, not version 1.
  final int featureVersion;

  /// Legacy profiles may contain empty maps even though a save succeeded.
  bool get hasVoiceReference =>
      (voice['pitchMean'] ?? 0) > 0 &&
      (voice['energyMean'] ?? 0) > 0 &&
      voice.values.every((value) => value.isFinite);

  bool get hasFaceReference =>
      face.isNotEmpty &&
      face.values.every((value) => value.isFinite && value >= 0);

  bool get isComplete => hasVoiceReference && hasFaceReference;

  /// Whether this profile satisfies the contract used by diary analysis.
  ///
  /// [isComplete] remains lenient so a legacy profile can be displayed. It
  /// must not be used for a new analysis because missing fields would silently
  /// reduce the number of deltas and change the resulting score.
  bool get isAnalysisReady =>
      featureVersion == currentFeatureVersion &&
      requiredAnalysisVoiceKeys.every(voice.containsKey) &&
      requiredAnalysisFaceKeys.every(face.containsKey) &&
      hasVoiceReference &&
      hasFaceReference &&
      voice['f0Std']! >= 0 &&
      voice['speechRate']! >= 0 &&
      voice['voicedRatio']! > 0 &&
      voice['voicedRatio']! <= 1 &&
      voice['durationSec']! > 0;

  factory BaselineProfile.fromJson(Map<String, dynamic> json) =>
      BaselineProfile(
        voice: (json['voice'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        face: (json['face'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        measuredAt: DateTime.parse(json['measuredAt'] as String),
        featureVersion: (json['featureVersion'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'voice': voice,
    'face': face,
    'measuredAt': measuredAt.toIso8601String(),
    'featureVersion': featureVersion,
  };
}
