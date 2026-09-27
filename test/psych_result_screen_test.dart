import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/psych_test/data/models/psych_result.dart';
import 'package:oddo/features/psych_test/data/psych_providers.dart';
import 'package:oddo/features/psych_test/data/repositories/psych_repository.dart';
import 'package:oddo/features/psych_test/domain/ipip_big5.dart';
import 'package:oddo/features/psych_test/presentation/screens/psych_test_done_screen.dart';
import 'package:oddo/theme/app_theme.dart';

class _Repository implements PsychRepository {
  @override
  Future<PsychResult?> fetchResult() async => PsychResult(
    big5: const {'O': 75, 'C': 62, 'E': 38, 'A': 81, 'N': 44},
    big5Instrument: ipipBig5Instrument,
    big5CompletedAt: DateTime.utc(2026, 9, 27),
    updatedAt: DateTime.utc(2026, 9, 27),
  );

  @override
  Future<void> saveBig5({
    required Map<String, int> scores,
    required String instrument,
    required DateTime completedAt,
  }) async {}
}

void main() {
  testWidgets(
    'shows stored scores without claiming a percentile or diagnosis',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [psychRepositoryProvider.overrideWithValue(_Repository())],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PsychTestDoneScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['개방성', '성실성', '외향성', '우호성', '정서 민감성']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final score in ['75', '62', '38', '81', '44']) {
        expect(find.text(score), findsOneWidget);
      }
      expect(find.textContaining('백분위나 의학적 진단이 아니에요'), findsOneWidget);
      expect(find.text('MBTI 성격유형 검사'), findsNothing);
    },
  );
}
