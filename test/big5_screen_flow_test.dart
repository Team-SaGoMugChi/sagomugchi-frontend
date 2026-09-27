import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oddo/app/router/app_routes.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/psych_test/data/models/psych_result.dart';
import 'package:oddo/features/psych_test/data/psych_providers.dart';
import 'package:oddo/features/psych_test/data/repositories/psych_repository.dart';
import 'package:oddo/features/psych_test/presentation/screens/big5_screen.dart';
import 'package:oddo/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testConfig = AppConfig(
  environment: AppEnvironment.dev,
  appName: 'Oddo test',
  apiBaseUrl: '',
  useDummyData: true,
);

class _Repository implements PsychRepository {
  Map<String, int>? savedScores;

  @override
  Future<PsychResult?> fetchResult() async => null;

  @override
  Future<void> saveBig5({
    required Map<String, int> scores,
    required String instrument,
    required DateTime completedAt,
  }) async {
    savedScores = scores;
  }
}

void main() {
  testWidgets('requires an answer and completes all 50 questions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = _Repository();
    final router = GoRouter(
      initialLocation: '/big5',
      routes: [
        GoRoute(path: '/big5', builder: (_, _) => const Big5Screen()),
        GoRoute(
          path: '/done',
          name: AppRoute.psychTestDone,
          builder: (_, _) => const Scaffold(body: Text('검사 완료')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          localStoreProvider.overrideWithValue(LocalStore(prefs)),
          psychRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );

    ElevatedButton nextButton() =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(nextButton().onPressed, isNull);

    for (var question = 1; question <= 50; question++) {
      expect(find.text('Q$question / 50'), findsOneWidget);
      await tester.tap(find.text('보통이다'));
      await tester.pump();
      expect(nextButton().onPressed, isNotNull);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
    }

    expect(find.text('검사 완료'), findsOneWidget);
    expect(repository.savedScores, {
      'O': 50,
      'C': 50,
      'E': 50,
      'A': 50,
      'N': 50,
    });
  });
}
