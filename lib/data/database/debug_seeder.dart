import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';
import '../../core/utils/date_utils.dart';

class DebugSeeder {
  DebugSeeder._();

  static Future<int> seedSixMonthsRealisticData(AppDatabase db) async {
    final uuid = const Uuid();
    final random = math.Random(42);

    // Fetch existing exercises
    final exercises = await (db.select(db.exercises)..where((t) => t.archived.equals(false))).get();
    if (exercises.isEmpty) return 0;

    final chestExercises = exercises.where((e) => e.muscleGroupId == 'chest').toList();
    final backExercises = exercises.where((e) => e.muscleGroupId == 'back').toList();
    final legExercises = exercises.where((e) => e.muscleGroupId == 'legs').toList();
    final shoulderExercises = exercises.where((e) => e.muscleGroupId == 'shoulders').toList();
    final armExercises = exercises.where((e) => e.muscleGroupId == 'biceps' || e.muscleGroupId == 'triceps').toList();

    int totalSetsCreated = 0;
    final now = DateTime.now();

    // 26 weeks (6 months)
    await db.transaction(() async {
      for (int week = 25; week >= 0; week--) {
        // 4 sessions per week: Mon (Push), Wed (Pull), Fri (Legs), Sat (Upper/Arms)
        final weekStart = now.subtract(Duration(days: week * 7));

        final sessionDays = [1, 3, 5, 6]; // Mon, Wed, Fri, Sat
        final sessionSplits = [
          ('Push Day (Chest, Shoulders)', [...chestExercises.take(3), ...shoulderExercises.take(2)]),
          ('Pull Day (Back, Biceps)', [...backExercises.take(4), ...armExercises.take(2)]),
          ('Leg Day (Quads, Hamstrings)', [...legExercises.take(5)]),
          ('Upper Hypertrophy', [...chestExercises.skip(3).take(2), ...backExercises.skip(3).take(2), ...armExercises.take(2)]),
        ];

        for (int s = 0; s < sessionDays.length; s++) {
          final dayOffset = sessionDays[s] - 1;
          final workoutDate = AppDateUtils.normalizeDate(weekStart.add(Duration(days: dayOffset)));
          if (workoutDate.isAfter(now)) continue;

          final workoutId = uuid.v4();
          final split = sessionSplits[s];

          await db.into(db.workouts).insert(
            WorkoutsCompanion.insert(
              id: workoutId,
              date: workoutDate,
              startedAt: Value(workoutDate.add(const Duration(hours: 17))),
              endedAt: Value(workoutDate.add(const Duration(hours: 18, minutes: 15))),
              title: split.$1,
              feel: Value(3 + random.nextInt(3)), // 3, 4, 5
              archived: const Value(false),
            ),
          );

          int pos = 0;
          for (final ex in split.$2) {
            final weId = uuid.v4();
            await db.into(db.workoutExercises).insert(
              WorkoutExercisesCompanion.insert(
                id: weId,
                workoutId: workoutId,
                exerciseId: ex.id,
                position: pos,
                archived: const Value(false),
              ),
            );

            // Progressive overload over 26 weeks (week 0 has lowest, week 25 highest)
            final progressFactor = (26 - week) / 26.0;
            final baseWeight = 40.0 + (random.nextInt(30));
            final currentWeight = baseWeight + (progressFactor * 25.0);

            // 4 sets per exercise
            final numSets = 3 + random.nextInt(2); // 3 to 4 sets
            for (int setIdx = 1; setIdx <= numSets; setIdx++) {
              final isWarmup = setIdx == 1;
              final weight = isWarmup
                  ? (currentWeight * 0.6).roundToDouble()
                  : (currentWeight + (setIdx * 2.5)).roundToDouble();
              final reps = isWarmup ? 12 : (8 + random.nextInt(4));

              await db.into(db.sets).insert(
                SetsCompanion.insert(
                  id: uuid.v4(),
                  workoutExerciseId: weId,
                  exerciseId: ex.id,
                  muscleGroupId: ex.muscleGroupId,
                  date: workoutDate,
                  setIndex: setIdx,
                  weight: weight,
                  reps: reps,
                  setType: isWarmup ? 'warmup' : 'working',
                  completedAt: workoutDate.add(Duration(hours: 17, minutes: pos * 10 + setIdx * 2)),
                  archived: const Value(false),
                ),
              );
              totalSetsCreated++;
            }
            pos++;
          }
        }
      }
    });

    return totalSetsCreated;
  }
}
