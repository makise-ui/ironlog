import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/data/repositories/workout_repository.dart';
import 'package:ironlog/domain/services/weight_step_learner.dart';
import 'package:ironlog/domain/models/exercise_model.dart';
import 'package:ironlog/domain/models/muscle_recovery_model.dart';
import 'package:ironlog/domain/models/set_model.dart';
import 'package:ironlog/domain/models/workout_debrief_model.dart';
import 'package:ironlog/domain/models/workout_model.dart';

void main() {
  group('MuscleRecoveryData Model Tests', () {
    test('Correctly identifies ready, recovering, and fatigued states', () {
      const readyMuscle = MuscleRecoveryData(
        id: 'chest',
        name: 'Chest',
        recoveryPercent: 0.95,
        hoursSinceLastTrained: 72,
        weeklySetsCount: 8,
        status: 'Recovered',
        tip: 'Ready to train',
      );
      expect(readyMuscle.state, MuscleRecoveryState.ready);
      expect(readyMuscle.color, const Color(0xFF10B981));

      const recoveringMuscle = MuscleRecoveryData(
        id: 'back',
        name: 'Back',
        recoveryPercent: 0.60,
        hoursSinceLastTrained: 24,
        weeklySetsCount: 12,
        status: 'Recovering',
        tip: 'Recovering nicely',
      );
      expect(recoveringMuscle.state, MuscleRecoveryState.recovering);
      expect(recoveringMuscle.color, const Color(0xFFF59E0B));

      const fatiguedMuscle = MuscleRecoveryData(
        id: 'legs',
        name: 'Legs',
        recoveryPercent: 0.30,
        hoursSinceLastTrained: 6,
        weeklySetsCount: 16,
        status: 'Fatigued',
        tip: 'Deep fatigue',
      );
      expect(fatiguedMuscle.state, MuscleRecoveryState.fatigued);
      expect(fatiguedMuscle.color, const Color(0xFFEF4444));
    });
  });

  group('WorkoutDebriefData Model Tests', () {
    test('Calculates volume surge and deload flags properly', () {
      final now = DateTime.now();
      final workout = WorkoutModel(
        id: 'w-1',
        date: now,
        title: 'Upper Body Power',
        exercises: const [],
      );

      final surgeDebrief = WorkoutDebriefData(
        workout: workout,
        duration: const Duration(minutes: 50),
        brokenPrs: const [],
        currentVolume: 6000,
        baselineVolume: 5000,
        volumeDeltaPercent: 20.0,
        muscleSets: const {'chest': 6, 'triceps': 4},
        primaryFatiguedMuscles: const ['chest', 'triceps'],
        headline: 'High Volume Surge!',
        volumeInsight: '+20% vs baseline',
        recoveryAdvice: 'Rest 48h',
        nutritionTip: 'High protein',
      );

      expect(surgeDebrief.isVolumeSurge, isTrue);
      expect(surgeDebrief.isVolumeDeload, isFalse);
      expect(surgeDebrief.hasPrs, isFalse);

      final deloadDebrief = WorkoutDebriefData(
        workout: workout,
        duration: const Duration(minutes: 30),
        brokenPrs: const [],
        currentVolume: 3500,
        baselineVolume: 5000,
        volumeDeltaPercent: -30.0,
        muscleSets: const {'chest': 3},
        primaryFatiguedMuscles: const ['chest'],
        headline: 'Deload Session',
        volumeInsight: '-30% vs baseline',
        recoveryAdvice: 'Active recovery',
        nutritionTip: 'Moderate protein',
      );

      expect(deloadDebrief.isVolumeDeload, isTrue);
      expect(deloadDebrief.isVolumeSurge, isFalse);
    });
  });

  group('WorkoutRepository Recovery & Debrief Integration', () {
    late AppDatabase db;
    late WorkoutRepository repo;

    setUp(() {
      db = AppDatabase.memory();
      repo = WorkoutRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('getMuscleRecoveryStatus returns all tracked muscle groups with full recovery when empty', () async {
      final statusMap = await repo.getMuscleRecoveryStatus();
      expect(statusMap.containsKey('chest'), isTrue);
      expect(statusMap.containsKey('back'), isTrue);
      expect(statusMap.containsKey('legs'), isTrue);
      expect(statusMap.containsKey('shoulders'), isTrue);
      expect(statusMap.containsKey('biceps'), isTrue);
      expect(statusMap.containsKey('triceps'), isTrue);
      expect(statusMap.containsKey('glutes'), isTrue);
      expect(statusMap.containsKey('core'), isTrue);
      expect(statusMap.containsKey('forearms'), isTrue);

      // When no recent workouts, muscle should be 100% recovered
      expect(statusMap['chest']!.recoveryPercent, 1.0);
      expect(statusMap['chest']!.state, MuscleRecoveryState.ready);
    });

    test('getWorkoutDebrief identifies broken PRs and computes volume breakdown', () async {
      final now = DateTime.now();
      const exercise = ExerciseModel(
        id: 'bench-press-1',
        name: 'Barbell Bench Press',
        muscleGroupId: 'chest',
        equipment: EquipmentType.barbell,
      );

      final workout = WorkoutModel(
        id: 'w-test',
        date: now,
        title: 'Chest Day Test',
        exercises: [
          WorkoutExerciseItem(
            id: 'we-1',
            workoutId: 'w-test',
            exercise: exercise,
            position: 1,
            sets: [
              SetModel(
                id: 'set-1',
                workoutExerciseId: 'we-1',
                exerciseId: exercise.id,
                muscleGroupId: 'chest',
                date: now,
                setIndex: 1,
                weight: 100.0,
                reps: 8,
                setType: SetType.working,
                completedAt: now,
              ),
            ],
          ),
        ],
      );

      final debrief = await repo.getWorkoutDebrief(workout, elapsed: const Duration(minutes: 45));
      expect(debrief.workout.id, 'w-test');
      expect(debrief.currentVolume, 800.0);
      expect(debrief.muscleSets['chest'], 1);
      expect(debrief.primaryFatiguedMuscles, contains('chest'));
      expect(debrief.brokenPrs.isNotEmpty, isTrue);
      expect(debrief.brokenPrs.first.exerciseId, exercise.id);
      expect(debrief.brokenPrs.first.value, 100.0);
    });
  });
}
