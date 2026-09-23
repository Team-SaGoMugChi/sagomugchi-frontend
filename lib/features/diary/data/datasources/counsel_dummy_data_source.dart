import '../../../../core/constants/app_durations.dart';
import '../models/counsel_session.dart';
import '../models/counsel_turn_result.dart';
import 'counsel_data_source.dart';

/// 테스트/더미 모드용 — 서버 없이 즉시 답한다.
class CounselDummyDataSource implements CounselDataSource {
  @override
  Future<CounselTurnResult> sendTurn({
    required String userText,
    List<CounselMessage> history = const [],
    Map<String, double>? emotions,
    Map<String, dynamic>? persona,
  }) async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    return const CounselTurnResult(reply: '그랬군요. 조금 더 이야기해줄래요?');
  }
}
