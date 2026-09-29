/// Step4 상담(영상통화·채팅)에서 함께 쓰는 고정 문구.
///
/// 예전에는 `DiaryFlowDummy`에 있었지만 더미가 아니라 실제 화면 문구라서
/// 상담 기능 안으로 옮겼다.
abstract final class CounselCopy {
  /// 대화 시작 전 탄카츄의 첫 인사.
  static const String greeting =
      '천천히 이야기해도 괜찮아요.\n오늘 가장 마음에 남는 순간을 함께 돌아봐요.';

  /// 상담봇 응답을 기다리는 동안 말풍선에 띄운다.
  static const String thinking = '잠시만요, 생각하고 있어요…';

  /// 44번 상단 상태 줄 — 지금 무엇을 하고 있는지 그대로 보여준다.
  static String callStatus({
    required bool recording,
    required bool transcribing,
    required bool sending,
    required bool crisis,
  }) {
    if (crisis) return '상담을 잠시 멈췄어요';
    if (recording) return '듣고 있어요';
    if (transcribing) return '말을 옮기고 있어요';
    if (sending) return '탄카츄가 답을 생각하고 있어요';
    return '마이크를 누르고 말해보세요';
  }
}