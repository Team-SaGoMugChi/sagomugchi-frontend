import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/home/presentation/widgets/weekly_calendar.dart';

void main() {
  testWidgets('swiping the week strip moves the selection a week', (
    tester,
  ) async {
    final selected = DateTime(2026, 11, 2);
    DateTime? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyCalendar(
            days: List.generate(
              7,
              (i) =>
                  DateTime(selected.year, selected.month, selected.day + i - 3),
            ),
            today: selected,
            selected: selected,
            onSelect: (d) => picked = d,
          ),
        ),
      ),
    );

    await tester.fling(
      find.byType(WeeklyCalendar),
      const Offset(-300, 0),
      1000,
    );
    expect(picked, DateTime(2026, 11, 9));

    await tester.fling(find.byType(WeeklyCalendar), const Offset(300, 0), 1000);
    expect(picked, DateTime(2026, 10, 26));
  });
}
