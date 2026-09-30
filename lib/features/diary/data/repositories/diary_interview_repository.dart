import '../models/diary_interview.dart';

abstract interface class DiaryInterviewRepository {
  Future<InterviewTurnResult> sendTurn({
    required String userText,
    List<InterviewMessage> history = const [],
  });

  Future<String?> refine({required List<InterviewMessage> messages});
}
