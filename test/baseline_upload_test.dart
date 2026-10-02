import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/error/app_exception.dart';
import 'package:oddo/core/network/api_client.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/baseline/application/baseline_face_frames_provider.dart';
import 'package:oddo/features/baseline/application/baseline_face_image_provider.dart';
import 'package:oddo/features/baseline/application/baseline_recording_provider.dart';
import 'package:oddo/features/baseline/application/baseline_upload_controller.dart';
import 'package:oddo/features/baseline/data/baseline_providers.dart';
import 'package:oddo/features/baseline/data/datasources/baseline_api.dart';
import 'package:oddo/features/baseline/data/models/baseline_measurement_exception.dart';
import 'package:oddo/features/baseline/data/models/baseline_profile.dart';
import 'package:oddo/features/baseline/data/repositories/baseline_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _profile = BaselineProfile(
  voice: const {'pitchMean': 220, 'energyMean': 0.3},
  face: const {'eyeAspectRatio': 0.28},
  measuredAt: DateTime.utc(2026, 9, 15),
);

class _Repository implements BaselineRepository {
  int calls = 0;
  List<String> expectedFaces = const ['face.jpg'];
  List<int> expectedTimes = const [];
  List<bool> expectedPromptFlags = const [];
  Future<BaselineProfile> Function() response = () async => _profile;

  @override
  Future<BaselineProfile> submitMeasurement({
    required String voiceFilePath,
    required String faceImagePath,
    List<String> faceImagePaths = const [],
    List<int> faceTimestampsMs = const [],
    List<bool> facePromptFlags = const [],
  }) {
    calls++;
    expect(voiceFilePath, 'voice.wav');
    expect(faceImagePath, expectedFaces.first);
    expect(faceImagePaths, expectedFaces);
    expect(faceTimestampsMs, expectedTimes);
    expect(facePromptFlags, expectedPromptFlags);
    return response();
  }

  @override
  Future<BaselineProfile?> fetchSaved() async => null;
}

