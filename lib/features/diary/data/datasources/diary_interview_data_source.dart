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
}
