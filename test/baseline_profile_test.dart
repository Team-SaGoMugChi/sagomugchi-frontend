import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/error/app_exception.dart';
import 'package:oddo/features/auth/application/auth_controller.dart';
import 'package:oddo/features/auth/data/models/app_user.dart';
import 'package:oddo/features/baseline/application/baseline_face_image_provider.dart';
import 'package:oddo/features/baseline/application/baseline_profile_provider.dart';
import 'package:oddo/features/baseline/application/baseline_recording_provider.dart';
import 'package:oddo/features/baseline/application/baseline_upload_controller.dart';
import 'package:oddo/features/baseline/data/baseline_providers.dart';
import 'package:oddo/features/baseline/data/models/baseline_profile.dart';
import 'package:oddo/features/baseline/data/repositories/baseline_repository.dart';
import 'package:oddo/features/baseline/presentation/screens/baseline_done_screen.dart';
import 'package:oddo/theme/app_theme.dart';

final _profile = BaselineProfile(
  voice: const {'pitchMean': 217.3, 'energyMean': 0.25, 'speechRate': 3.2},
  face: const {'eyeAspectRatio': 0.28},
  measuredAt: DateTime(2026, 9, 15, 10, 30),
);

class _Repository implements BaselineRepository {
  int reads = 0;
  Future<BaselineProfile?> Function() saved = () async => _profile;
  Future<BaselineProfile> Function() upload = () async => _profile;

  @override
  Future<BaselineProfile?> fetchSaved() {
    reads++;
    return saved();
  }

  @override
  Future<BaselineProfile> submitMeasurement({
    required String voiceFilePath,
    required String faceImagePath,
  }) => upload();
}

class _AuthController extends AuthController {
  void leave() => state = const AuthState();

  void enter(String id) => state = AuthState(
    user: AppUser(id: id, email: '$id@example.test', nickname: id),
  );
}

