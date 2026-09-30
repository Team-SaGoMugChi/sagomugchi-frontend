/// Who is speaking in the diary interview (37번 말하기 대화).
enum InterviewSpeaker { oddo, user }

/// 말하기 대화의 한 줄 — 서버 `InterviewMessage`와 1:1 대응.
class InterviewMessage {
  const InterviewMessage({required this.speaker, required this.text});

  final InterviewSpeaker speaker;
  final String text;

  Map<String, dynamic> toJson() => {'speaker': speaker.name, 'text': text};
}

/// `POST /diary/interview/turn` 응답 — 탄카츄가 할 말과 대화 상태.
///
/// 서버는 대화에서 육하원칙 칸([slots])을 채우고 빈 칸([missing])만 묻는다.
/// [done]이면 칸이 다 찼거나 질문 상한에 닿은 것 — 앱은 원문 확인으로 넘어간다.
/// [crisis]면 서버가 위기 표현을 먼저 걸러낸 것이고, [reply]에는 질문 대신
/// 전문 기관 안내가 담긴다 (서버 `counsel_guardrail.py` — 상담과 같은 기준).
class InterviewTurnResult {
  const InterviewTurnResult({
    required this.reply,
    this.done = false,
    this.crisis = false,
    this.slots = const {},
    this.missing = const [],
  });

  final String reply;
  final bool done;
  final bool crisis;

  /// 칸 이름(누가·언제·어디서·무엇을·어떻게·왜) → 사용자가 말한 내용, 빈 칸은
  /// null. 서버가 칸을 알 수 없던 차례(LLM 실패 등)면 비어 있다.
  final Map<String, String?> slots;
  final List<String> missing;

  factory InterviewTurnResult.fromJson(Map<String, dynamic> json) =>
      InterviewTurnResult(
        reply: json['reply'] as String,
        done: json['done'] as bool? ?? false,
        crisis: json['crisis'] as bool? ?? false,
        slots: (json['slots'] as Map<String, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key, value as String?),
        ),
        missing: (json['missing'] as List<dynamic>? ?? const [])
            .cast<String>(),
      );
}
