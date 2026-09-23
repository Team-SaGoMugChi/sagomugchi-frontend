/// `POST /counsel/turn` 응답 — 상담봇 답변 한 줄과 위기 발화 여부.
///
/// 서버가 위기 표현을 먼저 걸러내면 [crisis]가 true이고, [reply]에는 일반
/// 상담 응답 대신 전문 기관 안내 문구가 담긴다 (서버 `counsel_guardrail.py`).
class CounselTurnResult {
  const CounselTurnResult({required this.reply, this.crisis = false});

  final String reply;
  final bool crisis;

  factory CounselTurnResult.fromJson(Map<String, dynamic> json) =>
      CounselTurnResult(
        reply: json['reply'] as String,
        crisis: json['crisis'] as bool? ?? false,
      );
}
