import '../../../../core/utils/date_formatter.dart';
import 'video_archive_data_source.dart';

/// 테스트/더미 모드용 — 올리지 않고 경로만 기억한다.
class VideoArchiveDummyDataSource implements VideoArchiveDataSource {
  /// 경로 → 원래 영상 주소.
  final Map<String, String> archived = {};

  /// 영상 경로 → 원래 썸네일 주소.
  final Map<String, String> thumbnails = {};

  @override
  Future<String> archive({
    required DateTime date,
    required String sourceUrl,
    String? thumbnailUrl,
  }) async {
    final path = 'users/dummy/videos/${DateFormatter.dateKey(date)}.mp4';
    archived[path] = sourceUrl;
    if (thumbnailUrl != null) thumbnails[path] = thumbnailUrl;
    return path;
  }

  @override
  Future<String?> thumbnailUrl(String storagePath) async =>
      thumbnails[storagePath];

  @override
  Future<String> playableUrl(String storagePath) async =>
      archived[storagePath] ?? storagePath;
}
