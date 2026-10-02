import '../datasources/diary_handoff_data_source.dart';
import '../models/diary_handoff.dart';
import '../models/diary_interview.dart';
import '../models/fusion_result.dart';
import 'diary_handoff_repository.dart';

class DiaryHandoffRepositoryImpl implements DiaryHandoffRepository {
  DiaryHandoffRepositoryImpl(this._dataSource);

  final DiaryHandoffDataSource _dataSource;

  @override
  Future<DiaryHandoff> build({
    required DateTime date,
    required String transcript,
    String? diaryText,
    String? summary,
    Map<String, String?> slots = const {},
    List<InterviewMessage> conversation = const [],
    FusionResult? emotion,
  }) {
    return _dataSource.build(
      date: date,
      transcript: transcript,
      diaryText: diaryText,
      summary: summary,
      slots: slots,
      conversation: conversation,
      emotion: emotion,
    );
  }

  @override
  Future<void> save({required DateTime date, required DiaryHandoff handoff}) {
    return _dataSource.save(date: date, handoff: handoff);
  }
}
