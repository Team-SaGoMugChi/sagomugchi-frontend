import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/baseline/presentation/screens/baseline_ready_screen.dart';
import 'package:oddo/features/baseline/presentation/widgets/baseline_guide_film.dart';
import 'package:oddo/widgets/primary_button.dart';

void main() {
  testWidgets('preparation requires each confirmation and supports undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: BaselineReadyScreen()));
    // All three preparations should be visible before the user scrolls.
    for (var i = 0; i < 3; i++) {
      expect(
        find.byKey(ValueKey('baseline-ready-$i')).hitTestable(),
        findsOneWidget,
      );
    }
    PrimaryButton action() =>
        tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(action().enabled, isFalse);
    for (var i = 0; i < 3; i++) {
      final item = find.byKey(ValueKey('baseline-ready-$i'));
      await tester.ensureVisible(item);
      await tester.tap(
        find.descendant(of: item, matching: find.byType(Checkbox)),
      );
      await tester.pump();
      expect(action().enabled, i == 2);
    }
    final first = find.byKey(const ValueKey('baseline-ready-0'));
    await tester.ensureVisible(first);
    await tester.tap(
      find.descendant(of: first, matching: find.byType(Checkbox)),
    );
    await tester.pump();
    expect(action().enabled, isFalse);
    expect(action().label, '준비 확인 2/3');
    expect(tester.takeException(), isNull);
  });

  testWidgets('preparation has only three checks without repeating the video', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BaselineReadyScreen()));
    expect(find.byType(BaselineGuideFilm), findsNothing);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(find.byType(TextButton), findsNothing);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).enabled,
      isFalse,
    );
    expect(find.text('준비 확인 0/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
