import 'dart:convert';

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
import 'package:oddo/features/diary/data/models/diary_interview.dart';
import 'package:oddo/features/diary/data/models/fusion_result.dart';
import 'package:oddo/features/diary/data/repositories/diary_analysis_repository.dart';
import 'package:oddo/features/diary/data/repositories/diary_interview_repository.dart';

final _baseline = BaselineProfile(
  voice: const {
    'pitchMean': 220,
    'f0Std': 28,
    'speechRate': 4.2,
    'voicedRatio': 0.61,
    'durationSec': 352,
    'energyMean': 0.031,
    'windowPitchMean': 220,
    'windowPitchStd': 10,
    'windowEnergyMean': 0.031,
    'windowEnergyStd': 0.005,
    'windowSpeechRate': 4.2,
    'windowSpeechRateStd': 0.4,
    'windowCount': 100,
    'windowUsedCount': 90,
  },
  face: const {
    'eyeAspectRatio': 0.28,
    'mouthAspectRatio': 0.11,
    'mouthWidthRatio': 1.42,
    'eyebrowRaiseRatio': 0.38,
    'au1LogMean': -2,
    'au1LogStd': 0,
    'au2LogMean': -2,
    'au2LogStd': 0,
    'au4LogMean': -2,
    'au4LogStd': 0,
    'au5LogMean': -2,
    'au5LogStd': 0,
    'au6LogMean': -2,
    'au6LogStd': 0,
    'au7LogMean': -2,
    'au7LogStd': 0,
    'au12LogMean': -2,
    'au12LogStd': 0,
    'au15LogMean': -2,
    'au15LogStd': 0,
    'au17LogMean': -2,
    'au17LogStd': 0,
    'auFrameCount': 1,
    'auTotalFrames': 1,
  },
  measuredAt: DateTime.utc(2026, 9, 15),
  featureVersion: 2,
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

class _FixedBaselineRepository implements BaselineRepository {
  const _FixedBaselineRepository(this.profile);

  final BaselineProfile? profile;

  @override
  Future<BaselineProfile?> fetchSaved() async => profile;

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

class _InterviewRepository implements DiaryInterviewRepository {
  final refined = <List<InterviewMessage>>[];
  String? diary = '오늘 발표를 마쳤다.';
  Object? error;

  @override
  Future<String?> refine({required List<InterviewMessage> messages}) async {
    refined.add(messages);
    if (error != null) throw error!;
    return diary;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements ApiClient {
  Object? error;
  Map<String, dynamic> response = {'text': '오늘 발표가 끝났어요.'};
  String? path;
  Map<String, String>? fields;
  Map<String, String>? filePaths;

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    Map<String, String> filePaths = const {},
    Duration? receiveTimeout,
  }) async {
    this.path = path;
    this.fields = fields;
    this.filePaths = filePaths;
    if (error != null) throw error!;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User? get currentUser => null;

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
    late _InterviewRepository interview;

    setUp(() {
      repository = _AnalysisRepository();
      interview = _InterviewRepository();
      container = ProviderContainer(
        overrides: [
          baselineRepositoryProvider.overrideWithValue(_BaselineRepository()),
          diaryAnalysisRepositoryProvider.overrideWithValue(repository),
          diaryInterviewRepositoryProvider.overrideWithValue(interview),
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

    test('rejects a legacy baseline before transcribing', () async {
      final legacy = BaselineProfile(
        voice: _baseline.voice,
        face: _baseline.face,
        measuredAt: _baseline.measuredAt,
      );
      final legacyContainer = ProviderContainer(
        overrides: [
          baselineRepositoryProvider.overrideWithValue(
            _FixedBaselineRepository(legacy),
          ),
          diaryAnalysisRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(legacyContainer.dispose);
      legacyContainer.read(diaryDraftProvider.notifier)
        ..setRecordingPath('voice.wav')
        ..setFaceImagePath('face.jpg');

      await legacyContainer
          .read(step1AnalysisControllerProvider.notifier)
          .submit();

      expect(repository.transcribed, isEmpty);
      expect(
        legacyContainer.read(step1AnalysisControllerProvider).error,
        isA<AppException>().having(
          (error) => error.message,
          'message',
          contains('다시 측정'),
        ),
      );
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

    group('with a conversation', () {
      const conversation = [
        InterviewMessage(speaker: InterviewSpeaker.oddo, text: '오늘 어땠어요?'),
        InterviewMessage(speaker: InterviewSpeaker.user, text: '발표를 마쳤어요.'),
      ];

      setUp(() {
        container.read(diaryDraftProvider.notifier)
          ..setTranscript('발표를 마쳤어요.')
          ..setInterviewMessages(conversation);
      });

      test('refines the conversation into a diary during analysis', () async {
        await submit();

        expect(interview.refined.single.map((m) => m.text), [
          '오늘 어땠어요?',
          '발표를 마쳤어요.',
        ]);
        expect(container.read(diaryDraftProvider).diaryText, '오늘 발표를 마쳤다.');
        // 감정 분석은 정제본이 아니라 원 답변으로 한다.
        expect(repository.analyzedTexts, ['발표를 마쳤어요.']);
      });

      test('analysis still succeeds when refining fails', () async {
        interview.error = const NetworkException();
        await submit();

        expect(container.read(step1AnalysisControllerProvider).value, _fusion);
        expect(container.read(diaryDraftProvider).diaryText, isNull);
      });

      test('retry does not refine again once a diary exists', () async {
        repository.analyzeError = const NetworkException();
        await submit();
        repository.analyzeError = null;
        await submit();

        expect(interview.refined, hasLength(1));
      });
    });

    test('does not refine without a conversation', () async {
      await submit();
      expect(interview.refined, isEmpty);
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
      expect(client.path, '/stt/transcribe');
      expect(client.filePaths, {'voice_file': 'voice.wav'});
    });

    test('sends the complete baseline contract to analysis', () async {
      client.response = {
        'emotion_keywords': <String>[],
        'emotion_scores': <String, double>{},
        'emotion_intensity': 0,
        'text_emotion_scores': <String, double>{},
        'voice_delta': <String, dynamic>{},
        'face_delta': <String, dynamic>{},
      };

      await DiaryAnalysisRemoteDataSource(client, auth: _Auth()).analyzeStep2(
        text: '오늘 발표가 끝났어요.',
        voiceFilePath: 'voice.wav',
        faceImagePath: 'face.jpg',
        baseline: _baseline,
      );

      expect(client.path, '/diary/step2/analyze');
      expect(client.fields?['baseline_feature_version'], '2');
      expect(
        client.fields?['baseline_measured_at'],
        '2026-09-15T00:00:00.000Z',
      );
      expect(jsonDecode(client.fields!['baseline_voice']!), _baseline.voice);
      expect(jsonDecode(client.fields!['baseline_face']!), _baseline.face);
    });

    test(
      'shows the server remeasurement message for an invalid baseline',
      () async {
        client.error = _serverError(422, {
          'detail': {
            'code': 'baseline_remeasurement_required',
            'message': '음성 기준값이 불완전해요. 다시 측정해주세요.',
          },
        });

        await expectLater(
          DiaryAnalysisRemoteDataSource(client, auth: _Auth()).analyzeStep2(
            text: '오늘 발표가 끝났어요.',
            voiceFilePath: 'voice.wav',
            faceImagePath: 'face.jpg',
            baseline: _baseline,
          ),
          throwsA(
            isA<ServerException>().having(
              (error) => error.message,
              'message',
              '음성 기준값이 불완전해요. 다시 측정해주세요.',
            ),
          ),
        );
      },
    );

    test('shows the server retake message for invalid diary media', () async {
      client.error = _serverError(422, {
        'detail': {
          'code': 'face_not_detected',
          'message': '얼굴을 확인하지 못했어요. 다시 촬영해주세요.',
        },
      });

      await expectLater(
        DiaryAnalysisRemoteDataSource(client, auth: _Auth()).analyzeStep2(
          text: '오늘 발표가 끝났어요.',
          voiceFilePath: 'voice.wav',
          faceImagePath: 'face.jpg',
          baseline: _baseline,
        ),
        throwsA(
          isA<ServerException>().having(
            (error) => error.message,
            'message',
            '얼굴을 확인하지 못했어요. 다시 촬영해주세요.',
          ),
        ),
      );
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
