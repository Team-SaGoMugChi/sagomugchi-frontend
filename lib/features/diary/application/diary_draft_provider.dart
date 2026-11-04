import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/counsel_session.dart';
import '../data/models/diary_interview.dart';
import '../data/models/fusion_result.dart';
import '../data/models/video_rating.dart';

/// The in-progress diary run, carried across the write-flow steps until the
/// final "기록 완료하기" save.
///
/// - [transcript]: Step 1 말하기에서 사용자가 한 말(차례별 STT를 이어 붙인 원
///   답변). 감정 분석·영상·상담의 입력이라 다듬지 않는다.
/// - [interviewMessages]: Step 1에서 탄카츄와 나눈 대화 전체 — 40번 "대화
///   내용 보기"와 일기 정제의 재료.
/// - [interviewSlots]: 대화에서 채운 칸(육하원칙 + 기분) — 영상·상담 전달 JSON의 재료.
/// - [diaryText]: 대화를 일기 한 편으로 정제한 글(`/diary/interview/refine`).
///   Step 2 (확인하기)에서 사용자가 고치면 그 값으로 바뀐다. 보여주기용이다.
/// - [summary]: Step 1 대화(`/diary/interview/turn`)가 만든 일기 요약 —
///   38번 감정 분석 로딩 등에 보여준다.
/// - [recordingPath]: Step 1 (말하기)에서 녹음된 음성 파일 경로 —
///   Phase 4에서 AI 서버 업로드/분석에 사용.
/// - [faceImagePath], [faceImagePaths], [faceTimestampsMs]: Step 1에서 캡처한
///   정지 이미지와 합친 녹음 기준 시각 — 발화·무음 베이스라인 비교에 사용.
/// - [fusionResult]: 그 둘 + baseline을 서버(`/diary/step2/analyze`)에 보내서
///   받은 감정 키워드/점수/Δ. 아직 없으면(분석 전/실패) null — Step2 확인
///   화면은 이 경우 더미 콘텐츠로 폴백한다.
/// - [videoRating]: Step 3 완료 화면 "이 영상은 어땠나요?" 응답. 기록 완료 때
///   일기 문서와 함께 저장한다(Step 3 시점엔 일기 문서가 아직 없다).
/// - [counselMessages] / [counselStartedAt]: Step 4 상담에서 주고받은 대화와
///   시작 시각. 46번 화면의 "기록 완료하기"가 이걸 그대로 Firestore
///   `counsel_sessions/{yyyy-MM-dd}`에 저장한다.
class DiaryDraftState {
  const DiaryDraftState({
    this.transcript,
    this.interviewMessages = const [],
    this.interviewSlots = const {},
    this.diaryText,
    this.summary,
    this.recordingPath,
    this.faceImagePath,
    this.faceImagePaths = const [],
    this.faceTimestampsMs = const [],
    this.fusionResult,
    this.videoRating,
    this.counselMessages = const [],
    this.counselStartedAt,
  });

  final String? transcript;
  final List<InterviewMessage> interviewMessages;
  final Map<String, String?> interviewSlots;
  final String? diaryText;
  final String? summary;
  final String? recordingPath;
  final String? faceImagePath;
  final List<String> faceImagePaths;
  final List<int> faceTimestampsMs;
  final FusionResult? fusionResult;
  final VideoRating? videoRating;
  final List<CounselMessage> counselMessages;
  final DateTime? counselStartedAt;

  /// 영상을 기다리는 동안 앱을 꺼도 이어 쓸 수 있게 휴대폰에 남기는 값.
  /// 영상 평가·상담은 영상 완성 뒤에 생기므로 남기지 않는다.
  Map<String, dynamic> toJson() => {
    'transcript': transcript,
    'interview_messages': [for (final m in interviewMessages) m.toJson()],
    'interview_slots': interviewSlots,
    'diary_text': diaryText,
    'summary': summary,
    'recording_path': recordingPath,
    'face_image_path': faceImagePath,
    'face_image_paths': faceImagePaths,
    'face_timestamps_ms': faceTimestampsMs,
    'fusion_result': fusionResult?.toJson(),
  };

  factory DiaryDraftState.fromJson(Map<String, dynamic> json) {
    final fusion = json['fusion_result'];
    return DiaryDraftState(
      transcript: json['transcript'] as String?,
      interviewMessages: [
        for (final m in (json['interview_messages'] as List? ?? const []))
          InterviewMessage(
            speaker: InterviewSpeaker.values.byName(m['speaker'] as String),
            text: m['text'] as String,
          ),
      ],
      interviewSlots: Map<String, String?>.from(
        json['interview_slots'] as Map? ?? const {},
      ),
      diaryText: json['diary_text'] as String?,
      summary: json['summary'] as String?,
      recordingPath: json['recording_path'] as String?,
      faceImagePath: json['face_image_path'] as String?,
      faceImagePaths: List<String>.from(
        json['face_image_paths'] as List? ?? const [],
      ),
      faceTimestampsMs: List<int>.from(
        json['face_timestamps_ms'] as List? ?? const [],
      ),
      fusionResult: fusion is Map
          ? FusionResult.fromJson(Map<String, dynamic>.from(fusion))
          : null,
    );
  }

