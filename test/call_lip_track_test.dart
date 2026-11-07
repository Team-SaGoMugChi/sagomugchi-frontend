import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/media/call_lip_track.dart';

void main() {
  test('Korean vowel families drive distinct actual face morphs', () {
    final track = CallLipTrack('아에오우');
    for (var i = 0; i < 4; i++) {
      final weights = CallLipTrack.weights(track.lip.shapeAt(i + 0.4));
      expect(weights[i], greaterThan(0.8));
      expect(weights.where((v) => v > 0).length, 1);
    }
  });

  test('bilabials and punctuation close the mouth instead of pulsing', () {
    final lip = CallLipTrack('마밤,').lip;
    for (final beat in [0.05, 1.05, 1.9, 2.3, lip.totalBeats]) {
      expect(CallLipTrack.weights(lip.shapeAt(beat)), [0, 0, 0, 0]);
    }
    expect(CallLipTrack.weights(lip.shapeAt(0.5))[0], greaterThan(0.8));
  });

  test('all Hangul cues stay finite and bounded and end closed', () {
    final text = String.fromCharCodes(List.generate(11172, (i) => 0xAC00 + i));
    final track = CallLipTrack(text);
    for (final weights in track.samples) {
      expect(weights.every((v) => v.isFinite && v >= 0 && v <= 1), isTrue);
      expect(weights.reduce((a, b) => a + b), lessThanOrEqualTo(0.951));
    }
    expect(track.samples.last, [0, 0, 0, 0]);
    expect(CallLipTrack('').samples, [
      [0, 0, 0, 0],
    ]);
  });
}
