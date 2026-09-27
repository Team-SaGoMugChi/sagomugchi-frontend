import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/error/app_exception.dart';
import 'package:oddo/features/auth/application/auth_controller.dart';
import 'package:oddo/features/auth/data/auth_providers.dart';
import 'package:oddo/features/auth/data/models/app_user.dart';
import 'package:oddo/features/auth/data/repositories/auth_repository.dart';
import 'package:oddo/features/baseline/data/baseline_providers.dart';
import 'package:oddo/features/baseline/data/models/baseline_profile.dart';
import 'package:oddo/features/baseline/data/repositories/baseline_repository.dart';
import 'package:oddo/features/onboarding/application/onboarding_completion_service.dart';
import 'package:oddo/features/onboarding/application/onboarding_controller.dart';
import 'package:oddo/features/persona/data/models/persona_config.dart';
import 'package:oddo/features/persona/data/persona_providers.dart';
import 'package:oddo/features/persona/data/repositories/persona_repository.dart';
import 'package:oddo/features/persona/presentation/screens/persona_done_screen.dart';
import 'package:oddo/features/persona/presentation/widgets/persona_form.dart';
import 'package:oddo/features/psych_test/data/models/psych_result.dart';
import 'package:oddo/features/psych_test/data/psych_providers.dart';
import 'package:oddo/features/psych_test/data/repositories/psych_repository.dart';
import 'package:oddo/features/psych_test/domain/ipip_big5.dart';
import 'package:oddo/theme/app_theme.dart';

class _LoggedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    user: AppUser(id: 'user-1', email: 'user@test.dev', nickname: '테스터'),
  );
}

class _AuthRepository extends Fake implements AuthRepository {
  _AuthRepository({this.failure});

  final AppException? failure;
  bool? writtenValue;

  @override
  Future<void> updateOnboardingDone({required bool done}) async {
    if (failure case final failure?) throw failure;
    writtenValue = done;
  }
}

class _PersonaRepository extends Fake implements PersonaRepository {
  _PersonaRepository(this.config);

  final PersonaConfig? config;

  @override
  Future<PersonaConfig?> fetchPersona() async => config;
}

class _BaselineRepository extends Fake implements BaselineRepository {
  _BaselineRepository(this.profile);

  final BaselineProfile? profile;

  @override
  Future<BaselineProfile?> fetchSaved() async => profile;
}

class _PsychRepository extends Fake implements PsychRepository {
  @override
  Future<PsychResult?> fetchResult() async => PsychResult(
    big5: const {'O': 50, 'C': 50, 'E': 50, 'A': 50, 'N': 50},
    big5Instrument: ipipBig5Instrument,
    big5CompletedAt: DateTime.utc(2026, 9, 27),
    updatedAt: DateTime.utc(2026, 9, 27),
  );
}

final _validBaseline = BaselineProfile(
  voice: {
    for (final key in BaselineProfile.requiredAnalysisVoiceKeys) key: 1,
    'pitchMean': 150,
    'energyMean': 0.4,
    'voicedRatio': 0.8,
  },
  face: {for (final key in BaselineProfile.requiredAnalysisFaceKeys) key: 1},
  measuredAt: DateTime.utc(2026, 9, 27),
  featureVersion: BaselineProfile.currentFeatureVersion,
);

final _validPersona = PersonaConfig(
  name: '오디',
  tone: '친근하고 따뜻한',
  traits: const ['공감 잘해주는', '따뜻한'],
  updatedAt: DateTime.utc(2026, 9, 27),
);

void main() {
  test(
    'onboarding completion updates both states after persistence succeeds',
    () async {
      final repository = _AuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .completeOnboarding();

      expect(repository.writtenValue, isTrue);
      expect(container.read(authControllerProvider).onboardingDone, isTrue);
      expect(container.read(onboardingCompleteProvider), isTrue);
    },
  );

  test('failed onboarding persistence leaves both states incomplete', () async {
    final repository = _AuthRepository(failure: const ServerException('저장 실패'));
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(_LoggedInAuthController.new),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(authControllerProvider.notifier).completeOnboarding(),
      throwsA(isA<ServerException>()),
    );

    expect(container.read(authControllerProvider).onboardingDone, isFalse);
    expect(container.read(onboardingCompleteProvider), isFalse);
  });

  test(
    'onboarding completion verifies all three persisted prerequisites',
    () async {
      final authRepository = _AuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
          baselineRepositoryProvider.overrideWithValue(
            _BaselineRepository(_validBaseline),
          ),
          psychRepositoryProvider.overrideWithValue(_PsychRepository()),
          personaRepositoryProvider.overrideWithValue(
            _PersonaRepository(_validPersona),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(onboardingCompletionServiceProvider).complete();

      expect(authRepository.writtenValue, isTrue);
      expect(container.read(authControllerProvider).onboardingDone, isTrue);
    },
  );

  test('missing baseline cannot mark onboarding complete', () async {
    final authRepository = _AuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        authControllerProvider.overrideWith(_LoggedInAuthController.new),
        baselineRepositoryProvider.overrideWithValue(_BaselineRepository(null)),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(onboardingCompletionServiceProvider).complete(),
      throwsA(isA<AppException>()),
    );

    expect(authRepository.writtenValue, isNull);
    expect(container.read(authControllerProvider).onboardingDone, isFalse);
  });

  test('legacy baseline cannot mark onboarding complete', () async {
    final authRepository = _AuthRepository();
    final legacyBaseline = BaselineProfile(
      voice: const {'pitchMean': 150, 'energyMean': 0.4},
      face: const {'neutral': 0.8},
      measuredAt: DateTime.utc(2026, 9, 27),
      featureVersion: 1,
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        authControllerProvider.overrideWith(_LoggedInAuthController.new),
        baselineRepositoryProvider.overrideWithValue(
          _BaselineRepository(legacyBaseline),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(onboardingCompletionServiceProvider).complete(),
      throwsA(isA<AppException>()),
    );

    expect(authRepository.writtenValue, isNull);
    expect(container.read(authControllerProvider).onboardingDone, isFalse);
  });

  testWidgets('persona completion shows the saved configuration', (
    tester,
  ) async {
    final config = PersonaConfig(
      name: '마음이',
      tone: '차분하고 다정한',
      traits: const ['공감 잘해주는', '솔직한'],
      updatedAt: DateTime(2026, 9, 27),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personaRepositoryProvider.overrideWithValue(
            _PersonaRepository(config),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PersonaDoneScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('마음이가 준비됐어요!'), findsOneWidget);
    expect(find.text('차분하고 다정한'), findsOneWidget);
    expect(find.text('공감 잘해주는, 솔직한'), findsOneWidget);
    expect(find.text('오디가 준비됐어요!'), findsNothing);
  });

  test('persona config rejects oversized or multiline prompt fields', () {
    final oversized = PersonaConfig(
      name: '12345678901',
      tone: '차분한 말투',
      traits: const ['따뜻한'],
      updatedAt: DateTime(2026, 9, 27),
    );
    final multiline = PersonaConfig(
      name: '오디',
      tone: '차분한\n지시',
      traits: const ['따뜻한'],
      updatedAt: DateTime(2026, 9, 27),
    );

    expect(oversized.isValid, isFalse);
    expect(multiline.isValid, isFalse);
  });

  testWidgets('persona name input enforces the displayed ten-character limit', (
    tester,
  ) async {
    String? lastName;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PersonaForm(onChanged: (_, _, name) => lastName = name),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '12345678901');
    await tester.pump();

    expect(find.text('1234567890'), findsOneWidget);
    expect(lastName, '1234567890');
  });
}
