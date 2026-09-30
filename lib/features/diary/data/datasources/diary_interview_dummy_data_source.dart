import '../../../../core/constants/app_durations.dart';
import '../models/diary_interview.dart';
import 'diary_interview_data_source.dart';

/// 테스트/더미 모드용 — 답할 때마다 육하원칙 칸을 순서대로 채운 것으로 치고,
/// 빈 칸을 하나씩 묻다가 칸이 다 차면 마무리한다.
class DiaryInterviewDummyDataSource implements DiaryInterviewDataSource {
  static const _slots = ['무엇을', '언제', '어디서', '누가', '어떻게', '왜'];
  static const _questions = {
    '언제': '그 일은 언제 있었어요?',
    '어디서': '어디에서 있었던 일이에요?',
    '누가': '그때 누구와 함께였어요?',
    '어떻게': '그 일은 어떻게 흘러갔어요?',
    '왜': '왜 그렇게 됐다고 생각해요?',
  };

  @override
  Future<InterviewTurnResult> sendTurn({
    required String userText,
    List<InterviewMessage> history = const [],
  }) async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    final answers =
        history.where((m) => m.speaker == InterviewSpeaker.user).length + 1;
    final slots = {
      for (var i = 0; i < _slots.length; i++)
        _slots[i]: i < answers ? '(더미 답변)' : null,
    };
    final missing = [
      for (final name in _slots)
        if (slots[name] == null) name,
    ];
    if (missing.isEmpty) {
      return InterviewTurnResult(
        reply: '이야기해줘서 고마워요. 들은 이야기로 오늘 일기를 정리해볼게요.',
        done: true,
        slots: slots,
      );
    }
    return InterviewTurnResult(
      reply: _questions[missing.first]!,
      slots: slots,
      missing: missing,
    );
  }
}
