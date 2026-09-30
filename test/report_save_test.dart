import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oddo/app/router/app_routes.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/core/storage/local_store.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/data/diary_providers.dart';
import 'package:oddo/features/diary/data/models/counsel_session.dart';
import 'package:oddo/features/diary/data/models/diary_entry.dart';
import 'package:oddo/features/diary/data/models/emotion_report.dart';
import 'package:oddo/features/diary/data/models/fusion_result.dart';
import 'package:oddo/features/diary/data/repositories/diary_repository.dart';
import 'package:oddo/features/diary/presentation/screens/report_guide_screen.dart';
import 'package:oddo/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests run on dummy data so they never touch Firebase.
const _testConfig = AppConfig(
  environment: AppEnvironment.dev,
  appName: 'Oddo (test)',
  apiBaseUrl: '',
  useDummyData: true,
);

const _realDataConfig = AppConfig(
  environment: AppEnvironment.prod,
  appName: 'Oddo (test)',
  apiBaseUrl: 'http://127.0.0.1:8001',
  useDummyData: false,
);

/// Captures what "기록 완료하기" hands to the repository so the test can assert
/// on the saved payload instead of reaching Firestore.
class _CapturingDiaryRepository implements DiaryRepository {
  DiaryEntry? savedEntry;
  EmotionReport? savedReport;

  @override
  Future<void> saveRecord({
    required DiaryEntry entry,
    required EmotionReport report,
    required CounselSession counsel,
  }) async {
    savedEntry = entry;
    savedReport = report;
  }

  @override
  Future<List<DiaryEntry>> fetchEntries() async => const [];

  @override
  Future<DiaryEntry?> fetchEntry(DateTime date) async => null;

  @override
  Future<EmotionReport?> fetchReport(DateTime date) async => null;

  @override
  Future<CounselSession?> fetchCounsel(DateTime date) async => null;

  @override
  Future<Set<DateTime>> fetchRecordedDates() async => {};
}

/// Step1 분석이 성공했을 때 서버가 주는 모양 — 점수는 0–100.
const _fusion = FusionResult(
  emotionKeywords: ['서운함', '지침'],
  emotionScores: {'서운함': 60, '지침': 40},
  emotionIntensity: 88,
  textEmotionScores: {'서운함': 0.6},
  voiceDelta: {},
  faceDelta: {},
);

Future<_CapturingDiaryRepository> _tapCompleteRecord(
  WidgetTester tester, {
  required bool withFusion,
  AppConfig config = _testConfig,
  String? transcript,
  String? diaryText,
  String? summary,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repository = _CapturingDiaryRepository();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      localStoreProvider.overrideWithValue(LocalStore(prefs)),
      diaryRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  if (withFusion) {
    container.read(diaryDraftProvider.notifier).setFusionResult(_fusion);
  }
  if (transcript != null) {
    container.read(diaryDraftProvider.notifier).setTranscript(transcript);
  }
  if (diaryText != null) {
    container.read(diaryDraftProvider.notifier).setDiaryText(diaryText);
  }
  if (summary != null) {
    container.read(diaryDraftProvider.notifier).setSummary(summary);
  }

  final router = GoRouter(
    initialLocation: AppPath.reportGuide,
    routes: [
      GoRoute(
        path: AppPath.reportGuide,
        name: AppRoute.reportGuide,
        builder: (_, _) => const ReportGuideScreen(),
      ),
      GoRoute(
        path: AppPath.homeWritten,
        name: AppRoute.homeWritten,
        builder: (_, _) => const SizedBox(),
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

  if (!config.useDummyData) {
    expect(find.text('회복 가능성'), findsNothing);
    expect(find.text('상담을 지나며 속상함이 조금씩 가라앉았어요.'), findsNothing);
  }

  await tester.tap(find.text('기록 완료하기'));
  await tester.pump();
  await tester.pump();

  return repository;
}

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

  testWidgets('saves the server analysis when Step1 produced one', (
    tester,
  ) async {
    final repository = await _tapCompleteRecord(tester, withFusion: true);

    expect(repository.savedEntry, isNotNull, reason: '저장이 호출되지 않음');
    expect(repository.savedEntry!.emotionKeywords, _fusion.emotionKeywords);
    expect(repository.savedEntry!.emotionIntensity, 88);
    expect(repository.savedReport!.emotionIntensity, 88);
    // 서버 0–100 → Firestore 0–1 (FIRESTORE_SCHEMA.md §3).
    expect(repository.savedReport!.emotionDistribution, {
      '서운함': 0.6,
      '지침': 0.4,
    });

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('real mode stores only measured and user-confirmed content', (
    tester,
  ) async {
    const transcript = '오늘 발표를 마치고 긴장이 조금 풀렸어요.';
    final repository = await _tapCompleteRecord(
      tester,
      withFusion: true,
      config: _realDataConfig,
      transcript: transcript,
    );

    expect(repository.savedEntry, isNotNull, reason: '저장이 호출되지 않음');
    expect(repository.savedEntry!.transcript, transcript);
    expect(repository.savedEntry!.summary, transcript);
    expect(repository.savedEntry!.emotionStability, 0);
    expect(repository.savedReport!.recoveryPossibility, 0);
    expect(repository.savedReport!.analysisComment, isEmpty);
    expect(repository.savedReport!.behaviorGuides, isEmpty);
    expect(repository.savedReport!.recommendedActivities, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('saves the refined diary and summary apart from the raw answers', (
    tester,
  ) async {
    final repository = await _tapCompleteRecord(
      tester,
      withFusion: true,
      config: _realDataConfig,
      transcript: '음 발표를 마쳤어요.\n긴장이 좀 풀렸어요.',
      diaryText: '오늘 발표를 마쳤다. 긴장이 좀 풀렸다.',
      summary: '발표를 마치고 긴장이 풀린 하루였어요.',
    );

    final entry = repository.savedEntry!;
    expect(entry.transcript, '음 발표를 마쳤어요.\n긴장이 좀 풀렸어요.');
    expect(entry.diaryText, '오늘 발표를 마쳤다. 긴장이 좀 풀렸다.');
    expect(entry.summary, '발표를 마치고 긴장이 풀린 하루였어요.');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('real mode blocks saving when analysis is missing', (
    tester,
  ) async {
    final repository = await _tapCompleteRecord(
      tester,
      withFusion: false,
      config: _realDataConfig,
      transcript: '분석되지 않은 원문',
    );

    expect(repository.savedEntry, isNull);
    expect(find.textContaining('분석 결과가 없어 저장할 수 없어요'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('falls back to sample content when analysis is missing', (
    tester,
  ) async {
    final repository = await _tapCompleteRecord(tester, withFusion: false);

    expect(repository.savedEntry, isNotNull, reason: '저장이 호출되지 않음');
    expect(repository.savedEntry!.emotionKeywords, isNotEmpty);
    // 분포는 폴백이어도 0–1 범위를 지켜야 차트가 깨지지 않는다.
    for (final share in repository.savedReport!.emotionDistribution.values) {
      expect(share, inInclusiveRange(0.0, 1.0));
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
