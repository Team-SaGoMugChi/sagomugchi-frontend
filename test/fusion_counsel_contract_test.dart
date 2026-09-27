import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/network/api_client.dart';
import 'package:oddo/features/diary/application/counsel_controller.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/data/datasources/counsel_remote_data_source.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/counsel_session.dart';
import 'package:oddo/features/diary/data/models/counsel_turn_result.dart';
import 'package:oddo/features/diary/data/models/fusion_result.dart';
import 'package:oddo/features/diary/data/repositories/counsel_repository.dart';
import 'package:oddo/features/persona/data/models/persona_config.dart';
import 'package:oddo/features/persona/data/persona_providers.dart';

Map<String, dynamic> _fusionJson({bool includeCounselContext = true}) => {
  'emotion_keywords': ['불안'],
  'emotion_scores': {'불안': 72.0},
  'emotion_intensity': 68,
  'text_emotion_scores': {'불안': 0.72},
  'voice_delta': <String, dynamic>{},
  'face_delta': <String, dynamic>{},
  if (includeCounselContext) ...{
    'signals': ['말 속도가 평소보다 빠름'],
    'incongruent': true,
  },
};

class _Client implements ApiClient {
  String? path;
  Object? body;
  bool usedDummyContext = false;

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    this.path = path;
    this.body = body;
    return {
      'reply': '조금 더 이야기해줄래요?',
      'crisis': false,
      'used_dummy_context': usedDummyContext,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CounselRepository implements CounselRepository {
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
  }) async {
    sent = {
      'userText': userText,
      'history': history,
      'emotions': emotions,
      'signals': signals,
      'diarySummary': diarySummary,
      'incongruent': incongruent,
      'persona': persona,
      'psychProfile': psychProfile,
    };
    return const CounselTurnResult(reply: '응답');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('fusion to counsel contract', () {
    test('parses server-generated counseling context', () {
      final fusion = FusionResult.fromJson(_fusionJson());

      expect(fusion.signals, ['말 속도가 평소보다 빠름']);
      expect(fusion.incongruent, isTrue);
    });

    test('keeps compatibility with an older fusion response', () {
      final fusion = FusionResult.fromJson(
        _fusionJson(includeCounselContext: false),
      );

      expect(fusion.signals, isEmpty);
      expect(fusion.incongruent, isFalse);
    });

    test('rejects out-of-range emotion scores', () {
      final response = _fusionJson();
      response['emotion_scores'] = {'불안': 120.0};

      expect(
        () => FusionResult.fromJson(response),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-finite feature deltas', () {
      final response = _fusionJson();
      response['voice_delta'] = {
        'pitchMean': {
          'baseline_value': 220.0,
          'current_value': double.nan,
          'delta': 10.0,
          'relative_delta': 0.05,
        },
      };

      expect(
        () => FusionResult.fromJson(response),
        throwsA(isA<FormatException>()),
      );
    });

    test('serializes the complete context for the counseling API', () async {
      final client = _Client();
      final result = await CounselRemoteDataSource(client).sendTurn(
        userText: '발표가 걱정돼요.',
        history: const [
          CounselMessage(speaker: CounselSpeaker.oddo, text: '무슨 일이 있었나요?'),
        ],
        emotions: const {'불안': 72.0},
        signals: const ['말 속도가 평소보다 빠름'],
        diarySummary: '내일 발표가 있어서 긴장된다고 적음',
        incongruent: true,
        persona: const {
          'name': '오디',
          'tone': '따뜻한',
          'traits': ['공감'],
        },
      );

      expect(client.path, '/counsel/turn');
      expect(client.body, {
        'user_text': '발표가 걱정돼요.',
        'history': [
          {'speaker': 'oddo', 'text': '무슨 일이 있었나요?'},
        ],
        'emotions': {'불안': 72.0},
        'signals': ['말 속도가 평소보다 빠름'],
        'diary_summary': '내일 발표가 있어서 긴장된다고 적음',
        'incongruent': true,
        'persona': {
          'name': '오디',
          'tone': '따뜻한',
          'traits': ['공감'],
        },
      });
      expect(result.usedDummyContext, isFalse);
    });

    test('rejects a counseling response built with dummy context', () async {
      final client = _Client()..usedDummyContext = true;

      await expectLater(
        CounselRemoteDataSource(client).sendTurn(
          userText: '발표가 걱정돼요.',
          emotions: const {'불안': 72.0},
          signals: const ['말 속도가 평소보다 빠름'],
          diarySummary: '내일 발표가 있어서 긴장된다고 적음',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('테스트용 맥락'),
          ),
        ),
      );
    });

    test(
      'controller forwards the draft analysis without reinterpreting it',
      () async {
        final repository = _CounselRepository();
        final persona = PersonaConfig(
          name: '오디',
          tone: '따뜻한',
          traits: const ['공감'],
          updatedAt: DateTime.utc(2026, 9, 26),
        );
        final container = ProviderContainer(
          overrides: [
            counselRepositoryProvider.overrideWithValue(repository),
            personaConfigProvider.overrideWith((ref) async => persona),
          ],
        );
        addTearDown(container.dispose);
        container.read(diaryDraftProvider.notifier)
          ..setTranscript('내일 발표가 있어서 긴장돼요.')
          ..setFusionResult(FusionResult.fromJson(_fusionJson()));

        await container
            .read(counselControllerProvider.notifier)
            .sendTurn('어떻게 하면 좋을까요?');

        expect(repository.sent?['emotions'], {'불안': 72.0});
        expect(repository.sent?['signals'], ['말 속도가 평소보다 빠름']);
        expect(repository.sent?['diarySummary'], '내일 발표가 있어서 긴장돼요.');
        expect(repository.sent?['incongruent'], isTrue);
        expect(repository.sent?['persona'], {
          'name': '오디',
          'tone': '따뜻한',
          'traits': ['공감'],
        });
      },
    );
  });
}
