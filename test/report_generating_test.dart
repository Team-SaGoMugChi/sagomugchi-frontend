import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oddo/app/router/app_routes.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/counsel_report.dart';
import 'package:oddo/features/diary/data/models/counsel_session.dart';
import 'package:oddo/features/diary/data/repositories/counsel_repository.dart';
import 'package:oddo/features/diary/presentation/screens/report_generating_screen.dart';
import 'package:oddo/theme/app_theme.dart';

/// 리포트 응답을 테스트가 원하는 때에 돌려준다.
class _PendingCounselRepository implements CounselRepository {
  final report = Completer<CounselReport>();

  @override
  Future<CounselReport> fetchReport({
    required List<CounselMessage> messages,
    Map<String, double>? emotions,
    String? diarySummary,
  }) => report.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_PendingCounselRepository> _pumpGenerating(WidgetTester tester) async {
  final repository = _PendingCounselRepository();
  final container = ProviderContainer(
    overrides: [counselRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  container
      .read(diaryDraftProvider.notifier)
      .setCounsel(
        messages: const [
          CounselMessage(speaker: CounselSpeaker.oddo, text: '오늘 어땠어요?'),
          CounselMessage(speaker: CounselSpeaker.user, text: '친구랑 싸웠어요.'),
        ],
      );

  final router = GoRouter(
    initialLocation: AppPath.reportGenerating,
    routes: [
      GoRoute(
        path: AppPath.reportGenerating,
        name: AppRoute.reportGenerating,
        builder: (_, _) => const ReportGeneratingScreen(),
      ),
      GoRoute(
        path: AppPath.reportGuide,
        name: AppRoute.reportGuide,
        builder: (_, _) => const Text('46번 리포트'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    ),
  );
  await tester.pump();
  return repository;
}

double _barValue(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value!;

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('fills the bar only when the report actually arrives', (
    tester,
  ) async {
    final repository = await _pumpGenerating(tester);

    // 고정 % 숫자는 없다 — 실제 진행률을 알 수 없어서.
    expect(find.textContaining('%'), findsNothing);
    // 응답 전: 대화 전달만 끝났고, 리포트 완성은 아직.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);

    // 오래 기다려도 응답 전에는 끝까지 차지 않는다.
    await tester.pump(const Duration(seconds: 20));
    expect(_barValue(tester), closeTo(0.9, 0.001));
    expect(find.text('46번 리포트'), findsNothing);

    repository.report.complete(
      const CounselReport(headline: '오늘의 리포트', summary: '요약'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_barValue(tester), 1.0);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('46번 리포트'), findsOneWidget);
  });

  testWidgets('marks the AI step when the report fails', (tester) async {
    final repository = await _pumpGenerating(tester);

    repository.report.completeError(Exception('server down'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('46번 리포트'), findsOneWidget);
  });
}
