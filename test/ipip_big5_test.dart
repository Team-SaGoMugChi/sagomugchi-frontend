import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/psych_test/data/models/psych_result.dart';
import 'package:oddo/features/psych_test/domain/ipip_big5.dart';

void main() {
  test('contains 50 items with 10 items per factor', () {
    expect(ipipBig5Items, hasLength(50));
    for (final trait in Big5Trait.values) {
      expect(ipipBig5Items.where((item) => item.trait == trait), hasLength(10));
    }
  });

  test('neutral responses produce midpoint OCEAN scores', () {
    expect(scoreIpipBig5(List.filled(50, 3)), {
      'O': 50,
      'C': 50,
      'E': 50,
      'A': 50,
      'N': 50,
    });
  });

  test('keying direction is applied and stability becomes neuroticism', () {
    final mostStable = ipipBig5Items
        .map((item) => item.positiveKeyed ? 5 : 1)
        .toList();
    expect(scoreIpipBig5(mostStable), {
      'O': 100,
      'C': 100,
      'E': 100,
      'A': 100,
      'N': 0,
    });

    final inverse = mostStable.map((value) => 6 - value).toList();
    expect(scoreIpipBig5(inverse), {'O': 0, 'C': 0, 'E': 0, 'A': 0, 'N': 100});
  });

  test('rejects incomplete and out-of-range responses', () {
    expect(() => scoreIpipBig5(List.filled(49, 3)), throwsArgumentError);
    expect(
      () => scoreIpipBig5([...List.filled(49, 3), 6]),
      throwsArgumentError,
    );
  });

  test('psych result preserves Big Five provenance metadata', () {
    final completedAt = DateTime.utc(2026, 9, 27, 2, 30);
    final original = PsychResult(
      big5: const {'O': 60, 'C': 70, 'E': 40, 'A': 80, 'N': 30},
      big5Instrument: ipipBig5Instrument,
      big5CompletedAt: completedAt,
      updatedAt: completedAt,
    );

    final restored = PsychResult.fromJson(original.toJson());
    expect(restored.big5, original.big5);
    expect(restored.big5Instrument, ipipBig5Instrument);
    expect(restored.big5CompletedAt, completedAt);
  });
}
