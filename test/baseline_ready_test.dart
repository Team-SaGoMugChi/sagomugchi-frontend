import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/baseline/presentation/screens/baseline_ready_screen.dart';
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

  testWidgets('help expands independently of confirmation and can collapse', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BaselineReadyScreen()));
    final help = find.byKey(const ValueKey('baseline-help-0'));
    await tester.ensureVisible(help);
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.textContaining('눈·코·입이 모두'), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).enabled,
      isFalse,
    );
    expect(find.text('준비 확인 0/3'), findsOneWidget);
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.textContaining('눈·코·입이 모두'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
