import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/domain/services/csv_import_service.dart';
import 'package:ironlog/domain/services/suggestion_engine.dart';
import 'package:ironlog/domain/models/workout_model.dart';
import 'package:ironlog/domain/models/exercise_model.dart';
import 'package:ironlog/domain/models/set_model.dart';
import 'package:ironlog/domain/services/weight_step_learner.dart';

void main() {
  group('Universal CSV Importer Tests', () {
    test('Parses CSV with quoted fields and embedded commas', () {
      const csv = '''date,exercise,weight kg,reps
2026-09-20,"Bench Press, Close Grip",80,10
2026-09-20,"Squat",120,5''';

      final rows = CsvImportService.parseCsv(csv);
      expect(rows.length, 3);
      expect(rows[1][1], 'Bench Press, Close Grip');
      expect(rows[1][2], '80');
      expect(rows[2][1], 'Squat');
    });

    test('Auto-detects source app based on headers', () {
      final hevyHeaders = ['title', 'start_time', 'exercise_title', 'set_index', 'weight_kg', 'reps'];
      expect(CsvImportService.detectSource(hevyHeaders), 'Hevy');

      final strongHeaders = ['Date', 'Workout Name', 'Exercise Name', 'Set Order', 'Weight', 'Reps'];
      expect(CsvImportService.detectSource(strongHeaders), 'Strong');

      final fitNotesHeaders = ['Date', 'Exercise', 'Category', 'Weight', 'Weight Unit', 'Reps'];
      expect(CsvImportService.detectSource(fitNotesHeaders), 'FitNotes');
    });

    test('Normalizes exercise names with equipment brackets', () {
      expect(CsvImportService.normalizeExerciseName('Leg Press (Machine)'), 'Leg Press');
      expect(CsvImportService.normalizeExerciseName('Bench Press (Barbell)'), 'Bench Press');
      expect(CsvImportService.normalizeExerciseName('Bicep Curl (Dumbbell)'), 'Bicep Curl');
      expect(CsvImportService.normalizeExerciseName('Tricep Pushdown (Cable)'), 'Tricep Pushdown');
    });
  });

  group('Progressive Overload Policies Tests', () {
    final testExercise = const ExerciseModel(
      id: 'ex_bench',
      name: 'Barbell Bench Press',
      muscleGroupId: 'chest',
      equipment: EquipmentType.barbell,
      weightStep: 2.5,
      repMin: 5,
      repMax: 5,
    );

    final currentWorkout = WorkoutModel(
      id: 'w_today',
      date: DateTime.now(),
      title: 'Chest Day',
      exercises: [
        WorkoutExerciseItem(
          id: 'we_today_bench',
          workoutId: 'w_today',
          exercise: testExercise,
          position: 0,
          sets: [],
        ),
      ],
    );

    test('Linear Progression Rule: Hit all target reps advances weight by step', () {
      final prevWorkout = WorkoutModel(
        id: 'w_prev',
        date: DateTime.now().subtract(const Duration(days: 3)),
        title: 'Chest Day',
        exercises: [
          WorkoutExerciseItem(
            id: 'we_prev_bench',
            workoutId: 'w_prev',
            exercise: testExercise,
            position: 0,
            sets: [
              SetModel(
                id: 's1',
                workoutExerciseId: 'we_prev_bench',
                exerciseId: 'ex_bench',
                muscleGroupId: 'chest',
                date: DateTime.now().subtract(const Duration(days: 3)),
                setIndex: 1,
                weight: 100.0,
                reps: 5,
                setType: SetType.working,
                completedAt: DateTime.now(),
              ),
              SetModel(
                id: 's2',
                workoutExerciseId: 'we_prev_bench',
                exerciseId: 'ex_bench',
                muscleGroupId: 'chest',
                date: DateTime.now().subtract(const Duration(days: 3)),
                setIndex: 2,
                weight: 100.0,
                reps: 5,
                setType: SetType.working,
                completedAt: DateTime.now(),
              ),
            ],
          ),
        ],
      );

      final rule = LinearProgressionRule();
      final results = rule.evaluate(currentWorkout: currentWorkout, history: [prevWorkout]);

      expect(results.length, 1);
      expect(results.first.reasonCode, 'LINEAR_PROGRESSION_ADVANCE');
      expect(results.first.payload?['suggestedWeight'], 102.5);
    });

    test('Greyskull LP Rule: Beating AMRAP target by 5+ reps triggers double jump', () {
      final prevWorkout = WorkoutModel(
        id: 'w_prev',
        date: DateTime.now().subtract(const Duration(days: 3)),
        title: 'Chest Day',
        exercises: [
          WorkoutExerciseItem(
            id: 'we_prev_bench',
            workoutId: 'w_prev',
            exercise: testExercise,
            position: 0,
            sets: [
              SetModel(
                id: 's1',
                workoutExerciseId: 'we_prev_bench',
                exerciseId: 'ex_bench',
                muscleGroupId: 'chest',
                date: DateTime.now().subtract(const Duration(days: 3)),
                setIndex: 1,
                weight: 100.0,
                reps: 5,
                setType: SetType.working,
                completedAt: DateTime.now(),
              ),
              SetModel(
                id: 's2',
                workoutExerciseId: 'we_prev_bench',
                exerciseId: 'ex_bench',
                muscleGroupId: 'chest',
                date: DateTime.now().subtract(const Duration(days: 3)),
                setIndex: 2,
                weight: 100.0,
                reps: 11, // AMRAP with 11 reps (5 + 6 reps)
                setType: SetType.working,
                completedAt: DateTime.now(),
              ),
            ],
          ),
        ],
      );

      final rule = GreyskullLpRule();
      final results = rule.evaluate(currentWorkout: currentWorkout, history: [prevWorkout]);

      expect(results.length, 1);
      expect(results.first.reasonCode, 'GREYSKULL_DOUBLE_ADVANCE');
      expect(results.first.payload?['suggestedWeight'], 105.0); // +5.0 kg double jump
    });
  });
}
