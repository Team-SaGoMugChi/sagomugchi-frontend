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

    // 답을 고르면 바로 다음 문항으로 넘어가고, 첫 문항에서는 "이전 문제"가 꺼져 있다.
    expect(find.text('결과 저장하기'), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '이전 문제'))
          .onPressed,
      isNull,
    );

    for (var question = 1; question < 50; question++) {
      expect(find.text('Q$question / 50'), findsOneWidget);
      await tester.tap(find.text('보통이다'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }

    // 이전 문제로 돌아갔다가 다시 답하면 앞으로 간다.
    expect(find.text('Q50 / 50'), findsOneWidget);
    await tester.tap(find.text('이전 문제'));
    await tester.pumpAndSettle();
    expect(find.text('Q49 / 50'), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsOneWidget); // 이미 고른 답이 표시된다
    await tester.tap(find.text('보통이다'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // 마지막 문항은 답을 골라야 결과 저장하기가 나온다.
    expect(find.text('Q50 / 50'), findsOneWidget);
    expect(find.text('결과 저장하기'), findsNothing);
    await tester.tap(find.text('보통이다'));
    await tester.pump();
    await tester.tap(find.text('결과 저장하기'));
    await tester.pumpAndSettle();

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
