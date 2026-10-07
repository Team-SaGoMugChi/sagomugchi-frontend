import '../../../../core/utils/date_formatter.dart';
import 'video_archive_data_source.dart';

/// 테스트/더미 모드용 — 올리지 않고 경로만 기억한다.
class VideoArchiveDummyDataSource implements VideoArchiveDataSource {
  /// 경로 → 원래 영상 주소.
  final Map<String, String> archived = {};

  @override
  Future<String> archive({
    required DateTime date,
    required String sourceUrl,
  }) async {
    final path = 'users/dummy/videos/${DateFormatter.dateKey(date)}.mp4';
    archived[path] = sourceUrl;
    return path;
  }

  @override
  Future<String> playableUrl(String storagePath) async =>
      archived[storagePath] ?? storagePath;
}
