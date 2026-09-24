import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/data/database/debug_seeder.dart';
import 'package:ironlog/data/repositories/exercise_repository.dart';
import 'package:ironlog/data/repositories/workout_repository.dart';
import 'package:ironlog/domain/models/set_model.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository exerciseRepo;
  late WorkoutRepository workoutRepo;

  setUp(() {
    db = AppDatabase.memory();
    exerciseRepo = ExerciseRepository(db);
    workoutRepo = WorkoutRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift Database & Repository Integration Tests', () {
    test('Database seeds default muscle groups and exercises', () async {
      final muscleGroups = await exerciseRepo.getMuscleGroups();
      expect(muscleGroups.length, 10);
      expect(muscleGroups.map((m) => m.name), containsAll(['Chest', 'Back', 'Legs', 'Shoulders']));

      final exercises = await exerciseRepo.getExercises();
      expect(exercises.length, greaterThanOrEqualTo(150));
    });

    test('Workout logging flow with soft delete and restore undo', () async {
      final todayWorkout = await workoutRepo.getOrCreateTodayWorkout(routineTitle: 'Test Push');
      expect(todayWorkout.id, isNotEmpty);

      final exercises = await exerciseRepo.getExercises(muscleGroupId: 'chest');
      expect(exercises.isNotEmpty, true);
      final benchPress = exercises.first;

      // Add exercise to workout
      final weId = await workoutRepo.addExerciseToWorkout(
        workoutId: todayWorkout.id,
        exerciseId: benchPress.id,
      );
      expect(weId, isNotEmpty);

      // Log a set
      final setId = await workoutRepo.logSet(
        workoutExerciseId: weId,
        exerciseId: benchPress.id,
        muscleGroupId: benchPress.muscleGroupId,
        date: DateTime.now(),
        weight: 80.0,
        reps: 10,
        setType: SetType.working,
      );

      var updated = await workoutRepo.getWorkoutById(todayWorkout.id);
      expect(updated.exercises.length, 1);
      expect(updated.exercises.first.sets.length, 1);
      expect(updated.exercises.first.sets.first.weight, 80.0);
      expect(updated.exercises.first.sets.first.reps, 10);

      // Soft delete set
      await workoutRepo.deleteSet(setId);
      updated = await workoutRepo.getWorkoutById(todayWorkout.id);
      expect(updated.exercises.first.sets.isEmpty, true);

      // Restore set (undo)
      await workoutRepo.restoreSet(setId);
      updated = await workoutRepo.getWorkoutById(todayWorkout.id);
      expect(updated.exercises.first.sets.length, 1);
      expect(updated.exercises.first.sets.first.id, setId);
    });

    test('Learned weight step history from database', () async {
      final exercises = await exerciseRepo.getExercises(muscleGroupId: 'chest');
      final benchPress = exercises.first;

      final workout = await workoutRepo.getOrCreateTodayWorkout();
      final weId = await workoutRepo.addExerciseToWorkout(
        workoutId: workout.id,
        exerciseId: benchPress.id,
      );

      await workoutRepo.logSet(
        workoutExerciseId: weId,
        exerciseId: benchPress.id,
        muscleGroupId: benchPress.muscleGroupId,
        date: DateTime.now(),
        weight: 80.0,
        reps: 8,
      );
      await workoutRepo.logSet(
        workoutExerciseId: weId,
        exerciseId: benchPress.id,
        muscleGroupId: benchPress.muscleGroupId,
        date: DateTime.now(),
        weight: 82.5,
        reps: 8,
      );

      final history = await exerciseRepo.getWeightHistory(benchPress.id);
      expect(history, [80.0, 82.5]);
    });

    test('Rest Day marking and arbitrary date rest day support', () async {
      final todayWorkout = await workoutRepo.getOrCreateTodayWorkout();
      expect(todayWorkout.isRestDay, false);

      // Mark today as Rest Day
      await workoutRepo.markAsRestDay(todayWorkout.id, isRest: true);
      var updated = await workoutRepo.getWorkoutById(todayWorkout.id);
      expect(updated.isRestDay, true);
      expect(updated.title, contains('Rest'));

      // Cancel Rest Day
      await workoutRepo.markAsRestDay(todayWorkout.id, isRest: false);
      updated = await workoutRepo.getWorkoutById(todayWorkout.id);
      expect(updated.isRestDay, false);

      // Mark an arbitrary past date as rest day
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await workoutRepo.markDateAsRestDay(yesterday, isRest: true, note: 'Deep tissue recovery');
      final pastWorkout = await workoutRepo.getOrCreateWorkoutForDate(yesterday);
      expect(pastWorkout.isRestDay, true);
      expect(pastWorkout.note, 'Deep tissue recovery');
    });

    test('6-Month historical data batch loading performance and integrity', () async {
      // Seed 26 weeks (~100 workouts, ~1500 sets)
      await workoutRepo.getOrCreateTodayWorkout();
      // Import DebugSeeder
      final count = await DebugSeeder.seedSixMonthsRealisticData(db);
      expect(count, greaterThan(0));

      final stopwatch = Stopwatch()..start();
      final history = await workoutRepo.getHistoryWorkouts(limit: 100);
      stopwatch.stop();

      // Batch query should return all workouts with their exercises and sets intact
      expect(history.length, greaterThan(20));
      expect(history.first.exercises.isNotEmpty, true);
      expect(history.first.exercises.first.sets.isNotEmpty, true);
      // High performance verification: batch query must complete swiftly
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });
  });
}
