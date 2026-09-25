import '../../../baseline/data/models/baseline_profile.dart';
import '../models/fusion_result.dart';

abstract interface class DiaryAnalysisRepository {
  Future<String> transcribe({required String voiceFilePath});

  Future<FusionResult> analyzeStep2({
    required String text,
    required String voiceFilePath,
    required String faceImagePath,
    required BaselineProfile baseline,
  });
}
