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
        'windowPitchMean': 219.9,
        'windowPitchStd': 10.0,
        'windowEnergyMean': 0.031,
        'windowEnergyStd': 0.005,
        'windowSpeechRate': 4.2,
        'windowSpeechRateStd': 0.4,
        'windowCount': 100,
        'windowUsedCount': 90,
      },
      'face': <String, dynamic>{
        'eyeAspectRatio': 0.28,
        'mouthAspectRatio': 0.11,
        'mouthWidthRatio': 1.42,
        'eyebrowRaiseRatio': 0.38,
        'au1LogMean': -2.0,
        'au1LogStd': 0.0,
        'au2LogMean': -2.0,
        'au2LogStd': 0.0,
        'au4LogMean': -2.0,
        'au4LogStd': 0.0,
        'au5LogMean': -2.0,
        'au5LogStd': 0.0,
        'au6LogMean': -2.0,
        'au6LogStd': 0.0,
        'au7LogMean': -2.0,
        'au7LogStd': 0.0,
        'au12LogMean': -2.0,
        'au12LogStd': 0.0,
        'au15LogMean': -2.0,
        'au15LogStd': 0.0,
        'au17LogMean': -2.0,
        'au17LogStd': 0.0,
        'auFrameCount': 1,
        'auTotalFrames': 1,
      },
      'measuredAt': '2026-09-22T00:00:00.000Z',
      'featureVersion': 2,
    };
    final profile = BaselineProfile.fromJson(json);
    expect(profile.featureVersion, 2);
    expect(profile.isAnalysisReady, isTrue);
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
    expect(profile.isAnalysisReady, isFalse);
  });
}
