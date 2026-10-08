import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/network/api_client.dart';
import 'package:oddo/features/diary/application/counsel_controller.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/application/diary_handoff_controller.dart';
import 'package:oddo/features/diary/data/datasources/counsel_remote_data_source.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/counsel_report.dart';
import 'package:oddo/features/diary/data/models/counsel_session.dart';
import 'package:oddo/features/diary/data/models/counsel_turn_result.dart';
import 'package:oddo/features/diary/data/models/diary_handoff.dart';
import 'package:oddo/features/diary/data/repositories/counsel_repository.dart';

const _slots = <String, String?>{
  '무엇을': '팀 회의에서 낸 의견이 그냥 넘어감',
  '어디서': null,
  '왜': '  ',
  '그때 기분': '서운했어',
};

class _Client implements ApiClient {
  String? path;
  Object? body;

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    this.path = path;
    this.body = body;
    if (path == '/counsel/report') {
      return {'headline': '서운했던 회의', 'summary': '회의에서 서운했어요.'};
    }
    return {'reply': '서운하셨군요.', 'crisis': false, 'used_dummy_context': false};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements CounselRepository {
  Map<String, dynamic>? sent;

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
  }) async {
    sent = {'slots': slots, 'emotionArc': emotionArc};
    return const CounselTurnResult(reply: '응답');
  }

  @override
  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
    Map<String, String?>? slots,
  }) async {
    sent = {'slots': slots};
    return const CounselReport(headline: '리포트', summary: '요약');
  }
}

/// Step2에서 이미 전달 JSON을 만들어 둔 상태.
class _ReadyHandoff extends DiaryHandoffController {
  @override
  AsyncValue<DiaryHandoff?> build() => const AsyncData(
    DiaryHandoff(
      video: <String, dynamic>{},
      counsel: <String, dynamic>{'emotion_arc': ' 서운함 → 가라앉음 '},
    ),
  );
}

void main() {
  group('handoff context for counseling', () {
    test('keeps only filled slots', () {
      expect(filledCounselSlots(_slots), {
        '무엇을': '팀 회의에서 낸 의견이 그냥 넘어감',
        '그때 기분': '서운했어',
      });
      expect(filledCounselSlots(const {'어디서': null}), isNull);
      expect(filledCounselSlots(null), isNull);
    });

    test('turn request carries filled slots and emotion arc', () async {
      final client = _Client();
      await CounselRemoteDataSource(client).sendTurn(
        userText: '회의 생각이 계속 나',
        slots: _slots,
        emotionArc: ' 서운함 → 가라앉음 ',
      );

      final body = client.body! as Map<String, dynamic>;
      expect(body['slots'], {
        '무엇을': '팀 회의에서 낸 의견이 그냥 넘어감',
        '그때 기분': '서운했어',
      });
      expect(body['emotion_arc'], '서운함 → 가라앉음');
    });

    test('turn request omits empty handoff context', () async {
      final client = _Client();
      await CounselRemoteDataSource(client).sendTurn(
        userText: '안녕',
        slots: const {'어디서': null},
        emotionArc: '  ',
      );

      final body = client.body! as Map<String, dynamic>;
      expect(body.containsKey('slots'), isFalse);
      expect(body.containsKey('emotion_arc'), isFalse);
    });

    test('report request carries filled slots', () async {
      final client = _Client();
      await CounselRemoteDataSource(client).fetchReport(
        messages: const [
          CounselMessage(speaker: CounselSpeaker.user, text: '서운했어'),
        ],
        slots: _slots,
      );

      expect(client.path, '/counsel/report');
      expect((client.body! as Map<String, dynamic>)['slots'], {
        '무엇을': '팀 회의에서 낸 의견이 그냥 넘어감',
        '그때 기분': '서운했어',
      });
    });

    test('controller forwards draft slots and handoff emotion arc', () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          counselRepositoryProvider.overrideWithValue(repository),
          diaryHandoffControllerProvider.overrideWith(_ReadyHandoff.new),
        ],
      );
      addTearDown(container.dispose);
      container.read(diaryDraftProvider.notifier).setInterviewSlots(_slots);

      await container
          .read(counselControllerProvider.notifier)
          .sendTurn('회의 생각이 계속 나');

      expect(repository.sent?['slots'], _slots);
      expect(repository.sent?['emotionArc'], '서운함 → 가라앉음');
    });

    test('controller works without a handoff yet', () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [counselRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(counselControllerProvider.notifier)
          .sendTurn('안녕');

      expect(repository.sent?['emotionArc'], isNull);
    });
  });
}