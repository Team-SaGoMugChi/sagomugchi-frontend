import 'package:flutter_test/flutter_test.dart';
import 'package:oddo/features/baseline/application/baseline_reading_gate.dart';

void main() {
  test('silence and invalid microphone samples never permit advancing', () {
    final gate = BaselineReadingGate();
    for (final db in [-80.0, -40.0, double.nan, double.infinity]) {
      for (var i = 0; i < 20; i++) {
        gate.add(db);
      }
    }
    expect(gate.canContinue, isFalse);
  });
  test('each sentence needs new microphone activity', () {
    final gate = BaselineReadingGate();
    for (var i = 0; i < 3; i++) {
      gate.add(-20);
    }
    expect(gate.canContinue, isFalse);
    gate.add(-20);
    expect(gate.canContinue, isTrue);
    gate.reset();
    expect(gate.canContinue, isFalse);
  });
}
