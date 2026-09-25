import '../models/counsel_report.dart';
import '../models/counsel_session.dart';
import '../models/counsel_turn_result.dart';

/// 상담 서버 호출 — `POST /counsel/turn`, `POST /counsel/report`.
abstract interface class CounselDataSource {
  /// [userText]는 사용자가 방금 한 말.
  ///
  /// [history]는 이번 턴 이전까지의 대화(오래된 순), [emotions]는 Step2 분석의
  /// 감정 라벨별 점수, [persona]는 `meta/persona` 설정이다. 셋 다 없어도
  /// 상담은 동작하며, 있으면 서버가 프롬프트에 반영한다.
  Future<CounselTurnResult> sendTurn({
    required String userText,
    List<CounselMessage> history,
    Map<String, double>? emotions,
    Map<String, dynamic>? persona,
  });

  /// 상담이 끝난 뒤 대화를 보내 리포트를 받는다.
  ///
  /// [messages]는 주고받은 대화 전체, [emotions]는 Step2 분석 점수,
  /// [diarySummary]는 오늘 일기 내용이다. 대화만 있으면 동작한다.
  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
  });
}
