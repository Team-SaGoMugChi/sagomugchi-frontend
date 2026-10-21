/// `POST /counsel/turn` 응답 — 상담봇 답변 한 줄과 위기 발화 여부.
///
/// 서버가 위기 표현을 먼저 걸러내면 [crisis]가 true이고, [reply]에는 일반
/// 상담 응답 대신 전문 기관 안내 문구가 담긴다 (서버 `counsel_guardrail.py`).
/// [riskAxis]는 위험의 종류다 — suicide | danger | harm_others | psychosis |
/// dependence, 위험이 없으면 null. 앱은 이 값으로 안내 연락처를 고른다.
class CounselTurnResult {
  const CounselTurnResult({
    required this.reply,
    this.crisis = false,
    this.riskAxis,
    this.usedDummyContext = false,
  });

  final String reply;
  final bool crisis;
  final String? riskAxis;
  final bool usedDummyContext;

  factory CounselTurnResult.fromJson(Map<String, dynamic> json) =>
      CounselTurnResult(
        reply: json['reply'] as String,
        crisis: json['crisis'] as bool? ?? false,
        riskAxis: json['risk_axis'] as String?,
        usedDummyContext: json['used_dummy_context'] as bool? ?? false,
      );
}