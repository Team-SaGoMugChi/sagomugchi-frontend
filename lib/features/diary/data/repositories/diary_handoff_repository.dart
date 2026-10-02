import '../models/diary_handoff.dart';
import '../models/diary_interview.dart';
import '../models/fusion_result.dart';

abstract interface class DiaryHandoffRepository {
  Future<DiaryHandoff> build({
    required DateTime date,
    required String transcript,
    String? diaryText,
    String? summary,
    Map<String, String?> slots = const {},
    List<InterviewMessage> conversation = const [],
    FusionResult? emotion,
  });

  Future<void> save({required DateTime date, required DiaryHandoff handoff});
}
