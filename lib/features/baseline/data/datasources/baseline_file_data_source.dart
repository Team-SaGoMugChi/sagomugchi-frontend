import 'dart:convert';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/device_test_file.dart';
import '../models/baseline_profile.dart';
import 'baseline_data_source.dart';

/// 에뮬레이터 테스트용 — Firestore `meta/baseline` 대신 기기에 넣어 둔 baseline
/// JSON(Firestore 문서와 같은 모양: voice/face/measuredAt/featureVersion)을 읽는다.
///
/// `--dart-define=ODDO_BASELINE_FILE=<파일 이름>`으로 실행할 때만 쓰인다
/// ([baselineDataSourceProvider]). 파일 위치는 [deviceTestFile].
///
/// 측정([upload])은 실제 서버로 그대로 보낸다. 측정 결과는 Firestore에 저장되지만
/// 이 모드에서는 [fetchSaved]가 계속 파일을 읽는다.
class BaselineFileDataSource implements BaselineDataSource {
  BaselineFileDataSource(this._fileName, this._uploader);

  final String _fileName;
  final BaselineDataSource _uploader;

  @override
  Future<BaselineProfile> upload({
    required String voiceFilePath,
    required String faceImagePath,
    List<String> faceImagePaths = const [],
    List<int> faceTimestampsMs = const [],
    List<bool> facePromptFlags = const [],
  }) => _uploader.upload(
    voiceFilePath: voiceFilePath,
    faceImagePath: faceImagePath,
    faceImagePaths: faceImagePaths,
    faceTimestampsMs: faceTimestampsMs,
    facePromptFlags: facePromptFlags,
  );

  @override
  Future<BaselineProfile?> fetchSaved() async {
    final file = await deviceTestFile(_fileName);
    if (!await file.exists()) {
      throw AppException('테스트용 baseline 파일이 없어요: ${file.path}');
    }
    try {
      final json = jsonDecode(await file.readAsString());
      return BaselineProfile.fromJson(Map<String, dynamic>.from(json as Map));
    } catch (e) {
      throw AppException('테스트용 baseline 파일을 읽지 못했어요: $_fileName', e);
    }
  }
}
