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
  }) {
    return _dataSource.upload(
      voiceFilePath: voiceFilePath,
      faceImagePath: faceImagePath,
      faceImagePaths: faceImagePaths,
    );
  }

  @override
  Future<BaselineProfile?> fetchSaved() => _dataSource.fetchSaved();
}
