import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/error/app_exception.dart';
import 'package:oddo/core/network/api_client.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/application/diary_handoff_controller.dart';
import 'package:oddo/features/diary/data/datasources/diary_handoff_remote_data_source.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/diary_handoff.dart';
import 'package:oddo/features/diary/data/models/diary_interview.dart';
import 'package:oddo/features/diary/data/models/fusion_result.dart';
import 'package:oddo/features/diary/data/repositories/diary_handoff_repository.dart';
import 'package:oddo/features/records/application/viewing_date_provider.dart';

const _fusion = FusionResult(
  emotionKeywords: ['상처', '기쁨'],
  emotionScores: {'상처': 55, '기쁨': 30},
  emotionIntensity: 64,
  textEmotionScores: {'상처': 0.6},
  voiceDelta: {},
  faceDelta: {},
  signals: ['목소리가 평소보다 작음'],
  incongruent: true,
);

const _conversation = [
  InterviewMessage(speaker: InterviewSpeaker.oddo, text: '오늘 어땠어요?'),
  InterviewMessage(speaker: InterviewSpeaker.user, text: '회의에서 속상했어요.'),
];

class _Client implements ApiClient {
  String? path;
  Object? body;
  Map<String, dynamic> response = {
    'video': {'schema': 'oddo.diary_emotion.v1'},
    'counsel': {'schema': 'oddo.counsel_context.v1'},
  };

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    this.path = path;
    this.body = body;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements DiaryHandoffRepository {
  Map<String, Object?>? built;
  ({DateTime date, DiaryHandoff handoff})? saved;
  Object? error;

  @override
  Future<DiaryHandoff> build({
    required DateTime date,
    required String transcript,
    String? diaryText,
    String? summary,
    Map<String, String?> slots = const {},
    List<InterviewMessage> conversation = const [],
    FusionResult? emotion,
  }) async {
    built = {
      'date': date,
      'transcript': transcript,
      'diaryText': diaryText,
      'summary': summary,
      'slots': slots,
      'conversation': conversation,
      'emotion': emotion,
    };
    if (error != null) throw error!;
    return const DiaryHandoff(video: {'v': 1}, counsel: {'c': 1});
  }

  @override
  Future<void> save({required DateTime date, required DiaryHandoff handoff}) async {
    saved = (date: date, handoff: handoff);
  }
}

void main() {
  group('handoff HTTP contract', () {
    test('posts the diary material in snake_case', () async {
      final client = _Client();
      final handoff = await DiaryHandoffRemoteDataSource(client).build(
        date: DateTime(2026, 9, 30),
        transcript: '회의에서 속상했어요.',
        diaryText: '회의에서 속상했다.',
        summary: '속상했던 하루였어요.',
        slots: const {'무엇을': '회의', '왜': null},
        conversation: _conversation,
        emotion: _fusion,
      );

      expect(client.path, '/diary/handoff');
      expect(client.body, {
        'date': '2026-09-30',
        'transcript': '회의에서 속상했어요.',
        'diary_text': '회의에서 속상했다.',
        'summary': '속상했던 하루였어요.',
        'slots': {'무엇을': '회의', '왜': null},
        'conversation': [
          {'speaker': 'oddo', 'text': '오늘 어땠어요?'},
          {'speaker': 'user', 'text': '회의에서 속상했어요.'},
        ],
        'emotion': {
          'keywords': ['상처', '기쁨'],
          'scores': {'상처': 55.0, '기쁨': 30.0},
          'intensity': 64,
          'signals': ['목소리가 평소보다 작음'],
          'incongruent': true,
        },
      });
      expect(handoff.video['schema'], 'oddo.diary_emotion.v1');
      expect(handoff.counsel['schema'], 'oddo.counsel_context.v1');
    });

    test('leaves out missing optional material', () async {
      final client = _Client();
      await DiaryHandoffRemoteDataSource(
        client,
      ).build(date: DateTime(2026, 9, 30), transcript: '회의요.');

      final body = client.body! as Map<String, Object?>;
      expect(body.containsKey('diary_text'), isFalse);
      expect(body.containsKey('summary'), isFalse);
      expect(body.containsKey('emotion'), isFalse);
    });

    test('rejects a response without both files', () async {
      final client = _Client()..response = {'video': {}};
      await expectLater(
        DiaryHandoffRemoteDataSource(
          client,
        ).build(date: DateTime(2026, 9, 30), transcript: '회의요.'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('handoff controller', () {
    late ProviderContainer container;
    late _Repository repository;

    setUp(() {
      repository = _Repository();
      container = ProviderContainer(
        overrides: [diaryHandoffRepositoryProvider.overrideWithValue(repository)],
      );
      container.read(viewingDateProvider.notifier).set(DateTime(2026, 9, 29));
    });
    tearDown(() => container.dispose());

    Future<void> submit() =>
        container.read(diaryHandoffControllerProvider.notifier).submit();

    test('builds from the draft and saves under the viewing date', () async {
      container.read(diaryDraftProvider.notifier)
        ..setTranscript('회의에서 속상했어요.')
        ..setInterviewMessages(_conversation)
        ..setInterviewSlots(const {'무엇을': '회의'})
        ..setDiaryText('회의에서 속상했다.')
        ..setSummary('속상했던 하루였어요.')
        ..setFusionResult(_fusion);

      await submit();

      expect(repository.built!['date'], DateTime(2026, 9, 29));
      expect(repository.built!['transcript'], '회의에서 속상했어요.');
      expect(repository.built!['diaryText'], '회의에서 속상했다.');
      expect(repository.built!['summary'], '속상했던 하루였어요.');
      expect(repository.built!['slots'], {'무엇을': '회의'});
      expect(repository.built!['conversation'], _conversation);
      expect(repository.built!['emotion'], same(_fusion));
      expect(repository.saved!.date, DateTime(2026, 9, 29));
      expect(repository.saved!.handoff.video, {'v': 1});
      expect(container.read(diaryHandoffControllerProvider).value, isNotNull);
    });

    test('does nothing without the diary answers', () async {
      await submit();

      expect(repository.built, isNull);
      expect(repository.saved, isNull);
    });

    test('keeps a failure in its state instead of throwing', () async {
      container.read(diaryDraftProvider.notifier).setTranscript('회의요.');
      repository.error = const NetworkException();

      await submit();

      expect(container.read(diaryHandoffControllerProvider).hasError, isTrue);
      expect(repository.saved, isNull);
    });
  });
}
