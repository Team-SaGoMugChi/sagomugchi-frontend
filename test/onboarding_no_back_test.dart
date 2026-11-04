import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/auth/presentation/widgets/gender_selector.dart';
import 'package:oddo/features/persona/presentation/screens/persona_intro_screen.dart';
import 'package:oddo/widgets/birth_date_picker.dart';

void main() {
  testWidgets('birth date picker is Korean and returns the chosen date', (
    tester,
  ) async {
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showBirthDatePicker(
              context,
              initial: DateTime(2002, 10, 31),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('생년월일을 선택해주세요'), findsOneWidget);
    expect(find.text('2002년 10월 31일'), findsOneWidget);
    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2002, 10, 31));
  });

  testWidgets('gender has only 여성 and 남성', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GenderSelector())),
    );
    expect(find.text('여성'), findsOneWidget);
    expect(find.text('남성'), findsOneWidget);
    expect(find.text('선택 안 함'), findsNothing);
  });

  testWidgets('persona intro has no back button and blocks system back', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PersonaIntroScreen()));
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    final scope = tester.widget<PopScope>(find.byType(PopScope).first);
    expect(scope.canPop, isFalse);
  });
}
