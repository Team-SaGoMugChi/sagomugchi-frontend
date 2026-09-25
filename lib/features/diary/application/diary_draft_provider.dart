import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/counsel_session.dart';
import '../data/models/fusion_result.dart';

/// The in-progress diary run, carried across the write-flow steps until the
/// final "기록 완료하기" save.
///
/// - [transcript]: Step 1 녹음의 STT 원문. Step 2 (확인하기)에서 사용자가
///   수정하면 그 값으로 바뀐다.
/// - [recordingPath]: Step 1 (말하기)에서 녹음된 음성 파일 경로 —
///   Phase 4에서 AI 서버 업로드/분석에 사용.
/// - [faceImagePath]: Step 1 종료 시점에 캡처한 정지 이미지 — baseline과
///   같은 방식으로 표정 분석에 사용.
/// - [fusionResult]: 그 둘 + baseline을 서버(`/diary/step2/analyze`)에 보내서
///   받은 감정 키워드/점수/Δ. 아직 없으면(분석 전/실패) null — Step2 확인
///   화면은 이 경우 더미 콘텐츠로 폴백한다.
/// - [counselMessages] / [counselStartedAt]: Step 4 상담에서 주고받은 대화와
///   시작 시각. 46번 화면의 "기록 완료하기"가 이걸 그대로 Firestore
///   `counsel_sessions/{yyyy-MM-dd}`에 저장한다.
///
/// TODO(Phase 5): grow into a full draft (summary) once the AI pipeline
/// produces real values for that too.
class DiaryDraftState {
  const DiaryDraftState({
    this.transcript,
    this.recordingPath,
    this.faceImagePath,
    this.fusionResult,
    this.counselMessages = const [],
    this.counselStartedAt,
  });

  final String? transcript;
  final String? recordingPath;
  final String? faceImagePath;
  final FusionResult? fusionResult;
  final List<CounselMessage> counselMessages;
  final DateTime? counselStartedAt;

  DiaryDraftState copyWith({
    String? transcript,
    String? recordingPath,
    String? faceImagePath,
    FusionResult? fusionResult,
    List<CounselMessage>? counselMessages,
    DateTime? counselStartedAt,
  }) => DiaryDraftState(
    transcript: transcript ?? this.transcript,
    recordingPath: recordingPath ?? this.recordingPath,
    faceImagePath: faceImagePath ?? this.faceImagePath,
    fusionResult: fusionResult ?? this.fusionResult,
    counselMessages: counselMessages ?? this.counselMessages,
    counselStartedAt: counselStartedAt ?? this.counselStartedAt,
  );
}

class DiaryDraft extends Notifier<DiaryDraftState> {
  @override
  DiaryDraftState build() => const DiaryDraftState();

  void setTranscript(String transcript) =>
      state = state.copyWith(transcript: transcript);

  /// 새 녹음은 이전 녹음에서 나온 원문/분석 결과를 무효로 만든다 — 남겨두면
  /// Step1 분석이 옛 원문을 재사용한다. (copyWith는 null로 못 지워서 직접 생성)
  void setRecordingPath(String path) => state = DiaryDraftState(
    recordingPath: path,
    faceImagePath: state.faceImagePath,
    counselMessages: state.counselMessages,
    counselStartedAt: state.counselStartedAt,
  );

  void setFaceImagePath(String path) =>
      state = state.copyWith(faceImagePath: path);

  void setFusionResult(FusionResult result) =>
      state = state.copyWith(fusionResult: result);

  /// Step4 상담 종료 시 호출 — 대화 전체와 시작 시각을 draft에 싣는다.
  void setCounsel({
    required List<CounselMessage> messages,
    DateTime? startedAt,
  }) => state = state.copyWith(
    counselMessages: messages,
    counselStartedAt: startedAt,
  );

  void clear() => state = const DiaryDraftState();
}

final diaryDraftProvider = NotifierProvider<DiaryDraft, DiaryDraftState>(
  DiaryDraft.new,
);
