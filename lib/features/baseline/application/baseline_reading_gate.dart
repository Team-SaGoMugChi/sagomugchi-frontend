/// A minimum microphone activity check, not speech recognition or a quality score.
/// The server still validates usable voiced audio before saving a real baseline.
class BaselineReadingGate {
  BaselineReadingGate({this.requiredSamples = 4});
  final int requiredSamples;
  static const sampleInterval = Duration(milliseconds: 300);
  static const _thresholdDb = -35.0;
  int _voicedSamples = 0;

  bool get canContinue => _voicedSamples >= requiredSamples;

  void add(double decibels) {
    if (decibels.isFinite && decibels > _thresholdDb) _voicedSamples++;
  }

  void reset() => _voicedSamples = 0;
}
