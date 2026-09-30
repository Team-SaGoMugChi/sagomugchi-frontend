import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../baseline/data/baseline_providers.dart';
import '../data/diary_providers.dart';
import '../data/models/fusion_result.dart';
import 'diary_draft_provider.dart';

/// Step1(말하기)에서 모은 녹음을 원문으로 바꾸고(STT), 녹음/얼굴 캡처를
/// baseline과 비교해 감정을 뽑는 상태. 같은 시간에 탄카츄와의 대화를 일기
/// 한 편으로 정제해 draft에 싣는다.
///
/// idle은 `AsyncData(null)`로 표현한다 — 처리 화면 진입 시 자동으로 [submit]을
/// 호출하고, 실패하면 사용자가 재시도 버튼으로 다시 [submit]을 부를 수 있다
/// (baselineUploadController와 같은 모양).
class Step1AnalysisController extends Notifier<AsyncValue<FusionResult?>> {
  @override
  AsyncValue<FusionResult?> build() => const AsyncData(null);

  Future<void> submit() async {
    final draft = ref.read(diaryDraftProvider);
    final voicePath = draft.recordingPath;
    final facePath = draft.faceImagePath;

    if (voicePath == null || facePath == null) {
      state = AsyncError(
        const AppException('말하기 녹음 또는 얼굴 데이터를 찾을 수 없어요. 다시 녹음해주세요.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 일기 정제는 감정 분석과 동시에 — 기다리는 시간이 늘지 않게.
      final refining = _refineDiary();
      final baseline = await ref.read(baselineRepositoryProvider).fetchSaved();
      if (baseline == null) {
        throw const AppException('베이스라인 측정 정보를 찾을 수 없어요. 설정에서 다시 측정해주세요.');
      }
      if (!baseline.isAnalysisReady) {
        throw const AppException(
          '저장된 베이스라인이 현재 분석 기준과 맞지 않아요. 설정에서 다시 측정해주세요.',
        );
      }

      final repository = ref.read(diaryAnalysisRepositoryProvider);
      // 원문은 녹음당 한 번만 받는다 — 분석 단계에서 실패해 재시도할 때
      // CLOVA를 다시 호출(과금)하지 않도록 draft에 받아둔 걸 재사용한다.
      var transcript = draft.transcript;
      if (transcript == null) {
        transcript = await repository.transcribe(voiceFilePath: voicePath);
        ref.read(diaryDraftProvider.notifier).setTranscript(transcript);
      }

      final result = await repository.analyzeStep2(
        text: transcript,
        voiceFilePath: voicePath,
        faceImagePath: facePath,
        baseline: baseline,
      );
      ref.read(diaryDraftProvider.notifier).setFusionResult(result);
      await refining;
      return result;
    });
  }

  /// 탄카츄와 나눈 대화를 일기 한 편으로 정제해 draft에 싣는다(39번 "오늘의
  /// 일기"). 이미 있거나 대화가 없으면(더미 흐름 등) 건너뛴다. 실패해도
  /// 분석은 이어간다 — Step2는 원 답변을 보여준다.
  Future<void> _refineDiary() async {
    final draft = ref.read(diaryDraftProvider);
    if (draft.diaryText != null || draft.interviewMessages.isEmpty) return;
    try {
      final diary = await ref
          .read(diaryInterviewRepositoryProvider)
          .refine(messages: draft.interviewMessages);
      if (diary != null && ref.mounted) {
        ref.read(diaryDraftProvider.notifier).setDiaryText(diary);
      }
    } catch (_) {
      // 정제는 보여주기용이라 실패해도 기록 흐름을 막지 않는다.
    }
  }
}

final step1AnalysisControllerProvider =
    NotifierProvider<Step1AnalysisController, AsyncValue<FusionResult?>>(
      Step1AnalysisController.new,
    );
