import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/error/app_exception.dart';
import 'package:oddo/core/network/api_client.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/application/diary_interview_controller.dart';
import 'package:oddo/features/diary/data/datasources/diary_interview_remote_data_source.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/diary_interview.dart';
import 'package:oddo/features/diary/data/repositories/diary_interview_repository.dart';

const _greeting = '오늘 어떤 일이 있었어요?';
const _keepGoing = '이어서 말해주세요.';

class _Repository implements DiaryInterviewRepository {
  final calls = <({String userText, List<InterviewMessage> history})>[];
  InterviewTurnResult result = const InterviewTurnResult(reply: '언제 있었어요?');
  Object? error;

  @override
  Future<InterviewTurnResult> sendTurn({
    required String userText,
    List<InterviewMessage> history = const [],
  }) async {
    calls.add((userText: userText, history: history));
    if (error != null) throw error!;
    return result;
  }
}

class _Client implements ApiClient {
  String? path;
  Object? body;
  Map<String, dynamic> response = {
    'reply': '누구와 함께였어요?',
    'done': false,
    'crisis': false,
    'slots': {'무엇을': '팀 회의', '누가': null},
    'missing': ['누가'],
    'summary': '오늘은 팀 회의가 있었던 하루였어요.',
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

void main() {
  group('diary interview controller', () {
    late ProviderContainer container;
    late _Repository repository;

    DiaryInterviewController controller() =>
        container.read(diaryInterviewControllerProvider.notifier);
    DiaryInterviewState state() =>
        container.read(diaryInterviewControllerProvider);

    Future<void> answer(String text, {bool askNext = true}) =>
        controller().addAnswer(
          recordingPath: '$text.wav',
          text: text,
          keepGoing: _keepGoing,
          askNext: askNext,
        );

    setUp(() {
      repository = _Repository();
      container = ProviderContainer(
        overrides: [
          diaryInterviewRepositoryProvider.overrideWithValue(repository),
        ],
      );
      // autoDispose — 화면처럼 구독해 둬야 차례 사이에 상태가 남는다.
      container.listen(diaryInterviewControllerProvider, (_, _) {});
      controller().start(_greeting);
    });
    tearDown(() => container.dispose());

    test('sends the answer with the greeting as history', () async {
      await answer('팀 회의에서 의견이 무시당했어요.');

      expect(repository.calls.single.userText, '팀 회의에서 의견이 무시당했어요.');
      expect(repository.calls.single.history.map((m) => m.text), [_greeting]);
      expect(state().messages.last.text, '언제 있었어요?');
      expect(state().messages.last.speaker, InterviewSpeaker.oddo);
      expect(state().waiting, isFalse);
    });

    test('transcript keeps only what the user said, turn by turn', () async {
      await answer('팀 회의가 있었어요.');
      await answer('어제 오후요.');

      expect(state().transcript, '팀 회의가 있었어요.\n어제 오후요.');
      expect(state().recordingPaths, ['팀 회의가 있었어요..wav', '어제 오후요..wav']);
    });

    test('stops asking after the server closes the interview', () async {
      repository.result = const InterviewTurnResult(
        reply: '이야기해줘서 고마워요.',
        done: true,
      );
      await answer('일주일 됐어요.');
      await answer('한 가지 더 있어요.');

      expect(repository.calls, hasLength(1));
      expect(state().done, isTrue);
      expect(state().messages.last.speaker, InterviewSpeaker.user);
      expect(state().recordingPaths, hasLength(2));
    });

    test('stops asking after a crisis reply', () async {
      repository.result = const InterviewTurnResult(
        reply: '109에서 24시간 이야기를 들어줘요.',
        crisis: true,
      );
      await answer('다 끝내고 싶어요.');
      await answer('그냥요.');

      expect(state().crisis, isTrue);
      expect(repository.calls, hasLength(1));
    });

    test('keeps the conversation going when the server fails', () async {
      repository.error = const NetworkException();
      await answer('오늘 발표했어요.');

      expect(state().messages.last.text, _keepGoing);
      expect(state().waiting, isFalse);
      expect(state().done, isFalse);
    });

    test('the last answer before hanging up is recorded without a question', () async {
      await answer('이제 끊을게요.', askNext: false);

      expect(repository.calls, isEmpty);
      expect(state().transcript, '이제 끊을게요.');
    });

    test('keeps the last known slots when a turn cannot tell them', () async {
      repository.result = const InterviewTurnResult(
        reply: '어디에서 있었던 일이에요?',
        slots: {'무엇을': '팀 회의', '어디서': null},
        missing: ['어디서'],
      );
      await answer('팀 회의가 있었어요.');
      repository.result = const InterviewTurnResult(reply: '그랬군요.');
      await answer('스터디룸이요.');

      expect(state().slots, {'무엇을': '팀 회의', '어디서': null});
    });

    test('keeps the latest summary and ignores turns without one', () async {
      repository.result = const InterviewTurnResult(
        reply: '어디에서 있었던 일이에요?',
        summary: '오늘은 팀 회의에서 의견이 무시당한 하루였어요.',
      );
      await answer('팀 회의가 있었어요.');
      repository.result = const InterviewTurnResult(
        reply: '누구와 함께였어요?',
        summary: '  ',
      );
      await answer('스터디룸이요.');

      expect(state().summary, '오늘은 팀 회의에서 의견이 무시당한 하루였어요.');
    });

    test('start does not reset an ongoing conversation', () async {
      await answer('팀 회의가 있었어요.');
      controller().start(_greeting);

      expect(state().messages, hasLength(3));
    });
  });

  group('interview HTTP contract', () {
    test('posts snake_case fields to the interview endpoint', () async {
      final client = _Client();
      final result = await DiaryInterviewRemoteDataSource(client).sendTurn(
        userText: '어제요.',
        history: const [
          InterviewMessage(speaker: InterviewSpeaker.oddo, text: _greeting),
        ],
      );

      expect(client.path, '/diary/interview/turn');
      expect(client.body, {
        'user_text': '어제요.',
        'history': [
          {'speaker': 'oddo', 'text': _greeting},
        ],
      });
      expect(result.reply, '누구와 함께였어요?');
      expect(result.done, isFalse);
      expect(result.slots, {'무엇을': '팀 회의', '누가': null});
      expect(result.missing, ['누가']);
      expect(result.summary, '오늘은 팀 회의가 있었던 하루였어요.');
    });

    test('reads a response without slots as unknown slots', () async {
      final client = _Client()..response = {'reply': '어디였어요?'};
      final result = await DiaryInterviewRemoteDataSource(
        client,
      ).sendTurn(userText: '어제요.');

      expect(result.slots, isEmpty);
      expect(result.missing, isEmpty);
      expect(result.summary, isNull);
    });
  });

  group('diary draft summary', () {
    test('a new recording drops the previous summary', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final draft = container.read(diaryDraftProvider.notifier)
        ..setRecordingPath('first.wav')
        ..setSummary('오늘은 회의가 있었던 하루였어요.');
      expect(container.read(diaryDraftProvider).summary, isNotNull);

      draft.setRecordingPath('second.wav');

      expect(container.read(diaryDraftProvider).summary, isNull);
    });

    test('rejects a response without a reply', () async {
      final client = _Client()..response = {};
      await expectLater(
        DiaryInterviewRemoteDataSource(client).sendTurn(userText: '어제요.'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
