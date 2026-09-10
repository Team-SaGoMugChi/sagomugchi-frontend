/// 상담 한 턴 — AI 서버 `POST /counsel/turn` 하나를 감싼다
abstract interface class CounselDataSource {
  /// [userText]는 사용자가 방금 한 말. 상담봇 답변 한 줄을 돌려준다
  Future<String> sendTurn({required String userText});
}