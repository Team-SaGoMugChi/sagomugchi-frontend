import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/error/app_exception.dart';
import 'package:oddo/core/network/api_client.dart';
import 'package:oddo/features/baseline/data/baseline_providers.dart';
import 'package:oddo/features/baseline/data/models/baseline_profile.dart';
import 'package:oddo/features/baseline/data/repositories/baseline_repository.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/application/step1_analysis_controller.dart';
import 'package:oddo/features/diary/data/datasources/diary_analysis_remote_data_source.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/fusion_result.dart';
import 'package:oddo/features/diary/data/repositories/diary_analysis_repository.dart';

final _baseline = BaselineProfile(
  voice: const {'pitchMean': 220},
  face: const {'eyeAspectRatio': 0.28},
  measuredAt: DateTime.utc(2026, 9, 15),
);

const _fusion = FusionResult(
  emotionKeywords: ['슬픔'],
  emotionScores: {'슬픔': 100},
  emotionIntensity: 60,
  textEmotionScores: {'슬픔': 1},
  voiceDelta: {},
  faceDelta: {},
);

class _BaselineRepository implements BaselineRepository {
  @override
  Future<BaselineProfile?> fetchSaved() async => _baseline;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AnalysisRepository implements DiaryAnalysisRepository {
  final transcribed = <String>[];
  final analyzedTexts = <String>[];
  Object? analyzeError;

  @override
  Future<String> transcribe({required String voiceFilePath}) async {
    transcribed.add(voiceFilePath);
    return '$voiceFilePath 원문';
  }

  @override
  Future<FusionResult> analyzeStep2({
    required String text,
    required String voiceFilePath,
    required String faceImagePath,
    required BaselineProfile baseline,
  }) async {
    analyzedTexts.add(text);
    if (analyzeError != null) throw analyzeError!;
    return _fusion;
  }
}

class _Client implements ApiClient {
  Object? error;
  Map<String, dynamic> response = {'text': '오늘 발표가 끝났어요.'};

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    Map<String, String> filePaths = const {},
  }) async {
    expect(path, '/stt/transcribe');
    expect(filePaths, {'voice_file': 'voice.wav'});
    if (error != null) throw error!;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ServerException _serverError(int status, Object? data) {
  final request = RequestOptions(path: '/stt/transcribe');
  return ServerException(
    'Server responded $status',
    DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: status,
        data: data,
      ),
    ),
  );
}

void main() {
  group('Step1 STT flow', () {
    late ProviderContainer container;
    late _AnalysisRepository repository;

    setUp(() {
      repository = _AnalysisRepository();
      container = ProviderContainer(
        overrides: [
          baselineRepositoryProvider.overrideWithValue(_BaselineRepository()),
          diaryAnalysisRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.read(diaryDraftProvider.notifier)
        ..setRecordingPath('voice.wav')
        ..setFaceImagePath('face.jpg');
    });
    tearDown(() => container.dispose());

    Future<void> submit() =>
        container.read(step1AnalysisControllerProvider.notifier).submit();

    test('analyzes the STT transcript and keeps it in the draft', () async {
      await submit();
      expect(repository.analyzedTexts, ['voice.wav 원문']);
      expect(container.read(diaryDraftProvider).transcript, 'voice.wav 원문');
      expect(container.read(diaryDraftProvider).fusionResult, same(_fusion));
    });

    test('retry after analysis failure does not transcribe again', () async {
      repository.analyzeError = const NetworkException();
      await submit();
      expect(
        container.read(step1AnalysisControllerProvider).error,
        isA<NetworkException>(),
      );
      repository.analyzeError = null;
      await submit();
      expect(repository.transcribed, ['voice.wav']);
      expect(repository.analyzedTexts, ['voice.wav 원문', 'voice.wav 원문']);
    });

    test('new recording drops the previous transcript', () async {
      await submit();
      container.read(diaryDraftProvider.notifier).setRecordingPath('next.wav');
      expect(container.read(diaryDraftProvider).transcript, isNull);
      expect(container.read(diaryDraftProvider).fusionResult, isNull);
      await submit();
      expect(repository.transcribed, ['voice.wav', 'next.wav']);
      expect(repository.analyzedTexts.last, 'next.wav 원문');
    });
  });

  group('STT HTTP contract', () {
    late _Client client;
    setUp(() => client = _Client());

    Future<String> transcribe() => DiaryAnalysisRemoteDataSource(
      client,
      auth: _Auth(),
    ).transcribe(voiceFilePath: 'voice.wav');

    test('returns recognized text', () async {
      expect(await transcribe(), '오늘 발표가 끝났어요.');
    });

    test('shows the server message when speech is not recognized', () async {
      client.error = _serverError(422, {
        'detail': {
          'code': 'speech_not_recognized',
          'message': '말소리를 알아듣지 못했어요. 다시 녹음해주세요.',
        },
      });
      await expectLater(
        transcribe(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            '말소리를 알아듣지 못했어요. 다시 녹음해주세요.',
          ),
        ),
      );
    });

    test('keeps other server failures unchanged', () async {
      client.error = _serverError(500, 'Internal Server Error');
      await expectLater(
        transcribe(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Server responded 500',
          ),
        ),
      );
    });

    test('rejects a response without text', () async {
      client.response = {};
      await expectLater(transcribe(), throwsA(isA<ServerException>()));
    });
  });
}
