import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/app/router/app_router.dart';
import 'package:oddo/app/router/app_routes.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/onboarding/presentation/screens/app_introduction_screen.dart';
import 'package:oddo/features/persona/data/models/persona_config.dart';
import 'package:oddo/features/persona/data/persona_providers.dart';
import 'package:oddo/features/persona/data/repositories/persona_repository.dart';
import 'package:oddo/features/persona/presentation/widgets/persona_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'introduction leads to persona and saved persona leads to permissions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = PersonaDummyRepository();
      await repository.savePersona(
        PersonaConfig(
          name: '오디',
          tone: '친근하고 따뜻한',
          traits: const ['공감 잘해주는'],
          updatedAt: DateTime(2026),
        ),
      );
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
          localStoreProvider.overrideWithValue(LocalStore(prefs)),
          personaRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(goRouterProvider);
      router.go(AppPath.appIntroduction);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('대화할 친구 설정하기'));
      await tester.tap(find.text('대화할 친구 설정하기'));
      await tester.pumpAndSettle();
      expect(find.text('설정 시작하기'), findsOneWidget);
      router.go(AppPath.personaDone);
      await tester.pumpAndSettle();
      await tester.tap(find.text('문장 읽기 측정 준비하기'));
      await tester.pumpAndSettle();
      expect(find.text('권한 허용하기'), findsOneWidget);
    },
  );

  testWidgets('sample counseling can be tried without recording or saving', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppIntroductionScreen()));
    await tester.tap(find.text('상담'));
    await tester.pump();
    await tester.ensureVisible(find.text('“천천히 걸을 수 있어서 좋았어요” 보내보기'));
    await tester.tap(find.text('“천천히 걸을 수 있어서 좋았어요” 보내보기'));
    await tester.pump();
    expect(find.textContaining('내 속도로 움직이는 시간'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy multiple traits become exactly one selection on edit', (
    tester,
  ) async {
    Set<int>? selection;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              appName: 'test',
              apiBaseUrl: '',
              useDummyData: true,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PersonaForm(
                initialTraits: const {0, 1},
                onChanged: (_, traits, _) => selection = traits,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('유머러스한'));
    await tester.tap(find.text('유머러스한'));
    await tester.pump();
    expect(selection, {2});
    await tester.tap(find.text('유머러스한'));
    expect(selection, {2});
  });

  test('four tones map to four voices and preserve counseling personality', () {
    final voices = <String>{};
    for (final tone in ['친근하고 따뜻한', '차분하고 진중한', '밝고 에너지 넘치는', '간결하고 솔직한']) {
      final persona = PersonaConfig(
        name: '오디',
        tone: tone,
        traits: const ['공감 잘해주는'],
        updatedAt: DateTime(2026),
      );
      voices.add(PersonaConfig.fromJson(persona.toJson()).clovaVoice);
      expect(persona.toCounselJson()['traits'], ['공감 잘해주는']);
      expect(persona.toCounselJson()['tone'], tone);
    }
    expect(voices, {'nara', 'njinho', 'nminyoung', 'ndonghyun'});
  });
}
