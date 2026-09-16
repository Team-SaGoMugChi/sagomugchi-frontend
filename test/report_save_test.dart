import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/app/router/app_router.dart';
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
import 'package:oddo/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests run on dummy data so they never touch Firebase.
const _testConfig = AppConfig(
  environment: AppEnvironment.dev,
  appName: 'Oddo (test)',
  apiBaseUrl: '',
  useDummyData: true,
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
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repository = _CapturingDiaryRepository();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(_testConfig),
      localStoreProvider.overrideWithValue(LocalStore(prefs)),
      diaryRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  if (withFusion) {
    container.read(diaryDraftProvider.notifier).setFusionResult(_fusion);
  }

  final router = container.read(goRouterProvider);
  router.go(AppPath.reportGuide);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    ),
  );
  await tester.pump();

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
