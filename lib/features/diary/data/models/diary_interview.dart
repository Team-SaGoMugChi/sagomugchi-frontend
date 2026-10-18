/// Who is speaking in the diary interview (37번 말하기 대화).
enum InterviewSpeaker { oddo, user }

/// 말하기 대화의 한 줄 — 서버 `InterviewMessage`와 1:1 대응.
class InterviewMessage {
  const InterviewMessage({required this.speaker, required this.text});

  final InterviewSpeaker speaker;
  final String text;

  Map<String, dynamic> toJson() => {'speaker': speaker.name, 'text': text};
}

/// `POST /diary/interview/emotion` 응답 — 통화 중 답변 하나의 텍스트 감정.
///
/// 37번 실시간 감정 분석 패널에 보여주기만 하고 저장하지 않는다. 기록에 남는
/// 감정은 통화가 끝난 뒤의 Step2 분석 결과다. 6종 라벨은 Step2와 같다.
class AnswerEmotion {
  const AnswerEmotion({
    required this.scores,
    this.dominantEmotion,
    this.confidence = 0,
  });

  /// 6종 감정(기쁨·슬픔·분노·불안·상처·당황) → 상대 점수(합 1). 판단 불가면 모두 0.
  final Map<String, double> scores;

  /// 대표 감정. 근거가 부족하면(판단 불가) null.
  final String? dominantEmotion;

  /// 대표 감정이 얼마나 뚜렷하게 인식됐는지(0~1, 모델 근거 점수) — 패널의
  /// 세로 게이지. 보정된 정확도나 측정된 감정 세기가 아니다. 판단 불가면 0.
  final double confidence;

  factory AnswerEmotion.fromJson(Map<String, dynamic> json) => AnswerEmotion(
    scores: (json['scores'] as Map<String, dynamic>? ?? const {}).map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ),
    dominantEmotion: json['dominant_emotion'] as String?,
    confidence: ((json['confidence'] as num?)?.toDouble() ?? 0).clamp(0, 1),
  );
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
    this.summary,
  });

  final String reply;
  final bool done;
  final bool crisis;

  /// 칸 이름(누가·언제·어디서·무엇을·어떻게·왜) → 사용자가 말한 내용, 빈 칸은
  /// null. 서버가 칸을 알 수 없던 차례(LLM 실패 등)면 비어 있다.
  final Map<String, String?> slots;
  final List<String> missing;

  /// 지금까지 들은 이야기의 일기 요약(1~2문장). 보여주기용이고 감정 분석
  /// 입력이 아니다. 서버가 못 만든 차례면 null.
  final String? summary;

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
        summary: json['summary'] as String?,
      );
}