  DiaryDraftState copyWith({
    String? transcript,
    List<InterviewMessage>? interviewMessages,
    Map<String, String?>? interviewSlots,
    String? diaryText,
    String? summary,
    String? recordingPath,
    String? faceImagePath,
    List<String>? faceImagePaths,
    List<int>? faceTimestampsMs,
    FusionResult? fusionResult,
    VideoRating? videoRating,
    List<CounselMessage>? counselMessages,
    DateTime? counselStartedAt,
  }) => DiaryDraftState(
    transcript: transcript ?? this.transcript,
    interviewMessages: interviewMessages ?? this.interviewMessages,
    interviewSlots: interviewSlots ?? this.interviewSlots,
    diaryText: diaryText ?? this.diaryText,
    summary: summary ?? this.summary,
    recordingPath: recordingPath ?? this.recordingPath,
    faceImagePath: faceImagePath ?? this.faceImagePath,
    faceImagePaths: faceImagePaths ?? this.faceImagePaths,
    faceTimestampsMs: faceTimestampsMs ?? this.faceTimestampsMs,
    fusionResult: fusionResult ?? this.fusionResult,
    videoRating: videoRating ?? this.videoRating,
    counselMessages: counselMessages ?? this.counselMessages,
    counselStartedAt: counselStartedAt ?? this.counselStartedAt,
  );
}

class DiaryDraft extends Notifier<DiaryDraftState> {
  @override
  DiaryDraftState build() => const DiaryDraftState();

  void setTranscript(String transcript) =>
      state = state.copyWith(transcript: transcript);

  void setInterviewMessages(List<InterviewMessage> messages) =>
      state = state.copyWith(interviewMessages: List.unmodifiable(messages));

  void setInterviewSlots(Map<String, String?> slots) =>
      state = state.copyWith(interviewSlots: Map.unmodifiable(slots));

  void setDiaryText(String diaryText) =>
      state = state.copyWith(diaryText: diaryText);

  void setSummary(String summary) => state = state.copyWith(summary: summary);

  /// 새 녹음은 이전 녹음에서 나온 원문/대화/일기/요약/분석 결과를 무효로 만든다 —
  /// 남겨두면 Step1 분석이 옛 원문을 재사용한다. (copyWith는 null로 못 지워서 직접 생성)
  void setRecordingPath(String path) => state = DiaryDraftState(
    recordingPath: path,
    faceImagePath: state.faceImagePath,
    faceImagePaths: state.faceImagePaths,
    faceTimestampsMs: state.faceTimestampsMs,
    counselMessages: state.counselMessages,
    counselStartedAt: state.counselStartedAt,
  );

  void setFaceImagePath(String path) => state = state.copyWith(
    faceImagePath: path,
    faceImagePaths: const [],
    faceTimestampsMs: const [],
  );

  void clearFace() => state = DiaryDraftState(
    transcript: state.transcript,
    interviewMessages: state.interviewMessages,
    diaryText: state.diaryText,
    summary: state.summary,
    recordingPath: state.recordingPath,
    fusionResult: state.fusionResult,
    videoRating: state.videoRating,
    counselMessages: state.counselMessages,
    counselStartedAt: state.counselStartedAt,
  );

  void setFaceTimeline(List<String> paths, List<int> timestampsMs) {
    if (paths.length != timestampsMs.length) {
      throw ArgumentError('face timeline length');
    }
    state = state.copyWith(
      faceImagePath: paths.isEmpty ? null : paths.first,
      faceImagePaths: List.unmodifiable(paths),
      faceTimestampsMs: List.unmodifiable(timestampsMs),
    );
  }

  void setFusionResult(FusionResult result) =>
      state = state.copyWith(fusionResult: result);

  void setVideoRating(VideoRating rating) =>
      state = state.copyWith(videoRating: rating);

  /// Step4 상담 종료 시 호출 — 대화 전체와 시작 시각을 draft에 싣는다.
  void setCounsel({
    required List<CounselMessage> messages,
    DateTime? startedAt,
  }) => state = state.copyWith(
    counselMessages: messages,
    counselStartedAt: startedAt,
  );

  /// 홈에서 기다리던 일기를 이어 쓸 때 저장해 둔 값으로 되돌린다.
  void restore(DiaryDraftState saved) => state = saved;

  void clear() => state = const DiaryDraftState();
}

final diaryDraftProvider = NotifierProvider<DiaryDraft, DiaryDraftState>(
  DiaryDraft.new,
);
