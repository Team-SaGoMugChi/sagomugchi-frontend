import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/diary/data/models/counsel_turn_result.dart';
import 'package:oddo/features/diary/presentation/widgets/counsel_crisis_banner.dart';

void main() {
  group('CounselTurnResult.fromJson', () {
    test('reads risk_axis', () {
      final result = CounselTurnResult.fromJson({
        'reply': '안전한 곳으로 가 주세요.',
        'crisis': true,
        'risk_axis': 'danger',
      });
      expect(result.crisis, isTrue);
      expect(result.riskAxis, 'danger');
    });

    test('risk_axis is null for older responses', () {
      final result = CounselTurnResult.fromJson({'reply': '그랬군요.'});
      expect(result.riskAxis, isNull);
    });
  });

  group('CounselCrisisInfo.forAxis', () {
    test('suicide and unknown axes show 109', () {
      expect(CounselCrisisInfo.forAxis('suicide').contacts.first.number, '109');
      expect(CounselCrisisInfo.forAxis(null).contacts.first.number, '109');
    });

    test('danger shows 112 and 1366', () {
      final numbers =
          CounselCrisisInfo.forAxis('danger').contacts.map((c) => c.number);
      expect(numbers, containsAll(['112', '1366']));
    });

    test('harm_others and psychosis show 1577-0199', () {
      for (final axis in ['harm_others', 'psychosis']) {
        final numbers =
            CounselCrisisInfo.forAxis(axis).contacts.map((c) => c.number);
        expect(numbers, contains('15770199'));
      }
    });
  });

  testWidgets('banner shows contacts for the axis', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CounselCrisisBanner(riskAxis: 'danger')),
      ),
    );
    expect(find.text('112 긴급 신고'), findsOneWidget);
    expect(find.text('여성긴급전화 1366'), findsOneWidget);
    expect(find.textContaining('109'), findsNothing);
  });
}