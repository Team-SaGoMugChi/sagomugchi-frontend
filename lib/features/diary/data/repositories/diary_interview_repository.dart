import '../models/diary_interview.dart';

abstract interface class DiaryInterviewRepository {
  Future<InterviewTurnResult> sendTurn({
    required String userText,
    List<InterviewMessage> history = const [],
  });

  Future<AnswerEmotion> analyzeAnswer({required String userText});

  Future<String?> refine({required List<InterviewMessage> messages});
}
