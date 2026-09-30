import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/diary_interview.dart';
import 'diary_interview_data_source.dart';

/// 실제 AI 서버 호출.
class DiaryInterviewRemoteDataSource implements DiaryInterviewDataSource {
  DiaryInterviewRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<InterviewTurnResult> sendTurn({
    required String userText,
    List<InterviewMessage> history = const [],
  }) async {
    // 서버(JSON)는 snake_case, 앱은 camelCase — 변환은 여기서만 한다.
    final json = await _apiClient.post(
      '/diary/interview/turn',
      body: {
        'user_text': userText,
        'history': [for (final m in history) m.toJson()],
      },
    );
    if (json['reply'] is! String) {
      throw const ServerException('탄카츄의 질문을 받지 못했어요.');
    }
    return InterviewTurnResult.fromJson(json);
  }

  @override
  Future<String?> refine({required List<InterviewMessage> messages}) async {
    final json = await _apiClient.post(
      '/diary/interview/refine',
      body: {
        'messages': [for (final m in messages) m.toJson()],
      },
    );
    final diary = json['diary'];
    return diary is String && diary.trim().isNotEmpty ? diary.trim() : null;
  }
}
