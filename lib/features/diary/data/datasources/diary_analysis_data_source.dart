import '../../../baseline/data/models/baseline_profile.dart';
import '../models/fusion_result.dart';

/// 일기 Step1(말하기)에서 모은 음성/얼굴을 baseline과 비교해 감정을 뽑는
/// 추상화 — AI 서버 `POST /stt/transcribe`와 `POST /diary/step2/analyze`를
/// 감싼다.
abstract interface class DiaryAnalysisDataSource {
  /// Step1 녹음을 Naver CLOVA Speech(서버 프록시)로 보내 원문 텍스트를 받는다.
  Future<String> transcribe({required String voiceFilePath});

  /// [text]는 [transcribe]로 받은 Step1 원문 — fusion이 텍스트 감정 분류에
  /// 쓴다.
  Future<FusionResult> analyzeStep2({
    required String text,
    required String voiceFilePath,
    required String faceImagePath,
    required BaselineProfile baseline,
  });
}
