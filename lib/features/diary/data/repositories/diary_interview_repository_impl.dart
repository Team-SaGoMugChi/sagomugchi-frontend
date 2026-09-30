import '../datasources/diary_interview_data_source.dart';
import '../models/diary_interview.dart';
import 'diary_interview_repository.dart';

class DiaryInterviewRepositoryImpl implements DiaryInterviewRepository {
  DiaryInterviewRepositoryImpl(this._dataSource);

  final DiaryInterviewDataSource _dataSource;

  @override
  Future<InterviewTurnResult> sendTurn({
    required String userText,
    List<InterviewMessage> history = const [],
  }) {
    return _dataSource.sendTurn(userText: userText, history: history);
  }
}
