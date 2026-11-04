import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/application/pending_diary_provider.dart';
import 'package:oddo/features/diary/data/models/diary_interview.dart';
import 'package:oddo/features/diary/data/models/fusion_result.dart';

void main() {
  test('waiting diary survives a JSON round trip', () {
    final pending = PendingDiary(
      date: DateTime(2026, 11, 1),
      jobId: 'abc',
      draft: const DiaryDraftState(
        transcript: '할아버지 팔순 잔치',
        diaryText: '오늘은 팔순 잔치가 있었다.',
        summary: '뿌듯한 하루',
        interviewMessages: [
          InterviewMessage(speaker: InterviewSpeaker.user, text: '안녕'),
        ],
        interviewSlots: {'누가': '할아버지', '왜': null},
        fusionResult: FusionResult(
          emotionKeywords: ['기쁨'],
          emotionScores: {'기쁨': 70.0},
          emotionIntensity: 80,
          textEmotionScores: {'기쁨': 0.7},
          voiceDelta: {
            'pitch': FeatureDelta(baselineValue: 1, currentValue: 2, delta: 1),
          },
          faceDelta: {},
        ),
      ),
    );

    final back = PendingDiary.fromJson(pending.toJson());

    expect(back.date, DateTime(2026, 11, 1));
    expect(back.jobId, 'abc');
    expect(back.isFor(DateTime(2026, 11, 1, 15)), isTrue);
    expect(back.draft.diaryText, '오늘은 팔순 잔치가 있었다.');
    expect(back.draft.interviewMessages.single.speaker, InterviewSpeaker.user);
    expect(back.draft.interviewSlots, {'누가': '할아버지', '왜': null});
    expect(back.draft.fusionResult!.emotionIntensity, 80);
    expect(back.draft.fusionResult!.voiceDelta['pitch']!.delta, 1);
  });
}
