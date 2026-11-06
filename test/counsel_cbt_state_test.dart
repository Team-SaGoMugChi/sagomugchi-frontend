import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/diary/data/models/counsel_cbt_state.dart';
import 'package:oddo/features/diary/data/models/counsel_turn_result.dart';

void main() {
  test('merge keeps earlier values and applies server stage', () {
    const start = CounselCbtState(
      stage: 1,
      extracted: {'emotionLabel': '서운함'},
    );
    final next = start.merge({
      'stage': 2,
      'stage_turn': 0,
      'extracted': {'intensity': 7},
      'done': false,
    });

    expect(next.stage, 2);
    expect(next.extracted, {'emotionLabel': '서운함', 'intensity': 7});
  });

  test('request JSON uses server keys and skips empty mission', () {
    const state = CounselCbtState(stage: 3, stageTurn: 1);

    expect(state.toRequestJson(style: 'goal', lastMission: '  '), {
      'stage': 3,
      'stage_turn': 1,
      'style': 'goal',
    });
    expect(
      state.toRequestJson(style: 'empathy', lastMission: '10분 산책')['last_mission'],
      '10분 산책',
    );
  });

  test('mission survives Firestore round trip', () {
    const state = CounselCbtState(
      stage: 5,
      extracted: {'mission': '점심 먹고 10분 산책'},
      done: true,
    );
    final restored = CounselCbtState.fromJson(state.toJson());

    expect(restored.mission, '점심 먹고 10분 산책');
    expect(restored.done, isTrue);
  });

  test('tone picks counsel style', () {
    expect(CounselCbtState.styleForTone('차분하고 진중한'), 'analysis');
    expect(CounselCbtState.styleForTone('간결하고 솔직한'), 'goal');
    expect(CounselCbtState.styleForTone(null), 'empathy');
  });

  test('turn result reads cbt block', () {
    final result = CounselTurnResult.fromJson({
      'reply': '응답',
      'cbt': {'stage': 2, 'stage_turn': 0, 'extracted': {}, 'done': false},
    });

    expect(result.cbt?['stage'], 2);
  });
}