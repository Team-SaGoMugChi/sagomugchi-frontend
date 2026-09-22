import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/baseline/data/models/baseline_profile.dart';

void main() {
  test('Firestore round trip preserves handoff values and feature version', () {
    final json = <String, dynamic>{
      'voice': <String, dynamic>{
        'pitchMean': 219.9,
        'f0Std': 28.4,
        'voicedRatio': 0.61,
        'durationSec': 352,
        'energyMean': 0.031,
        'speechRate': 4.2,
      },
      'face': <String, dynamic>{'eyeAspectRatio': 0.28},
      'measuredAt': '2026-09-22T00:00:00.000Z',
      'featureVersion': 1,
    };
    final profile = BaselineProfile.fromJson(json);
    expect(profile.featureVersion, 1);
    expect(profile.toJson(), json);
    expect(profile.isComplete, isTrue);
  });

  test('legacy baseline is readable without claiming new feature version', () {
    final profile = BaselineProfile.fromJson({
      'voice': <String, dynamic>{'pitchMean': 220, 'energyMean': 0.1},
      'face': <String, dynamic>{'eyeAspectRatio': 0.28},
      'measuredAt': '2026-09-01T00:00:00Z',
    });
    expect(profile.featureVersion, 0);
    expect(profile.voice.containsKey('f0Std'), isFalse);
    expect(profile.isComplete, isTrue);
  });
}
