import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/domain/services/weight_step_learner.dart';

void main() {
  group('WeightStepLearner Tests', () {
    test('Falls back to equipment defaults when history is empty', () {
      expect(
        WeightStepLearner.learnStep(historicalWeights: [], equipment: EquipmentType.barbell),
        2.5,
      );
      expect(
        WeightStepLearner.learnStep(historicalWeights: [], equipment: EquipmentType.machine),
        5.0,
      );
      expect(
        WeightStepLearner.learnStep(historicalWeights: [], equipment: EquipmentType.dumbbell),
        2.5,
      );
    });

    test('Learns 2.5kg step from standard barbell progression', () {
      final step = WeightStepLearner.learnStep(
        historicalWeights: [60.0, 62.5, 65.0, 70.0],
        equipment: EquipmentType.barbell,
      );
      expect(step, 2.5);
    });

    test('Learns 1.25kg micro-plate step', () {
      final step = WeightStepLearner.learnStep(
        historicalWeights: [80.0, 81.25, 82.5, 85.0],
        equipment: EquipmentType.barbell,
      );
      expect(step, 1.25);
    });

    test('Learns 2.0kg dumbbell step', () {
      final step = WeightStepLearner.learnStep(
        historicalWeights: [10.0, 12.0, 14.0, 16.0],
        equipment: EquipmentType.dumbbell,
      );
      expect(step, 2.0);
    });

    test('Ignores duplicate weights and falls back if all weights are identical', () {
      final step = WeightStepLearner.learnStep(
        historicalWeights: [100.0, 100.0, 100.0, 100.0],
        equipment: EquipmentType.barbell,
      );
      expect(step, 2.5);
    });

    test('Correctly identifies min difference from unsorted history', () {
      final step = WeightStepLearner.learnStep(
        historicalWeights: [75.0, 60.0, 70.0, 67.5, 65.0],
        equipment: EquipmentType.barbell,
      );
      expect(step, 2.5);
    });
  });
}
