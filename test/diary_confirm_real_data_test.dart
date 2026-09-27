import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/data/dummy/dummy_seed.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/data/models/fusion_result.dart';
import 'package:oddo/features/diary/presentation/screens/diary_step2_confirm_screen.dart';
import 'package:oddo/theme/app_theme.dart';

const _realConfig = AppConfig(
  environment: AppEnvironment.prod,
  appName: 'Oddo (test)',
  apiBaseUrl: 'http://127.0.0.1:8001',
  useDummyData: false,
);

const _fusion = FusionResult(
  emotionKeywords: ['불안'],
  emotionScores: {'불안': 72},
  emotionIntensity: 72,
  textEmotionScores: {'불안': 0.72},
  voiceDelta: {},
  faceDelta: {},
);

void main() {
  testWidgets('real confirmation shows only server-computed fields', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(_realConfig)],
    );
    addTearDown(container.dispose);
    container.read(diaryDraftProvider.notifier)
      ..setTranscript('내일 발표가 있어서 긴장돼요.')
      ..setFusionResult(_fusion);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DiaryStep2ConfirmScreen(),
        ),
      ),
    );

    expect(find.text('불안'), findsOneWidget);
    expect(find.text('72 / 100'), findsOneWidget);
    expect(find.text('AI 요약'), findsNothing);
    expect(find.text('감정 안정도'), findsNothing);
    expect(find.text(DummySeed.diaryJan14.summary), findsNothing);
  });
}
