import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/domain/models/exercise_model.dart';
import 'package:ironlog/domain/models/set_model.dart';
import 'package:ironlog/domain/models/workout_model.dart';
import 'package:ironlog/domain/models/suggestion_model.dart';
import 'package:ironlog/domain/services/weight_step_learner.dart';
import 'package:ironlog/domain/services/suggestion_engine.dart';

void main() {
  final testExercise = ExerciseModel(
    id: 'bench_press',
    name: 'Barbell Bench Press',
    muscleGroupId: 'chest',
    secondaryGroups: ['triceps', 'shoulders'],
    equipment: EquipmentType.barbell,
    loadMode: LoadMode.total,
    isUnilateral: false,
    weightStep: 2.5,
    repMin: 8,
    repMax: 10,
    restSeconds: 120,
    isCustom: false,
    archived: false,
  );

  group('SuggestionEngine Rules Tests', () {
    test('ProgressHoldRule: Steps up weight when all working sets hit rep_max', () {
      final lastWeekSets = [
        SetModel(
          id: 's1',
          workoutExerciseId: 'we_prev',
          exerciseId: 'bench_press',
          muscleGroupId: 'chest',
          date: DateTime.now().subtract(const Duration(days: 3)),
          setIndex: 1,
          weight: 80.0,
          reps: 10, // hit rep_max (10)
          setType: SetType.working,
          completedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        SetModel(
          id: 's2',
          workoutExerciseId: 'we_prev',
          exerciseId: 'bench_press',
          muscleGroupId: 'chest',
          date: DateTime.now().subtract(const Duration(days: 3)),
          setIndex: 2,
          weight: 80.0,
          reps: 10, // hit rep_max (10)
          setType: SetType.working,
          completedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

      final prevWorkout = WorkoutModel(
        id: 'prev_w',
        date: DateTime.now().subtract(const Duration(days: 3)),
        title: 'Push Day',
        exercises: [
          WorkoutExerciseItem(
            id: 'we_prev',
            workoutId: 'prev_w',
            exercise: testExercise,
            position: 0,
            sets: lastWeekSets,
          ),
        ],
      );

      final currentWorkout = WorkoutModel(
        id: 'curr_w',
        date: DateTime.now(),
        title: 'Today Workout',
        exercises: [
          WorkoutExerciseItem(
            id: 'we_curr',
            workoutId: 'curr_w',
            exercise: testExercise,
            position: 0,
            sets: [],
          ),
        ],
      );

      final rule = ProgressHoldRule();
      final results = rule.evaluate(
        currentWorkout: currentWorkout,
        history: [prevWorkout],
      );

      expect(results.length, equals(1));
      final s = results.first;
      expect(s.reasonCode, equals('PROGRESS_OVERLOAD_STEP_UP'));
      expect(s.payload['suggestedWeight'], equals(82.5)); // 80 + 2.5
      expect(s.payload['suggestedReps'], equals(8)); // repMin
    });

    test('ProgressHoldRule: Holds weight and targets rep + 1 when sets did not hit rep_max', () {
      final lastWeekSets = [
        SetModel(
          id: 's1',
          workoutExerciseId: 'we_prev',
          exerciseId: 'bench_press',
          muscleGroupId: 'chest',
          date: DateTime.now().subtract(const Duration(days: 3)),
          setIndex: 1,
          weight: 80.0,
          reps: 10,
          setType: SetType.working,
          completedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        SetModel(
          id: 's2',
          workoutExerciseId: 'we_prev',
          exerciseId: 'bench_press',
          muscleGroupId: 'chest',
          date: DateTime.now().subtract(const Duration(days: 3)),
          setIndex: 2,
          weight: 80.0,
          reps: 8, // fell short of 10
          setType: SetType.working,
          completedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

      final prevWorkout = WorkoutModel(
        id: 'prev_w',
        date: DateTime.now().subtract(const Duration(days: 3)),
        title: 'Push Day',
        exercises: [
          WorkoutExerciseItem(
            id: 'we_prev',
            workoutId: 'prev_w',
            exercise: testExercise,
            position: 0,
            sets: lastWeekSets,
          ),
        ],
      );

      final currentWorkout = WorkoutModel(
        id: 'curr_w',
        date: DateTime.now(),
        title: 'Today Workout',
        exercises: [
          WorkoutExerciseItem(
            id: 'we_curr',
            workoutId: 'curr_w',
            exercise: testExercise,
            position: 0,
            sets: [],
          ),
        ],
      );

      final rule = ProgressHoldRule();
      final results = rule.evaluate(
        currentWorkout: currentWorkout,
        history: [prevWorkout],
      );

      expect(results.length, equals(1));
      final s = results.first;
      expect(s.reasonCode, equals('PROGRESS_HOLD_REPS_UP'));
      expect(s.payload['suggestedWeight'], equals(80.0));
      expect(s.payload['suggestedReps'], equals(9)); // minReps (8) + 1
    });

    test('FatigueRule: Flags when intra-session reps drop > 40%', () {
      final activeSets = [
        SetModel(
          id: 's1',
          workoutExerciseId: 'we_curr',
          exerciseId: 'bench_press',
          muscleGroupId: 'chest',
          date: DateTime.now(),
          setIndex: 1,
          weight: 100.0,
          reps: 10,
          setType: SetType.working,
          completedAt: DateTime.now(),
        ),
        SetModel(
          id: 's2',
          workoutExerciseId: 'we_curr',
          exerciseId: 'bench_press',
          muscleGroupId: 'chest',
          date: DateTime.now(),
          setIndex: 2,
          weight: 100.0,
          reps: 5, // (10 - 5)/10 = 50% drop > 40%
          setType: SetType.working,
          completedAt: DateTime.now(),
        ),
      ];

      final currentWorkout = WorkoutModel(
        id: 'curr_w',
        date: DateTime.now(),
        title: 'Today Workout',
        exercises: [
          WorkoutExerciseItem(
            id: 'we_curr',
            workoutId: 'curr_w',
            exercise: testExercise,
            position: 0,
            sets: activeSets,
          ),
        ],
      );

      final rule = FatigueRule();
      final results = rule.evaluate(
        currentWorkout: currentWorkout,
        history: [],
      );

      expect(results.length, equals(1));
      expect(results.first.reasonCode, equals('INTRA_SESSION_FATIGUE_DROP'));
    });

    test('ComebackRule: Suggests 90% load after 14+ days absence', () {
      final oldSets = [
        SetModel(
          id: 's1',
          workoutExerciseId: 'we_old',
          exerciseId: 'bench_press',
          muscleGroupId: 'chest',
          date: DateTime.now().subtract(const Duration(days: 20)),
          setIndex: 1,
          weight: 100.0,
          reps: 10,
          setType: SetType.working,
          completedAt: DateTime.now().subtract(const Duration(days: 20)),
        ),
      ];

      final oldWorkout = WorkoutModel(
        id: 'old_w',
        date: DateTime.now().subtract(const Duration(days: 20)),
        title: 'Push Day',
        exercises: [
          WorkoutExerciseItem(
            id: 'we_old',
            workoutId: 'old_w',
            exercise: testExercise,
            position: 0,
            sets: oldSets,
          ),
        ],
      );

      final currentWorkout = WorkoutModel(
        id: 'curr_w',
        date: DateTime.now(),
        title: 'Today Workout',
        exercises: [
          WorkoutExerciseItem(
            id: 'we_curr',
            workoutId: 'curr_w',
            exercise: testExercise,
            position: 0,
            sets: [],
          ),
        ],
      );

      final rule = ComebackRule();
      final results = rule.evaluate(
        currentWorkout: currentWorkout,
        history: [oldWorkout],
      );

      expect(results.length, equals(1));
      expect(results.first.reasonCode, equals('COMEBACK_DETRAINING_RESET'));
      expect(results.first.payload['targetWeight'], equals(90.0)); // 100 * 0.90
    });

    test('NextWorkoutRule: Proposes routine for empty workout', () {
      final currentWorkout = WorkoutModel(
        id: 'empty_w',
        date: DateTime.now(),
        title: 'Empty Workout',
        exercises: [],
      );

      final rule = NextWorkoutRule();
      final results = rule.evaluate(
        currentWorkout: currentWorkout,
        history: [],
      );

      expect(results.length, equals(1));
      expect(results.first.type, equals(SuggestionType.nextWorkout));
      expect(results.first.actionLabel, isNotNull);
    });
  });
}
