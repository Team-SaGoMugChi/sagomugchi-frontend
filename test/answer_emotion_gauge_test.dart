import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/diary/application/diary_interview_controller.dart';
import 'package:oddo/features/diary/data/models/diary_interview.dart';
import 'package:oddo/features/diary/presentation/widgets/answer_emotion_gauge.dart';
import 'package:oddo/features/diary/presentation/widgets/diary_interview_copy.dart';

const _angry = AnswerEmotion(
  scores: {'분노': 1},
  dominantEmotion: '분노',
  confidence: 0.9,
);
const _sad = AnswerEmotion(
  scores: {'슬픔': 1},
  dominantEmotion: '슬픔',
  confidence: 0.5,
);
const _unclear = AnswerEmotion(scores: {'분노': 0, '슬픔': 0});

Future<void> _pump(WidgetTester tester, List<AnswerEmotionRecord> records) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: AnswerEmotionGauge(records: records),
        ),
      ),
    ),
  );
}

double _fill(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('emotion-gauge-fill'))).height;

void main() {
  testWidgets('is empty before the first answer', (tester) async {
    await _pump(tester, const []);

    expect(find.text(DiaryInterviewCopy.emotionUnknown), findsOneWidget);
    expect(_fill(tester), 0);
  });

  testWidgets('shows the latest emotion and how clearly it was recognized', (
    tester,
  ) async {
    await _pump(tester, const [
      AnswerEmotionRecord.done(_angry),
      AnswerEmotionRecord.done(_sad),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('슬픔'), findsOneWidget);
    expect(find.text('분노'), findsNothing);
    expect(_fill(tester), closeTo(72 * 0.5, 0.01));
  });

  testWidgets('keeps the last result while analyzing or after a failure', (
    tester,
  ) async {
    for (final pending in const [
      AnswerEmotionRecord.analyzing(),
      AnswerEmotionRecord.failed(),
    ]) {
      await _pump(tester, [const AnswerEmotionRecord.done(_angry), pending]);
      await tester.pumpAndSettle();

      expect(find.text('분노'), findsOneWidget);
      expect(_fill(tester), closeTo(72 * 0.9, 0.01));
    }
  });

  testWidgets('does not guess when the answer had no clear emotion', (
    tester,
  ) async {
    await _pump(tester, const [
      AnswerEmotionRecord.done(_angry),
      AnswerEmotionRecord.done(_unclear),
    ]);
    await tester.pumpAndSettle();

    expect(find.text(DiaryInterviewCopy.emotionUnknown), findsOneWidget);
    expect(_fill(tester), 0);
  });
}
