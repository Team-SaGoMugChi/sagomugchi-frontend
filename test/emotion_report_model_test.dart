import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/diary/data/models/emotion_report.dart';

void main() {
  final base = {
    'date': '2026-10-21T00:00:00.000',
    'emotionDistribution': {'서운함': 0.6, '불안': 0.4},
    'emotionIntensity': 70,
    'recoveryPossibility': 0,
    'analysisComment': '회의에서 의견이 묻힌 날이에요.',
    'behaviorGuides': <String>[],
    'recommendedActivities': <String>[],
  };

  test('reads documents saved before counsel fields existed', () {
    final report = EmotionReport.fromJson(base);
    expect(report.headline, isEmpty);
    expect(report.moments, isEmpty);
    expect(report.reframe, isEmpty);
  });

  test('round-trips counsel fields through JSON', () {
    final saved = EmotionReport.fromJson({
      ...base,
      'headline': '반응 없던 회의가 마음에 남은 날',
      'moments': ['팀장님이 바빠서 그랬을 수도 있다는 걸 떠올렸어요.'],
      'reframe': '반응이 없던 건 상황 때문일 수도 있어요.',
    });

    final restored = EmotionReport.fromJson(saved.toJson());
    expect(restored.headline, '반응 없던 회의가 마음에 남은 날');
    expect(restored.moments, ['팀장님이 바빠서 그랬을 수도 있다는 걸 떠올렸어요.']);
    expect(restored.reframe, '반응이 없던 건 상황 때문일 수도 있어요.');
  });
}