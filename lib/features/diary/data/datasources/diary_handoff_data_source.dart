import '../models/diary_handoff.dart';
import '../models/diary_interview.dart';
import '../models/fusion_result.dart';

/// 영상·상담 파트에 넘길 JSON을 만들고(`POST /diary/handoff`) 저장한다
/// (Firestore `users/{uid}/handoffs/{yyyy-MM-dd}`).
abstract interface class DiaryHandoffDataSource {
  Future<DiaryHandoff> build({
    required DateTime date,
    required String transcript,
    String? diaryText,
    String? summary,
    Map<String, String?> slots = const {},
    List<InterviewMessage> conversation = const [],
    FusionResult? emotion,
  });

  /// 같은 날짜로 다시 저장하면 덮어쓴다.
  Future<void> save({required DateTime date, required DiaryHandoff handoff});
}
