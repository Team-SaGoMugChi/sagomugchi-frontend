import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oddo/app/router/app_routes.dart';
import 'package:oddo/features/home/presentation/widgets/baseline_needed_dialog.dart';

void main() {
  for (final seen in [false, true]) {
    testWidgets('home preparation never replays intro when seen=$seen', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showBaselineNeededDialog(context, introFilmSeen: seen),
                child: const Text('준비 열기'),
              ),
            ),
          ),
          GoRoute(
            path: '/persona',
            name: AppRoute.personaIntro,
            builder: (_, _) => const Scaffold(body: Text('페르소나 준비 화면')),
          ),
          GoRoute(
            path: '/film',
            name: AppRoute.appIntroduction,
            builder: (_, _) => const Scaffold(body: Text('소개영상 재생 화면')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('준비 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('페르소나 준비 화면'), findsOneWidget);
      expect(find.text('소개영상 재생 화면'), findsNothing);
    });
  }
}
