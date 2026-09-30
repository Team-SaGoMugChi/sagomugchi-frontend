import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/device_test_file.dart';
import '../../../baseline/data/models/baseline_profile.dart';
import '../models/fusion_result.dart';
import 'diary_analysis_data_source.dart';

/// 에뮬레이터 테스트용 — Step1 카메라 캡처 대신 기기에 넣어 둔 얼굴 사진으로
/// 감정 분석을 요청한다. 에뮬레이터가 PC 웹캠을 잡으면 PC 마이크 입력이 녹음
/// 시작 2초 뒤부터 0으로 끊겨서(2026-09-29 확인), 마이크만 쓰고 얼굴은 사진으로
/// 대신한다.
///
/// `--dart-define=ODDO_FACE_IMAGE_FILE=<파일 이름>`으로 실행할 때만 쓰인다
/// ([diaryAnalysisDataSourceProvider]). 파일 위치는 [deviceTestFile] — 같은 이름으로
/// 다시 push하면 다시 빌드하지 않고 표정을 바꿔 테스트할 수 있다.
class DiaryAnalysisFaceFileDataSource implements DiaryAnalysisDataSource {
  DiaryAnalysisFaceFileDataSource(this._fileName, this._inner);

  final String _fileName;
  final DiaryAnalysisDataSource _inner;

  @override
  Future<String> transcribe({required String voiceFilePath}) =>
      _inner.transcribe(voiceFilePath: voiceFilePath);

  @override
  Future<FusionResult> analyzeStep2({
    required String text,
    required String voiceFilePath,
    required String faceImagePath,
    required BaselineProfile baseline,
  }) async {
    final file = await deviceTestFile(_fileName);
    if (!await file.exists()) {
      throw AppException('테스트용 얼굴 사진이 없어요: ${file.path}');
    }
    return _inner.analyzeStep2(
      text: text,
      voiceFilePath: voiceFilePath,
      faceImagePath: file.path,
      baseline: baseline,
    );
  }
}
