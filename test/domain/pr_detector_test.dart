import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/domain/models/set_model.dart';
import 'package:ironlog/domain/services/pr_detector.dart';

void main() {
  group('PrDetector Tests', () {
    test('First time set creates a starting baseline record', () {
      final newSet = SetModel(
        id: 's1',
        workoutExerciseId: 'we1',
        exerciseId: 'bench',
        muscleGroupId: 'chest',
        date: DateTime.now(),
        setIndex: 1,
        weight: 80.0,
        reps: 10,
        setType: SetType.working,
        completedAt: DateTime.now(),
      );

      final result = PrDetector.checkSetPr(
        newSet: newSet,
        historicalSets: [],
      );

      expect(result.isPr, isTrue);
      expect(result.prType, equals(PrType.maxWeight));
    });

    test('Warmup sets are excluded from PR detection', () {
      final warmup = SetModel(
        id: 's1',
        workoutExerciseId: 'we1',
        exerciseId: 'bench',
        muscleGroupId: 'chest',
        date: DateTime.now(),
        setIndex: 1,
        weight: 150.0, // huge weight, but marked warmup
        reps: 10,
        setType: SetType.warmup,
        completedAt: DateTime.now(),
      );

      final result = PrDetector.checkSetPr(
        newSet: warmup,
        historicalSets: [],
      );

      expect(result.isPr, isFalse);
    });

    test('Detects new heaviest weight PR', () {
      final hist1 = SetModel(
        id: 'h1',
        workoutExerciseId: 'we1',
        exerciseId: 'bench',
        muscleGroupId: 'chest',
        date: DateTime.now().subtract(const Duration(days: 7)),
        setIndex: 1,
        weight: 100.0,
        reps: 5,
        setType: SetType.working,
        completedAt: DateTime.now().subtract(const Duration(days: 7)),
      );

      final newSet = SetModel(
        id: 's1',
        workoutExerciseId: 'we1',
        exerciseId: 'bench',
        muscleGroupId: 'chest',
        date: DateTime.now(),
        setIndex: 1,
        weight: 102.5,
        reps: 5,
        setType: SetType.working,
        completedAt: DateTime.now(),
      );

      final result = PrDetector.checkSetPr(
        newSet: newSet,
        historicalSets: [hist1],
      );

      expect(result.isPr, isTrue);
      expect(result.prType, equals(PrType.maxWeight));
      expect(result.currentValue, equals(102.5));
      expect(result.previousRecord, equals(100.0));
    });

    test('Detects new estimated 1RM PR when weight is same or lower but reps are higher', () {
      final hist1 = SetModel(
        id: 'h1',
        workoutExerciseId: 'we1',
        exerciseId: 'bench',
        muscleGroupId: 'chest',
        date: DateTime.now().subtract(const Duration(days: 7)),
        setIndex: 1,
        weight: 100.0,
        reps: 5, // e1RM = 100 * (1 + 5/30) = 116.67
        setType: SetType.working,
        completedAt: DateTime.now().subtract(const Duration(days: 7)),
      );

      final newSet = SetModel(
        id: 's1',
        workoutExerciseId: 'we1',
        exerciseId: 'bench',
        muscleGroupId: 'chest',
        date: DateTime.now(),
        setIndex: 1,
        weight: 95.0,
        reps: 9, // e1RM = 95 * (1 + 9/30) = 95 * 1.3 = 123.5
        setType: SetType.working,
        completedAt: DateTime.now(),
      );

      final result = PrDetector.checkSetPr(
        newSet: newSet,
        historicalSets: [hist1],
      );

      expect(result.isPr, isTrue);
      expect(result.prType, equals(PrType.bestE1rm));
    });

    test('Detects rep record at a specific weight', () {
      final hist1 = SetModel(
        id: 'h1',
        workoutExerciseId: 'we1',
        exerciseId: 'bench',
        muscleGroupId: 'chest',
        date: DateTime.now().subtract(const Duration(days: 7)),
        setIndex: 1,
        weight: 80.0,
        reps: 8,
        setType: SetType.working,
        completedAt: DateTime.now().subtract(const Duration(days: 7)),
      );
      final hist2 = SetModel(
        id: 'h2',
        workoutExerciseId: 'we1',
        exerciseId: 'bench',
        muscleGroupId: 'chest',
        date: DateTime.now().subtract(const Duration(days: 14)),
        setIndex: 1,
        weight: 120.0, // higher max weight in past
        reps: 3, // e1RM = 132
        setType: SetType.working,
        completedAt: DateTime.now().subtract(const Duration(days: 14)),
      );

      final newSet = SetModel(
        id: 's1',
        workoutExerciseId: 'we1',
        exerciseId: 'bench',
        muscleGroupId: 'chest',
        date: DateTime.now(),
        setIndex: 1,
        weight: 80.0,
        reps: 11, // beats 8 reps at 80kg (though e1RM is 109 < 132)
        setType: SetType.working,
        completedAt: DateTime.now(),
      );

      final result = PrDetector.checkSetPr(
        newSet: newSet,
        historicalSets: [hist1, hist2],
      );

      expect(result.isPr, isTrue);
      expect(result.prType, equals(PrType.repsAtWeight));
      expect(result.currentValue, equals(11.0));
      expect(result.previousRecord, equals(8.0));
    });
  });
}
