import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/video_job_status.dart';
import 'video_data_source.dart';

/// 실제 AI 서버 호출.
class VideoRemoteDataSource implements VideoDataSource {
  VideoRemoteDataSource(this._apiClient, {required String baseUrl})
    : _baseUrl = baseUrl;

  final ApiClient _apiClient;

  /// 서버는 영상 경로를 상대 경로로 준다 — 플레이어용 절대 URL을 만들 때 쓴다.
  final String _baseUrl;

  @override
  Future<VideoJobStatus> createJob({
    required String text,
    List<String>? emotionKeywords,
    Map<String, double>? emotionScores,
    int? emotionIntensity,
  }) async {
    // 서버(JSON)는 snake_case, 앱은 camelCase — 변환은 여기서만 한다.
    final json = await _apiClient.post(
      '/video/jobs',
      body: {
        'text': text,
        if (emotionKeywords != null && emotionKeywords.isNotEmpty)
          'emotion_keywords': emotionKeywords,
        if (emotionScores != null && emotionScores.isNotEmpty)
          'emotion_scores': emotionScores,
        'emotion_intensity': ?emotionIntensity,
      },
    );
    return _parse(json);
  }

  @override
  Future<VideoJobStatus> fetchJob(String jobId) async {
    final json = await _apiClient.get('/video/jobs/$jobId');
    return _parse(json);
  }

  VideoJobStatus _parse(Map<String, dynamic> json) {
    if (json['job_id'] is! String) {
      throw const ServerException('영상 작업 응답을 처리하지 못했어요.');
    }
    return VideoJobStatus.fromJson(json, baseUrl: _baseUrl);
  }
}
