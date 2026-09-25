import '../datasources/counsel_data_source.dart';
import '../models/counsel_report.dart';
import '../models/counsel_session.dart';
import '../models/counsel_turn_result.dart';
import 'counsel_repository.dart';

class CounselRepositoryImpl implements CounselRepository {
  CounselRepositoryImpl(this._dataSource);

  final CounselDataSource _dataSource;

  @override
  Future<CounselTurnResult> sendTurn({
    required String userText,
    List<CounselMessage> history = const [],
    Map<String, double>? emotions,
    Map<String, dynamic>? persona,
  }) {
    return _dataSource.sendTurn(
      userText: userText,
      history: history,
      emotions: emotions,
      persona: persona,
    );
  }

  @override
  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
  }) {
    return _dataSource.fetchReport(
      messages: messages,
      emotions: emotions,
      diarySummary: diarySummary,
    );
  }
}
