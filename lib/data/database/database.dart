import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/native.dart';
import 'tables.dart';
import 'seed_data.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  MuscleGroups,
  Exercises,
  Workouts,
  WorkoutExercises,
  Sets,
  Routines,
  RoutineItems,
  Prs,
  Achievements,
  Settings,
  BodyMetrics,
  Photos,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'ironlog_db'));

  AppDatabase.forTesting(super.executor);

  factory AppDatabase.memory() {
    return AppDatabase(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_we_workout_id ON workout_exercises(workout_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sets_we_id ON sets(workout_exercise_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sets_exercise_date ON sets(exercise_id, date);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sets_muscle_group_date ON sets(muscle_group_id, date);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_workouts_date ON workouts(date);',
          );

          // Ensure all seed exercises exist in database (supports newly added defaults)
          for (final ex in SeedData.exercises) {
            await into(exercises).insert(
              ExercisesCompanion.insert(
                id: ex.id,
                name: ex.name,
                muscleGroupId: ex.muscleGroupId,
                secondaryGroups: Value(ex.secondaryGroups),
                equipment: ex.equipment,
                loadMode: Value(ex.loadMode),
                isUnilateral: Value(ex.isUnilateral),
                weightStep: Value(ex.weightStep),
                repMin: Value(ex.repMin),
                repMax: Value(ex.repMax),
                restSeconds: Value(ex.restSeconds),
                isCustom: const Value(false),
                archived: const Value(false),
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
        },
        onCreate: (m) async {
          await m.createAll();

          // Create explicit indexes for performance
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_we_workout_id ON workout_exercises(workout_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sets_we_id ON sets(workout_exercise_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sets_exercise_date ON sets(exercise_id, date);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sets_muscle_group_date ON sets(muscle_group_id, date);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_workouts_date ON workouts(date);',
          );

          // Seed default muscle groups
          for (final mg in SeedData.muscleGroups) {
            await into(muscleGroups).insert(
              MuscleGroupsCompanion.insert(
                id: mg.id,
                name: mg.name,
                color: mg.color,
                icon: mg.icon,
                sort: Value(mg.sort),
              ),
            );
          }

          // Seed ~160 exercises
          for (final ex in SeedData.exercises) {
            await into(exercises).insert(
              ExercisesCompanion.insert(
                id: ex.id,
                name: ex.name,
                muscleGroupId: ex.muscleGroupId,
                secondaryGroups: Value(ex.secondaryGroups),
                equipment: ex.equipment,
                loadMode: Value(ex.loadMode),
                isUnilateral: Value(ex.isUnilateral),
                weightStep: Value(ex.weightStep),
                repMin: Value(ex.repMin),
                repMax: Value(ex.repMax),
                restSeconds: Value(ex.restSeconds),
                isCustom: const Value(false),
                archived: const Value(false),
              ),
            );
          }

          // Seed default routines
          for (final routine in SeedData.defaultRoutines) {
            final routineId = routine['id'] as String;
            final routineName = routine['name'] as String;
            final routineDesc = routine['description'] as String;
            final exList = routine['exercises'] as List<String>;

            await into(routines).insert(
              RoutinesCompanion.insert(
                id: routineId,
                name: routineName,
                description: Value(routineDesc),
                archived: const Value(false),
              ),
            );

            for (int i = 0; i < exList.length; i++) {
              await into(routineItems).insert(
                RoutineItemsCompanion.insert(
                  id: '${routineId}_item_$i',
                  routineId: routineId,
                  exerciseId: exList[i],
                  position: i,
                  targetSets: const Value(3),
                  repMin: const Value(8),
                  repMax: const Value(12),
                  restSeconds: const Value(90),
                ),
              );
            }
          }
        },
        onUpgrade: (m, from, to) async {
          // Future schema migrations
        },
      );
}
