import 'korean_lip_sync.dart';

/// Text-derived mouth cues, corrected by TTS word events or playback duration.
/// This estimates articulation; it does not analyze the audio waveform.
class CallLipTrack {
  CallLipTrack(String text) : lip = KoreanLipSync(text) {
    samples = List.generate(
      (lip.totalBeats / step).ceil() + 1,
      (i) => weights(lip.shapeAt(i * step)),
    );
  }

  static const step = 0.1;
  final KoreanLipSync lip;
  late final List<List<double>> samples;

  /// AA / E / O / U. Keep the sum below one so blended shapes cannot over-open.
  static List<double> weights(MouthShape shape) {
    if (shape.open <= 0) return [0, 0, 0, 0];
    final result = [0.0, 0.0, 0.0, 0.0];
    if (shape.round >= 0.5) {
      final u = ((shape.round - 0.8) / 0.2).clamp(0.0, 1.0);
      final referenceOpen = 0.55 * (1 - u) + 0.35 * u;
      final amount = (shape.open / referenceOpen * 0.9).clamp(0.0, 0.95);
      result[2] = amount * (1 - u);
      result[3] = amount * u;
    } else if (shape.width >= 0.7) {
      result[1] = (shape.open / 0.65 * 0.9).clamp(0.0, 0.95);
    } else {
      result[0] = (shape.open / 0.95 * 0.9).clamp(0.0, 0.95);
    }
    return result.map((v) => (v * 1000).round() / 1000).toList();
  }

  Map<String, Object> toJson() => {
    'step': step,
    'total': lip.totalBeats,
    'samples': samples,
  };
}
