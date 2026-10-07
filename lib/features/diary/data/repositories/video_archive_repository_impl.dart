import '../datasources/video_archive_data_source.dart';
import 'video_archive_repository.dart';

class VideoArchiveRepositoryImpl implements VideoArchiveRepository {
  VideoArchiveRepositoryImpl(this._dataSource);

  final VideoArchiveDataSource _dataSource;

  @override
  Future<String> archive({
    required DateTime date,
    required String sourceUrl,
    String? thumbnailUrl,
  }) => _dataSource.archive(
    date: date,
    sourceUrl: sourceUrl,
    thumbnailUrl: thumbnailUrl,
  );

  @override
  Future<String> playableUrl(String storagePath) =>
      _dataSource.playableUrl(storagePath);

  @override
  Future<String?> thumbnailUrl(String storagePath) =>
      _dataSource.thumbnailUrl(storagePath);
}
