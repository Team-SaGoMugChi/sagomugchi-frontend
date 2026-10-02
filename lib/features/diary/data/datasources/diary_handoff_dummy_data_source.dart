import '../../../../core/constants/app_durations.dart';
import '../../../../core/utils/date_formatter.dart';
import '../models/diary_handoff.dart';
import '../models/diary_interview.dart';
import '../models/fusion_result.dart';
import 'diary_handoff_data_source.dart';

/// 테스트/더미 모드용 — 서버 없이 최소한의 JSON을 만들고 메모리에만 저장한다.
class DiaryHandoffDummyDataSource implements DiaryHandoffDataSource {
  final Map<String, DiaryHandoff> saved = {};

  @override
  Future<DiaryHandoff> build({
    required DateTime date,
    required String transcript,
    String? diaryText,
    String? summary,
    Map<String, String?> slots = const {},
    List<InterviewMessage> conversation = const [],
    FusionResult? emotion,
  }) async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    final key = DateFormatter.dateKey(date);
    return DiaryHandoff(
      video: {
        'schema': 'oddo.diary_emotion.v1',
        'diary': {'date': key, 'transcript': transcript, 'diary_text': diaryText},
      },
      counsel: {
        'schema': 'oddo.counsel_context.v1',
        'date': key,
        'diary_summary': summary ?? diaryText ?? transcript,
      },
    );
  }

  @override
  Future<void> save({
    required DateTime date,
    required DiaryHandoff handoff,
  }) async {
    saved[DateFormatter.dateKey(date)] = handoff;
  }
}