class _Client implements ApiClient {
  Object? error;
  int? featureVersion;
  Duration? receiveTimeout;
  List<String> expectedFaces = const ['face.jpg'];
  String? expectedTimeline;

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    Map<String, String> filePaths = const {},
    Map<String, List<String>> fileListPaths = const {},
    Duration? receiveTimeout,
  }) async {
    expect(path, '/baseline');
    final expectedFields = {'user_id': 'user-1'};
    if (expectedTimeline != null) {
      expectedFields['face_timeline'] = expectedTimeline!;
    }
    expect(fields, expectedFields);
    expect(filePaths, {'voice_file': 'voice.wav'});
    expect(fileListPaths, {'face_images': expectedFaces});
    this.receiveTimeout = receiveTimeout;
    if (error != null) throw error!;
    return {
      'voice': _profile.voice,
      'face': _profile.face,
      'measured_at': _profile.measuredAt.toIso8601String(),
      if (featureVersion != null) 'feature_version': featureVersion,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('measurement lifecycle', () {
    late ProviderContainer container;
    late _Repository repository;
    late BaselineUploadController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = _Repository();
      final prefs = await SharedPreferences.getInstance();
      addTearDown(prefs.clear);
      container = ProviderContainer(
        overrides: [
          baselineRepositoryProvider.overrideWithValue(repository),
          localStoreProvider.overrideWithValue(LocalStore(prefs)),
        ],
      );
      controller = container.read(baselineUploadControllerProvider.notifier);
    });
    tearDown(() => container.dispose());

    void setFiles() {
      container.read(baselineRecordingProvider.notifier).set('voice.wav');
      container.read(baselineFaceImageProvider.notifier).set('face.jpg');
    }

    test('missing captures require remeasurement without an upload', () async {
      await controller.submit();
      expect(repository.calls, 0);
      expect(
        container.read(baselineUploadControllerProvider).error,
        isA<BaselineMeasurementException>(),
      );
    });

    test('new measurement clears both files and previous success', () async {
      setFiles();
      await controller.submit();
      controller.startMeasurement();
      expect(container.read(baselineRecordingProvider), isNull);
      expect(container.read(baselineFaceImageProvider), isNull);
      expect(
        container.read(baselineUploadControllerProvider).asData?.value,
        isNull,
      );
      container.read(baselineRecordingProvider.notifier).set('voice.wav');
      await controller.submit();
      expect(repository.calls, 1); // Old face must never complete the new pair.
    });

    test('repeated submit while pending sends only once', () async {
      setFiles();
      final pending = Completer<BaselineProfile>();
      repository.response = () => pending.future;
      final first = controller.submit();
      await controller.submit();
      expect(repository.calls, 1);
      pending.complete(_profile);
      await first;
      expect(
        container.read(baselineUploadControllerProvider).asData?.value,
        same(_profile),
      );
    });

    test('late response cannot complete a newer measurement', () async {
      setFiles();
      final pending = Completer<BaselineProfile>();
      repository.response = () => pending.future;
      final first = controller.submit();
      controller.startMeasurement();
      pending.complete(_profile);
      await first;
      expect(
        container.read(baselineUploadControllerProvider).asData?.value,
        isNull,
      );
    });

    test('network failure retains files for retry', () async {
      setFiles();
      repository.response = () async => throw const NetworkException();
      await controller.submit();
      expect(
        container.read(baselineUploadControllerProvider).error,
        isA<NetworkException>(),
      );
      repository.response = () async => _profile;
      await controller.submit();
      expect(repository.calls, 2);
      expect(
        container.read(baselineUploadControllerProvider).asData?.value,
        same(_profile),
      );
    });

    test('multiple face captures remain available for retry', () async {
      container.read(baselineRecordingProvider.notifier).set('voice.wav');
      container.read(baselineFaceFramesProvider.notifier)
        ..add('first.jpg', timestampMs: 1000)
        ..add('last.jpg', timestampMs: 2000, promptSpeaking: true);
      repository.expectedFaces = const ['first.jpg', 'last.jpg'];
      repository.expectedTimes = const [1000, 2000];
      repository.expectedPromptFlags = const [false, true];
      repository.response = () async => throw const NetworkException();
      await controller.submit();
      expect(
        container.read(baselineFaceFramesProvider),
        repository.expectedFaces,
      );
      repository.response = () async => _profile;
      await controller.submit();
      expect(repository.calls, 2);
      expect(container.read(baselineFaceFramesProvider), isEmpty);
    });
  });

  group('baseline HTTP contract', () {
    late _Client client;
    setUp(() => client = _Client());

    Future<BaselineProfile> upload() => BaselineApi(client).upload(
      userId: 'user-1',
      voiceFilePath: 'voice.wav',
      faceImagePath: 'face.jpg',
    );

    test('maps saved response to profile', () async {
      final result = await upload();
      expect(result.voice, _profile.voice);
      expect(result.face, _profile.face);
      expect(result.measuredAt, _profile.measuredAt);
      expect(result.featureVersion, 0);
      expect(client.receiveTimeout, const Duration(minutes: 5));
    });

    test('sends repeated face image fields', () async {
      client.expectedFaces = const ['first.jpg', 'last.jpg'];
      client.expectedTimeline = '1000,0;2000,1';
      await BaselineApi(client).upload(
        userId: 'user-1',
        voiceFilePath: 'voice.wav',
        faceImagePath: 'first.jpg',
        faceImagePaths: client.expectedFaces,
        faceTimestampsMs: const [1000, 2000],
        facePromptFlags: const [false, true],
      );
    });

    test('preserves API feature version in Firestore form', () async {
      client.featureVersion = 1;
      final result = await upload();
      expect(result.featureVersion, 1);
      expect(result.toJson()['featureVersion'], 1);
    });

    for (final code in [
      'invalid_audio',
      'voice_not_detected',
      'invalid_face_image',
      'face_not_detected',
      'invalid_face_timeline',
    ]) {
      test('$code asks for a fresh measurement', () async {
        final request = RequestOptions(path: '/baseline');
        client.error = ServerException(
          'Server responded 422',
          DioException(
            requestOptions: request,
            response: Response(
              requestOptions: request,
              statusCode: 422,
              data: {
                'detail': {'code': code, 'message': '다시 측정해주세요.'},
              },
            ),
          ),
        );
        await expectLater(
          upload(),
          throwsA(
            isA<BaselineMeasurementException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.message, 'message', '다시 측정해주세요.'),
          ),
        );
      });
    }

    test('deleted recording asks for remeasurement', () async {
      client.error = const FileSystemException('File not found');
      await expectLater(upload(), throwsA(isA<BaselineMeasurementException>()));
    });

    test('server failure remains retryable', () async {
      client.error = const ServerException();
      await expectLater(upload(), throwsA(isA<ServerException>()));
    });
  });
}
