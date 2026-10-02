import '../datasources/video_data_source.dart';
import '../models/video_job_status.dart';
import 'video_repository.dart';

class VideoRepositoryImpl implements VideoRepository {
  VideoRepositoryImpl(this._dataSource);

  final VideoDataSource _dataSource;

  @override
  Future<VideoJobStatus> createJob({
    required String text,
    List<String>? emotionKeywords,
    Map<String, double>? emotionScores,
    int? emotionIntensity,
    Map<String, dynamic>? diaryHandoff,
  }) {
    return _dataSource.createJob(
      text: text,
      emotionKeywords: emotionKeywords,
      emotionScores: emotionScores,
      emotionIntensity: emotionIntensity,
      diaryHandoff: diaryHandoff,
    );
  }

  @override
  Future<VideoJobStatus> fetchJob(String jobId) => _dataSource.fetchJob(jobId);
}
