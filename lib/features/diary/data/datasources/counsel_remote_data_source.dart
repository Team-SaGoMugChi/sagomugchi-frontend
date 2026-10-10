import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/counsel_report.dart';
import '../models/counsel_session.dart';
import '../models/counsel_turn_result.dart';
import 'counsel_data_source.dart';

/// 일기 대화 칸에서 내용이 있는 것만 남긴다. 하나도 없으면 null —
/// 요청 본문에서 `slots` 키 자체를 뺀다.
Map<String, String>? filledCounselSlots(Map<String, String?>? slots) {
  if (slots == null) return null;
  final filled = <String, String>{
    for (final entry in slots.entries)
      if ((entry.value ?? '').trim().isNotEmpty)
        entry.key: entry.value!.trim(),
  };
  return filled.isEmpty ? null : filled;
}

/// 실제 AI 서버 호출.
class CounselRemoteDataSource implements CounselDataSource {
  CounselRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CounselTurnResult> sendTurn({
    required String userText,
    List<CounselMessage> history = const [],
    Map<String, double>? emotions,
    List<String>? signals,
    String? diarySummary,
    bool incongruent = false,
    Map<String, dynamic>? persona,
    Map<String, dynamic>? psychProfile,
    Map<String, String?>? slots,
    String? emotionArc,
  }) async {
    final filledSlots = filledCounselSlots(slots);
    final arc = emotionArc?.trim();
    // 서버(JSON)는 snake_case, 앱은 camelCase — 변환은 여기서만 한다.
    final json = await _apiClient.post(
      '/counsel/turn',
      body: {
        'user_text': userText,
        'history': [for (final m in history) m.toJson()],
        if (emotions != null && emotions.isNotEmpty) 'emotions': emotions,
        if (signals != null && signals.isNotEmpty) 'signals': signals,
        if (diarySummary != null && diarySummary.isNotEmpty)
          'diary_summary': diarySummary,
        'incongruent': incongruent,
        if (persona != null && persona.isNotEmpty) 'persona': persona,
        if (psychProfile != null && psychProfile.isNotEmpty)
          'psych_profile': psychProfile,
        'slots': ?filledSlots,
        if (arc != null && arc.isNotEmpty) 'emotion_arc': arc,
      },
    );
    if (json['reply'] is! String) {
      throw const ServerException('상담 응답을 처리하지 못했어요.');
    }
    final result = CounselTurnResult.fromJson(json);
    if (result.usedDummyContext) {
      throw const ServerException('상담 서버가 아직 테스트용 맥락을 사용 중이에요.');
    }
    return result;
  }

  @override
  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
    Map<String, String?>? slots,
  }) async {
    final filledSlots = filledCounselSlots(slots);
    final json = await _apiClient.post(
      '/counsel/report',
      body: {
        'messages': [for (final m in messages) m.toJson()],
        if (emotions != null && emotions.isNotEmpty) 'emotions': emotions,
        if (diarySummary != null && diarySummary.isNotEmpty)
          'diary_summary': diarySummary,
        'slots': ?filledSlots,
      },
    );
    if (json['summary'] is! String) {
      throw const ServerException('리포트를 처리하지 못했어요.');
    }
    return CounselReport.fromJson(json);
  }
}