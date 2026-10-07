import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oddo/app/router/app_routes.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/data/models/diary_entry.dart';
import 'package:oddo/features/diary/data/models/video_rating.dart';
import 'package:oddo/features/diary/presentation/screens/diary_step3_video_done_screen.dart';
import 'package:oddo/features/records/application/viewing_date_provider.dart';
import 'package:oddo/features/records/presentation/screens/shortform_player_screen.dart';
import 'package:oddo/theme/app_theme.dart';

const _testConfig = AppConfig(
  environment: AppEnvironment.dev,
  appName: 'Oddo (test)',
  apiBaseUrl: '',
  useDummyData: true,
);

Future<ProviderContainer> _pump(WidgetTester tester, Widget screen) async {
  final view = tester.view;
  view.physicalSize = const Size(1170, 2532);
  view.devicePixelRatio = 3.0;
  addTearDown(view.reset);

  final container = ProviderContainer(
    overrides: [appConfigProvider.overrideWithValue(_testConfig)],
  );
  addTearDown(container.dispose);
  container
      .read(viewingDateProvider.notifier)
      .set(DateTime(2026, 10, 7));

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: AppPath.shortformPlayer,
        name: AppRoute.shortformPlayer,
        builder: (_, _) => const SizedBox(),
      ),
      GoRoute(
        path: AppPath.diaryStep4CounselIntro,
        name: AppRoute.diaryStep4CounselIntro,
        builder: (_, _) => const SizedBox(),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('숏폼 플레이어', () {
    testWidgets('영상이 없으면 가짜 재생 화면 대신 없다고 알린다', (tester) async {
      await _pump(tester, const ShortformPlayerScreen());

      expect(find.text('10월 7일의 이야기'), findsOneWidget);
      expect(find.text('아직 볼 수 있는 영상이 없어요'), findsOneWidget);
      // 예전 샘플 시간·재생바·전체화면 아이콘이 남아 있지 않다.
      expect(find.text('01:32'), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });

  group('Step3 완료 화면', () {
    testWidgets('샘플 시간·요약 대신 영상 상태만 보여준다', (tester) async {
      await _pump(tester, const DiaryStep3VideoDoneScreen());

      expect(find.text('영상을 불러오지 못했어요.'), findsOneWidget);
      expect(find.text('00:03'), findsNothing);
      expect(find.text('01:32'), findsNothing);
      expect(find.text('영상 요약'), findsNothing);
      expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
    });

    testWidgets('영상 평가를 고르면 기록 완료 때 저장할 draft에 남는다', (tester) async {
      final container = await _pump(tester, const DiaryStep3VideoDoneScreen());

      await tester.tap(find.text('별로였어요'));
      await tester.pump();
      expect(container.read(diaryDraftProvider).videoRating, VideoRating.bad);

      await tester.tap(find.text('좋았어요'));
      await tester.pump();
      expect(container.read(diaryDraftProvider).videoRating, VideoRating.good);
    });
  });

  group('VideoRating 저장 형식', () {
    test('일기 문서에 key로 저장하고 다시 읽는다', () {
      final entry = DiaryEntry(
        id: '2026-10-07',
        date: DateTime(2026, 10, 7),
        transcript: '원문',
        summary: '요약',
        emotionKeywords: const ['기쁨'],
        videoRating: VideoRating.okay,
      );

      final json = entry.toJson();
      expect(json['videoRating'], 'okay');
      expect(DiaryEntry.fromJson(json).videoRating, VideoRating.okay);
    });

    test('고르지 않았거나 모르는 값이면 null', () {
      final json = DiaryEntry(
        id: '2026-10-07',
        date: DateTime(2026, 10, 7),
        transcript: '원문',
        summary: '요약',
        emotionKeywords: const [],
      ).toJson();

      expect(json.containsKey('videoRating'), isFalse);
      expect(DiaryEntry.fromJson(json).videoRating, isNull);
      expect(
        DiaryEntry.fromJson({...json, 'videoRating': 'great'}).videoRating,
        isNull,
      );
    });
  });
}
