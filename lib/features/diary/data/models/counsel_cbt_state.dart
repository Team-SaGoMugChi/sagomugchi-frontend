/// CBT 단계형 상담 상태 — 서버 `counsel_cbt.py`와 같은 단계 번호를 쓴다.
///
/// 0 지난 미션 확인 · 1 감정 확인 · 2 상황·자동적 사고 · 3 거리두기 ·
/// 4 대안 사고 · 5 행동 가이드. 앱은 직전 응답의 [stage]·[stageTurn]을 다음
/// 요청에 그대로 보내고, [extracted]는 턴마다 쌓아 상담 기록에 저장한다.
class CounselCbtState {
  const CounselCbtState({
    this.stage = 0,
    this.stageTurn = 0,
    this.extracted = const {},
    this.done = false,
  });

  final int stage;
  final int stageTurn;

  /// 단계마다 얻은 값 — emotionLabel, intensity, automaticThought, mission 등.
  final Map<String, dynamic> extracted;

  /// 5단계까지 끝나 회기가 종료됨.
  final bool done;

  /// 이번 회기에서 정한 미션. 다음 상담의 0단계(미션 확인)에 쓴다.
  String? get mission {
    final value = extracted['mission'];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 서버 응답의 `cbt`를 반영한다. 단계·턴은 서버 값으로 바꾸고, 얻은 값은 쌓는다.
  CounselCbtState merge(Map<String, dynamic> json) {
    final newValues = json['extracted'];
    return CounselCbtState(
      stage: (json['stage'] as num?)?.toInt() ?? stage,
      stageTurn: (json['stage_turn'] as num?)?.toInt() ?? stageTurn,
      extracted: {
        ...extracted,
        if (newValues is Map) ...newValues.cast<String, dynamic>(),
      },
      done: json['done'] as bool? ?? done,
    );
  }

  /// `POST /counsel/turn`의 `cbt` 요청 본문(서버는 snake_case).
  Map<String, dynamic> toRequestJson({
    required String style,
    String? lastMission,
  }) {
    final mission = lastMission?.trim();
    return {
      'stage': stage,
      'stage_turn': stageTurn,
      'style': style,
      if (mission != null && mission.isNotEmpty)
        'last_mission': mission.length > 200
            ? mission.substring(0, 200)
            : mission,
    };
  }

  /// 챗봇 말투로 상담 스타일을 고른다(서버 STYLE_PROMPTS 키).
  static String styleForTone(String? tone) => switch (tone?.trim()) {
    '차분하고 진중한' => 'analysis',
    '간결하고 솔직한' => 'goal',
    _ => 'empathy',
  };

  /// Firestore 저장용 — `counsel_sessions` 문서의 `cbt` 필드.
  Map<String, dynamic> toJson() => {
    'stage': stage,
    'stageTurn': stageTurn,
    'extracted': extracted,
    'done': done,
  };

  factory CounselCbtState.fromJson(Map<String, dynamic> json) =>
      CounselCbtState(
        stage: (json['stage'] as num?)?.toInt() ?? 0,
        stageTurn: (json['stageTurn'] as num?)?.toInt() ?? 0,
        extracted:
            (json['extracted'] as Map?)?.cast<String, dynamic>() ?? const {},
        done: json['done'] as bool? ?? false,
      );
}