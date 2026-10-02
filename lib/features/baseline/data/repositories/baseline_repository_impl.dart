import '../datasources/baseline_data_source.dart';
import '../models/baseline_profile.dart';
import 'baseline_repository.dart';

class BaselineRepositoryImpl implements BaselineRepository {
  BaselineRepositoryImpl(this._dataSource);

  final BaselineDataSource _dataSource;

  @override
  Future<BaselineProfile> submitMeasurement({
    required String voiceFilePath,
    required String faceImagePath,
    List<String> faceImagePaths = const [],
    List<int> faceTimestampsMs = const [],
    List<bool> facePromptFlags = const [],
  }) {
    return _dataSource.upload(
      voiceFilePath: voiceFilePath,
      faceImagePath: faceImagePath,
      faceImagePaths: faceImagePaths,
      faceTimestampsMs: faceTimestampsMs,
      facePromptFlags: facePromptFlags,
    );
  }

  @override
  Future<BaselineProfile?> fetchSaved() => _dataSource.fetchSaved();
}
