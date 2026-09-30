import '../models/diary_interview.dart';

/// 일기 말하기 대화(37번) — AI 서버 `POST /diary/interview/turn`을 감싼다.
///
/// 감정 분석(`DiaryAnalysisDataSource`)과 따로 둔다 — 대화는 질문만 주고받고,
/// 분석은 대화가 끝난 뒤 답변을 모아 한 번 한다.
abstract interface class DiaryInterviewDataSource {
  /// 지금까지의 대화([history])와 방금 한 말([userText])을 보내고 탄카츄의
  /// 다음 말(질문 또는 마무리)을 받는다.
  Future<InterviewTurnResult> sendTurn({
    required String userText,
    List<InterviewMessage> history = const [],
  });

  /// 대화 전체(`POST /diary/interview/refine`)를 일기 한 편으로 정제한다 —
  /// 39번 "오늘의 일기"에 보여주는 용도. 서버가 만들지 못하면 null.
  Future<String?> refine({required List<InterviewMessage> messages});
}
