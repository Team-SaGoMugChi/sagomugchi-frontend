import '../../../../core/constants/app_durations.dart';
import '../models/counsel_report.dart';
import '../models/counsel_session.dart';
import '../models/counsel_turn_result.dart';
import 'counsel_data_source.dart';

/// 테스트/더미 모드용 — 서버 없이 즉시 답한다.
class CounselDummyDataSource implements CounselDataSource {
  @override
  Future<CounselTurnResult> sendTurn({
    required String userText,
    List<CounselMessage> history = const [],
    Map<String, double>? emotions,
    Map<String, dynamic>? persona,
  }) async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    return const CounselTurnResult(reply: '그랬군요. 조금 더 이야기해줄래요?');
  }

  @override
  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
  }) async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    return const CounselReport(
      headline: '마음이 무거웠던 하루',
      summary: '오늘 있었던 일을 이야기하면서 스스로를 탓하는 마음이 크게 느껴졌어요. '
          '이야기하는 동안 그 마음이 조금씩 정리됐어요.',
      moments: ['생각보다 스스로에게 엄격하다는 걸 알아차렸어요.'],
      reframe: '같은 일이 다른 사람에게 일어났다면, 지금처럼 엄하게 보지는 않았을지도 몰라요.',
      suggestion: '그 생각이 또 들면 짧게 메모해두고 나중에 다시 읽어봐요.',
      closing: '오늘은 여기까지만 해도 충분해요.',
    );
  }
}
