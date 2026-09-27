import '../models/counsel_report.dart';
import '../models/counsel_session.dart';
import '../models/counsel_turn_result.dart';

/// 상담 대화에서 앱이 필요로 하는 것.
abstract interface class CounselRepository {
  Future<CounselTurnResult> sendTurn({
    required String userText,
    List<CounselMessage> history,
    Map<String, double>? emotions,
    List<String>? signals,
    String? diarySummary,
    bool incongruent,
    Map<String, dynamic>? persona,
    Map<String, dynamic>? psychProfile,
  });

  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
  });
}