void main() {
  for (final signOut in [false, true]) {
    test(
      'account ${signOut ? "logout" : "switch"} prevents reusing captures',
      () async {
        final repository = _Repository();
        var uploads = 0;
        repository.upload = () async {
          uploads++;
          return _profile;
        };
        final container = ProviderContainer(
          overrides: [
            baselineRepositoryProvider.overrideWithValue(repository),
            authControllerProvider.overrideWith(_AuthController.new),
          ],
        );
        addTearDown(container.dispose);
        final auth =
            container.read(authControllerProvider.notifier) as _AuthController;
        auth.enter('first');
        container.read(baselineRecordingProvider.notifier).set('voice.wav');
        container.read(baselineFaceImageProvider.notifier).set('face.jpg');
        if (signOut) {
          auth.leave();
        } else {
          auth.enter('second');
        }
        await container
            .read(baselineUploadControllerProvider.notifier)
            .submit();
        expect(uploads, 0);
        expect(container.read(baselineRecordingProvider), isNull);
        expect(container.read(baselineFaceImageProvider), isNull);
      },
    );
  }

  test('same account refresh preserves captures for retry', () {
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(_AuthController.new)],
    );
    addTearDown(container.dispose);
    final auth =
        container.read(authControllerProvider.notifier) as _AuthController;
    auth.enter('first');
    container.read(baselineRecordingProvider.notifier).set('voice.wav');
    container.read(baselineFaceImageProvider.notifier).set('face.jpg');
    auth.enter('first');
    expect(container.read(baselineRecordingProvider), 'voice.wav');
    expect(container.read(baselineFaceImageProvider), 'face.jpg');
  });

  test('complete requires usable voice and face references', () {
    expect(_profile.isComplete, isTrue);
    for (final voice in [
      <String, double>{},
      {'energyMean': 0.3},
      {'pitchMean': double.nan, 'energyMean': 0.3},
    ]) {
      expect(
        BaselineProfile(
          voice: voice,
          face: _profile.face,
          measuredAt: _profile.measuredAt,
        ).isComplete,
        isFalse,
      );
    }
    expect(
      BaselineProfile(
        voice: _profile.voice,
        face: const {},
        measuredAt: _profile.measuredAt,
      ).isComplete,
      isFalse,
    );
  });

  test('restores saved profile when no upload exists in memory', () async {
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [baselineRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(baselineProfileProvider.future),
      same(_profile),
    );
    expect(repository.reads, 1);
  });

  test('uses confirmed upload without reading stale storage', () async {
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [baselineRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(baselineRecordingProvider.notifier).set('voice.wav');
    container.read(baselineFaceImageProvider.notifier).set('face.jpg');
    await container.read(baselineUploadControllerProvider.notifier).submit();
    expect(
      await container.read(baselineProfileProvider.future),
      same(_profile),
    );
    expect(repository.reads, 0);
  });

  test(
    'account switch clears uploaded result and ignores late responses',
    () async {
      final repository = _Repository();
      final pending = Completer<BaselineProfile>();
      repository.upload = () => pending.future;
      final container = ProviderContainer(
        overrides: [
          baselineRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(_AuthController.new),
        ],
      );
      addTearDown(container.dispose);
      final auth =
          container.read(authControllerProvider.notifier) as _AuthController;
      auth.enter('first');
      container.read(baselineRecordingProvider.notifier).set('voice.wav');
      container.read(baselineFaceImageProvider.notifier).set('face.jpg');
      final request = container
          .read(baselineUploadControllerProvider.notifier)
          .submit();
      auth.enter('second');
      expect(
        container.read(baselineUploadControllerProvider).asData?.value,
        isNull,
      );
      pending.complete(_profile);
      await request;
      expect(
        container.read(baselineUploadControllerProvider).asData?.value,
        isNull,
      );
      repository.saved = () async => null;
      expect(await container.read(baselineProfileProvider.future), isNull);
    },
  );

  group('completion screen', () {
    late _Repository repository;

    setUp(() => repository = _Repository());

    Future<void> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [baselineRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const BaselineDoneScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('displays measured values rather than dummy scores', (
      tester,
    ) async {
      await show(tester);
      await tester.pumpAndSettle();
      expect(find.text('217 Hz'), findsOneWidget);
      expect(find.text('3.2 음절/초'), findsOneWidget);
      expect(find.text('9/15 10:30'), findsOneWidget);
      expect(find.text('72%'), findsNothing);
      expect(find.text('심리테스트 시작하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not claim completion while loading', (tester) async {
      final pending = Completer<BaselineProfile?>();
      repository.saved = () => pending.future;
      await show(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('첫 측정이 완료됐어요!'), findsNothing);
      expect(find.text('심리테스트 시작하기'), findsNothing);
      pending.complete(_profile);
      await tester.pumpAndSettle();
    });

    testWidgets('missing result offers remeasurement', (tester) async {
      repository.saved = () async => null;
      await show(tester);
      await tester.pumpAndSettle();
      expect(find.text('다시 측정하기'), findsOneWidget);
      expect(find.text('첫 측정이 완료됐어요!'), findsNothing);
      expect(find.text('심리테스트 시작하기'), findsNothing);
    });

    testWidgets('legacy empty face is not shown as successful', (tester) async {
      repository.saved = () async => BaselineProfile(
        voice: _profile.voice,
        face: const {},
        measuredAt: _profile.measuredAt,
      );
      await show(tester);
      await tester.pumpAndSettle();
      expect(find.text('기준값을 다시 측정해주세요'), findsOneWidget);
      expect(find.text('심리테스트 시작하기'), findsNothing);
    });

    testWidgets('failed read can be retried', (tester) async {
      repository.saved = () async => throw const NetworkException();
      await show(tester);
      await tester.pump();
      expect(find.text('다시 불러오기'), findsOneWidget);
      repository.saved = () async => _profile;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('217 Hz'), findsOneWidget);
    });
  });
}
