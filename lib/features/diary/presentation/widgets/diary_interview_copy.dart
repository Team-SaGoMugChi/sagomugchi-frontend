/// 37번 말하기 대화의 고정 문구 (Step4의 `CounselCopy`와 같은 역할).
abstract final class DiaryInterviewCopy {
  /// 통화를 시작하면 탄카츄가 먼저 건네는 말. 서버에도 대화 기록으로 보낸다.
  static const String greeting =
      '안녕하세요, 탄카츄예요.\n오늘 어떤 일이 있었는지 편하게 이야기해줄래요?';

  /// 다음 질문을 기다리는 동안 말풍선에 띄운다.
  static const String thinking = '잠시만요, 들은 이야기를 정리하고 있어요…';

  /// 서버에서 질문을 받지 못했을 때 — 기록은 계속 이어간다.
  static const String keepGoing = '잘 들었어요. 더 하고 싶은 이야기가 있으면 이어서 말해주세요.';

  /// 37번 상단 상태 줄 — 통화 상대가 하는 말처럼 짧게. 녹음·STT·서버 같은
  /// 처리 단계는 드러내지 않는다(말을 옮기는 중과 질문을 기다리는 중은 사용자
  /// 입장에선 같은 "생각하는 중"이다).
  static String callStatus({
    required bool speaking,
    required bool listenFailed,
    required bool recording,
    required bool transcribing,
    required bool waiting,
    required bool ending,
    required bool done,
    required bool crisis,
  }) {
    if (crisis) return '대화를 잠시 멈췄어요';
    if (ending) return '통화를 마무리하고 있어요';
    if (recording) return '듣고 있어요';
    if (transcribing || waiting) return '생각하고 있어요';
    if (done) return '이야기 잘 들었어요';
    if (speaking) return '통화 중';
    if (listenFailed) return '말하기를 눌러 이어가세요';
    // 탄카츄 말이 끝나고 녹음이 켜지기까지의 짧은 틈 — 곧 듣는다.
    return '듣고 있어요';
  }

  /// 좌상단 감정 게이지 아래 — 아직 인식된 감정이 없을 때.
  static const String emotionUnknown = '—';
}
