import '../models/diary_interview.dart';

abstract interface class DiaryInterviewRepository {
  Future<InterviewTurnResult> sendTurn({
    required String userText,
    List<InterviewMessage> history = const [],
  });
}
