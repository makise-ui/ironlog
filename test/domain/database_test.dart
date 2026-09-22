import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
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
  });
}
