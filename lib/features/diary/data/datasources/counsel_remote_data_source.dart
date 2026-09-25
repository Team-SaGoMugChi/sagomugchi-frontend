import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/counsel_report.dart';
import '../models/counsel_session.dart';
import '../models/counsel_turn_result.dart';
import 'counsel_data_source.dart';

/// 실제 AI 서버 호출.
class CounselRemoteDataSource implements CounselDataSource {
  CounselRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CounselTurnResult> sendTurn({
    required String userText,
    List<CounselMessage> history = const [],
    Map<String, double>? emotions,
    Map<String, dynamic>? persona,
  }) async {
    // 서버(JSON)는 snake_case, 앱은 camelCase — 변환은 여기서만 한다.
    final json = await _apiClient.post(
      '/counsel/turn',
      body: {
        'user_text': userText,
        'history': [for (final m in history) m.toJson()],
        if (emotions != null && emotions.isNotEmpty) 'emotions': emotions,
        if (persona != null && persona.isNotEmpty) 'persona': persona,
      },
    );
    if (json['reply'] is! String) {
      throw const ServerException('상담 응답을 처리하지 못했어요.');
    }
    return CounselTurnResult.fromJson(json);
  }

  @override
  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
  }) async {
    final json = await _apiClient.post(
      '/counsel/report',
      body: {
        'messages': [for (final m in messages) m.toJson()],
        if (emotions != null && emotions.isNotEmpty) 'emotions': emotions,
        if (diarySummary != null && diarySummary.isNotEmpty)
          'diary_summary': diarySummary,
      },
    );
    if (json['summary'] is! String) {
      throw const ServerException('리포트를 처리하지 못했어요.');
    }
    return CounselReport.fromJson(json);
  }
}
