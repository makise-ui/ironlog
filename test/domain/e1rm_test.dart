import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/domain/services/e1rm_calculator.dart';

void main() {
  group('E1rmCalculator Tests (Epley formula)', () {
    test('1 rep should equal exact weight', () {
      expect(E1rmCalculator.calculateEpley(100.0, 1), 100.0);
      expect(E1rmCalculator.calculateEpley(65.5, 1), 65.5);
    });

    test('100kg for 10 reps yields ~133.33kg', () {
      final e1rm = E1rmCalculator.calculateEpley(100.0, 10);
      expect(e1rm, closeTo(133.33, 0.01));
    });

    test('60kg for 6 reps yields 72.0kg', () {
      final e1rm = E1rmCalculator.calculateEpley(60.0, 6);
      expect(e1rm, closeTo(72.0, 0.001));
    });

    test('Zero or negative values return 0.0', () {
      expect(E1rmCalculator.calculateEpley(0, 10), 0.0);
      expect(E1rmCalculator.calculateEpley(100, 0), 0.0);
      expect(E1rmCalculator.calculateEpley(-50, 5), 0.0);
    });

    test('Set volume calculation', () {
      expect(E1rmCalculator.calculateSetVolume(50.0, 10), 500.0);
      // per hand multiplies load x 2
      expect(E1rmCalculator.calculateSetVolume(25.0, 10, isPerHand: true), 500.0);
    });
  });
}
