import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oddo/app/router/app_routes.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/auth/application/auth_controller.dart';
import 'package:oddo/features/baseline/data/datasources/baseline_dummy_data_source.dart';
import 'package:oddo/features/onboarding/presentation/screens/onboarding_done_screen.dart';
import 'package:oddo/features/persona/data/models/persona_config.dart';
import 'package:oddo/features/persona/data/persona_providers.dart';
import 'package:oddo/features/psych_test/data/psych_providers.dart';
import 'package:oddo/features/psych_test/domain/ipip_big5.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sample upload and reload meet current completion contract', () async {
    final source = BaselineDummyDataSource();
    final uploaded = await source.upload(
      voiceFilePath: 'sample.wav',
      faceImagePath: 'sample.jpg',
    );
    expect(uploaded.isAnalysisReady, isTrue);
    expect((await source.fetchSaved())!.isAnalysisReady, isTrue);
  });

  testWidgets('completed sample onboarding returns to home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: AppEnvironment.dev,
            appName: 'test',
            apiBaseUrl: '',
            useDummyData: true,
          ),
        ),
        localStoreProvider.overrideWithValue(
          LocalStore(await SharedPreferences.getInstance()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container
          .read(authControllerProvider.notifier)
          .signUp(
            email: 'preview@example.invalid',
            password: 'sample',
            nickname: '샘플',
          );
    });
    await container
        .read(personaRepositoryProvider)
        .savePersona(
          PersonaConfig(
            name: '오디',
            tone: '친근하고 따뜻한',
            traits: const ['공감 잘해주는'],
            updatedAt: DateTime(2026),
          ),
        );
    await container
        .read(psychRepositoryProvider)
        .saveBig5(
          scores: const {'O': 50, 'C': 50, 'E': 50, 'A': 50, 'N': 50},
          instrument: ipipBig5Instrument,
          completedAt: DateTime(2026),
        );
    final router = GoRouter(
      initialLocation: '/done',
      routes: [
        GoRoute(path: '/done', builder: (_, _) => const OnboardingDoneScreen()),
        GoRoute(
          path: '/home',
          name: AppRoute.home,
          builder: (_, _) => const Scaffold(body: Text('홈 도착')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.ensureVisible(find.text('홈으로 가기'));
    await tester.tap(find.text('홈으로 가기'));
    await tester.pumpAndSettle();
    expect(find.text('홈 도착'), findsOneWidget);
    expect(container.read(authControllerProvider).onboardingDone, isTrue);
  });
}
