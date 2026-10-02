/// 일기 기록(Step2 확인)이 끝난 뒤 다른 파트에 넘기는 JSON 두 개.
///
/// 서버 `POST /diary/handoff`가 만들고, 앱이 Firestore
/// `users/{uid}/handoffs/{yyyy-MM-dd}`에 저장한다(FIRESTORE_SCHEMA.md). 필드 뜻은
/// 각 JSON의 `설명` 블록에 한국어로 들어 있다 — 앱은 내용을 해석하지 않고 옮기기만 한다.
class DiaryHandoff {
  const DiaryHandoff({required this.video, required this.counsel});

  /// 영상 파트(Step3)용 — `oddo.diary_emotion.v1`: 원문·정제 일기·대화 칸,
  /// 장면(scenes)·전환점(turning_points)·문장별 감정.
  final Map<String, dynamic> video;

  /// 상담 파트(Step4)용 — `oddo.counsel_context.v1`: `/counsel/turn` 요청 필드
  /// 이름(emotions·signals·diary_summary·incongruent) 그대로 + 대화 칸·감정 흐름.
  final Map<String, dynamic> counsel;
}
