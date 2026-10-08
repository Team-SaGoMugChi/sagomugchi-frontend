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
    List<String>? signals,
    String? diarySummary,
    bool incongruent = false,
    Map<String, dynamic>? persona,
    Map<String, dynamic>? psychProfile,
    Map<String, String?>? slots,
    String? emotionArc,
  }) {
    return _dataSource.sendTurn(
      userText: userText,
      history: history,
      emotions: emotions,
      signals: signals,
      diarySummary: diarySummary,
      incongruent: incongruent,
      persona: persona,
      psychProfile: psychProfile,
      slots: slots,
      emotionArc: emotionArc,
    );
  }

  @override
  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
    Map<String, String?>? slots,
  }) {
    return _dataSource.fetchReport(
      messages: messages,
      emotions: emotions,
      diarySummary: diarySummary,
      slots: slots,
    );
  }
}