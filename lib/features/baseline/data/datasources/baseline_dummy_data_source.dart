import '../../../../core/constants/app_durations.dart';
import '../../../../data/dummy/baseline_dummy.dart';
import '../models/baseline_profile.dart';
import 'baseline_data_source.dart';

/// 테스트/더미 모드용 — 실제 업로드 없이 그럴듯한 프로필을 즉시 반환한다.
class BaselineDummyDataSource implements BaselineDataSource {
  @override
  Future<BaselineProfile> upload({
    required String voiceFilePath,
    required String faceImagePath,
    List<String> faceImagePaths = const [],
    List<int> faceTimestampsMs = const [],
    List<bool> facePromptFlags = const [],
  }) async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    return sampleBaseline(DateTime.now());
  }

  @override
  Future<BaselineProfile?> fetchSaved() async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    return sampleBaseline(DateTime.now());
  }
}
