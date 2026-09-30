import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/core/config/app_config.dart';
import 'package:oddo/core/config/app_config_provider.dart';
import 'package:oddo/data/dummy/dummy_seed.dart';
import 'package:oddo/features/diary/application/diary_draft_provider.dart';
import 'package:oddo/features/diary/data/models/diary_interview.dart';
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
    // 대화가 없으면(대화형 말하기 이전 흐름) 대화 보기 버튼을 숨긴다.
    expect(find.text('대화 내용 보기'), findsNothing);
  });

  testWidgets('shows the refined diary, the summary and the conversation button', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(_realConfig)],
    );
    addTearDown(container.dispose);
    container.read(diaryDraftProvider.notifier)
      ..setTranscript('음 발표가 있어서 긴장돼요.')
      ..setInterviewMessages(const [
        InterviewMessage(speaker: InterviewSpeaker.user, text: '음 발표가 있어서 긴장돼요.'),
      ])
      ..setDiaryText('내일 발표가 있어서 긴장된다.')
      ..setSummary('발표를 앞두고 긴장한 하루였어요.')
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

    expect(find.text('오늘의 일기'), findsOneWidget);
    expect(find.text('내일 발표가 있어서 긴장된다.'), findsOneWidget);
    expect(find.text('음 발표가 있어서 긴장돼요.'), findsNothing);
    expect(find.text('발표를 앞두고 긴장한 하루였어요.'), findsOneWidget);
    expect(find.text('대화 내용 보기'), findsOneWidget);
  });
}
