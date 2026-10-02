import '../models/video_job_status.dart';

/// Step3 영상 생성 서버 호출 — `POST /video/jobs`, `GET /video/jobs/{id}`.
abstract interface class VideoDataSource {
  /// 일기 원문과 Step2 분석 결과로 영상 생성 작업을 등록한다.
  ///
  /// 감정 값은 `/diary/step2/analyze` 응답을 그대로 넘긴다. 없으면 서버가
  /// 원문만으로 스토리보드를 만든다. [diaryHandoff]는 일기 기록 뒤 만든 영상
  /// 전달 JSON(`oddo.diary_emotion.v1`) — 앱은 해석하지 않고 그대로 싣는다.
  Future<VideoJobStatus> createJob({
    required String text,
    List<String>? emotionKeywords,
    Map<String, double>? emotionScores,
    int? emotionIntensity,
    Map<String, dynamic>? diaryHandoff,
  });

  Future<VideoJobStatus> fetchJob(String jobId);
}
