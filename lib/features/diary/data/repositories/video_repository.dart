import '../models/video_job_status.dart';

/// Step3 영상 생성에서 앱이 필요로 하는 것.
abstract interface class VideoRepository {
  Future<VideoJobStatus> createJob({
    required String text,
    List<String>? emotionKeywords,
    Map<String, double>? emotionScores,
    int? emotionIntensity,
    Map<String, dynamic>? diaryHandoff,
  });

  Future<VideoJobStatus> fetchJob(String jobId);
}
