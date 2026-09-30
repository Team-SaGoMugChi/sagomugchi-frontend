/// 37번 말하기 대화의 고정 문구 (Step4의 `CounselCopy`와 같은 역할).
abstract final class DiaryInterviewCopy {
  /// 통화를 시작하면 탄카츄가 먼저 건네는 말. 서버에도 대화 기록으로 보낸다.
  static const String greeting =
      '안녕하세요, 탄카츄예요.\n오늘 어떤 일이 있었는지 편하게 이야기해줄래요?';

  /// 다음 질문을 기다리는 동안 말풍선에 띄운다.
  static const String thinking = '잠시만요, 들은 이야기를 정리하고 있어요…';

  /// 서버에서 질문을 받지 못했을 때 — 기록은 계속 이어간다.
  static const String keepGoing = '잘 들었어요. 더 하고 싶은 이야기가 있으면 이어서 말해주세요.';

  /// 37번 상단 상태 줄 — 지금 무엇을 하고 있는지 그대로 보여준다.
  static String callStatus({
    required bool recording,
    required bool transcribing,
    required bool waiting,
    required bool ending,
    required bool done,
    required bool crisis,
  }) {
    if (crisis) return '대화를 잠시 멈췄어요';
    if (ending) return '이야기를 정리하고 있어요';
    if (recording) return '듣고 있어요';
    if (transcribing) return '말을 옮기고 있어요';
    if (waiting) return '탄카츄가 질문을 고르고 있어요';
    if (done) return '이야기를 다 들었어요. 정리하러 갈게요';
    return '마이크를 누르고 말해보세요';
  }
}
