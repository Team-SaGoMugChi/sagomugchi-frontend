import '../../../../core/constants/app_durations.dart';
import '../models/video_job_status.dart';
import 'video_data_source.dart';

/// 테스트/더미 모드용 — 서버 없이 몇 번의 폴링 만에 완료된다.
///
/// 재생할 파일이 없으므로 완료 상태의 videoUrl은 null이다. 화면은 이 경우
/// 기존 플레이스홀더를 보여준다.
class VideoDummyDataSource implements VideoDataSource {
  static const _jobId = 'dummy-video-job';
  static const _stages = ['storyboard', 'images', 'videos', 'narration'];

  int _polls = 0;

  @override
  Future<VideoJobStatus> createJob({
    required String text,
    List<String>? emotionKeywords,
    Map<String, double>? emotionScores,
    int? emotionIntensity,
    Map<String, dynamic>? diaryHandoff,
  }) async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    _polls = 0;
    return _status();
  }

  @override
  Future<VideoJobStatus> fetchJob(String jobId) async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    _polls++;
    return _status();
  }

  VideoJobStatus _status() {
    if (_polls >= _stages.length) {
      return const VideoJobStatus(
        jobId: _jobId,
        state: VideoJobState.done,
        stage: 'done',
        progress: 1,
      );
    }
    return VideoJobStatus(
      jobId: _jobId,
      state: VideoJobState.running,
      stage: _stages[_polls],
      progress: _polls / _stages.length,
    );
  }
}
