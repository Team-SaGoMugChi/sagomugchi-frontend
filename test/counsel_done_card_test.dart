import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/diary/presentation/widgets/counsel_done_card.dart';

Future<void> _pump(WidgetTester tester, Widget card) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );
}

void main() {
  testWidgets('shows mission and finishes on tap', (tester) async {
    var finished = 0;
    await _pump(
      tester,
      CounselDoneCard(mission: '점심 먹고 10분 산책', onFinish: () => finished++),
    );

    expect(find.text('오늘 상담을 마무리했어요'), findsOneWidget);
    expect(find.text('내일의 미션 · 점심 먹고 10분 산책'), findsOneWidget);

    await tester.tap(find.text('감정 리포트 보기'));
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('hides mission line when there is none', (tester) async {
    await _pump(tester, CounselDoneCard(onFinish: () {}));

    expect(find.text('오늘 상담을 마무리했어요'), findsOneWidget);
    expect(find.textContaining('내일의 미션'), findsNothing);
  });
}