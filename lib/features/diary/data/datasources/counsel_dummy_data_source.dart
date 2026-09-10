import '../../../../core/constants/app_durations.dart';
import 'counsel_data_source.dart';

/// 테스트/더미 모드용 — 서버 없이 즉시 답한다.
class CounselDummyDataSource implements CounselDataSource {
  @override
  Future<String> sendTurn({required String userText}) async {
    await Future<void>.delayed(AppDurations.dummyLatency);
    return '그랬군요. 조금 더 이야기해줄래요?';
  }
}