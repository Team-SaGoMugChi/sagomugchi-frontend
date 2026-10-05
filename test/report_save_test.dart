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
  final repository = await _pumpReportGuide(
    tester,
    fusion: withFusion ? _fusion : null,
    config: config,
    transcript: transcript,
    diaryText: diaryText,
    summary: summary,
  );

  if (!config.useDummyData) {
    expect(find.text('회복 가능성'), findsNothing);
    expect(find.text('상담을 지나며 속상함이 조금씩 가라앉았어요.'), findsNothing);
  }

  await tester.tap(find.text('기록 완료하기'));
  await tester.pump();
  await tester.pump();

  return repository;
}

Future<_CapturingDiaryRepository> _pumpReportGuide(
  WidgetTester tester, {
  FusionResult? fusion,
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

  if (fusion != null) {
    container.read(diaryDraftProvider.notifier).setFusionResult(fusion);
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

  return repository;
}

/// 감정 여러 개가 섞인 Step2 결과 — 2026-10-05 실기기 일기를 문장별로 분석한 값.
const _mixedFusion = FusionResult(
  emotionKeywords: ['기쁨', '불안'],
  emotionScores: {
    '기쁨': 58.2,
    '슬픔': 11.3,
    '분노': 0.3,
    '불안': 15.3,
    '상처': 11.5,
    '당황': 0,
  },
  emotionIntensity: 69,
  textEmotionScores: {'기쁨': 0.582},
  voiceDelta: {},
  faceDelta: {},
);

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

  testWidgets('shows only the top three emotions but saves all of them', (
    tester,
  ) async {
    final repository = await _pumpReportGuide(
      tester,
      fusion: _mixedFusion,
      config: _realDataConfig,
      transcript: '오늘 발표가 있었어요.',
    );

    // 높은 순으로 3개만, 나머지(0% 포함)는 숨긴다.
    final top = ['기쁨', '불안', '상처'];
    for (final name in top) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    for (final name in ['슬픔', '분노', '당황']) {
      expect(find.text(name), findsNothing, reason: name);
    }
    final rows = [for (final name in top) tester.getTopLeft(find.text(name)).dy];
    expect(rows, orderedEquals([...rows]..sort()));

    await tester.tap(find.text('기록 완료하기'));
    await tester.pump();
    await tester.pump();
    expect(repository.savedReport!.emotionDistribution.length, 6);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('says so when no emotion was detected', (tester) async {
    await _pumpReportGuide(
      tester,
      fusion: const FusionResult(
        emotionKeywords: [],
        emotionScores: {'기쁨': 0, '슬픔': 0, '분노': 0, '불안': 0, '상처': 0, '당황': 0},
        emotionIntensity: 0,
        textEmotionScores: {},
        voiceDelta: {},
        faceDelta: {},
      ),
      config: _realDataConfig,
      transcript: '오늘은 월요일이었어요.',
    );

    expect(find.text('이번 일기에서는 감정을 뚜렷하게 읽지 못했어요.'), findsOneWidget);
    expect(find.text('0%'), findsNothing);

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
