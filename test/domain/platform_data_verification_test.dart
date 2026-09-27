import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/data/repositories/exercise_repository.dart';
import 'package:ironlog/data/repositories/workout_repository.dart';
import 'package:ironlog/domain/models/exercise_model.dart';
import 'package:ironlog/domain/services/csv_import_service.dart';
import 'package:ironlog/domain/services/e1rm_calculator.dart';
import 'package:ironlog/domain/services/weight_step_learner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Platform Data Integrity & Schema Verification', () {
    test('opengym_exercises.json exists, is valid JSON, and has 1324 cleaned exercises', () {
      final file = File('assets/exercises/opengym_exercises.json');
      expect(file.existsSync(), isTrue, reason: 'assets/exercises/opengym_exercises.json must exist');

      final content = file.readAsStringSync();
      final List<dynamic> list = jsonDecode(content);
      expect(list.length, equals(1324));

      final validMuscleGroups = {
        'chest', 'back', 'legs', 'shoulders', 'biceps',
        'triceps', 'glutes', 'forearms', 'core', 'cardio'
      };

      final validLoadModes = {'total', 'per_hand', 'bodyweight', 'assisted'};
      final validTrackingTypes = {'weightAndReps', 'bodyweightReps', 'duration', 'cardioTime'};

      for (int i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final name = item['name'] as String?;
        expect(name, isNotNull, reason: 'Exercise at $i has null name');
        expect(name!.isNotEmpty, isTrue, reason: 'Exercise at $i has empty name');

        final mgId = item['muscleGroupId'] as String?;
        expect(validMuscleGroups.contains(mgId), isTrue,
            reason: 'Exercise "$name" has invalid muscleGroupId: $mgId');

        final eq = item['equipment'] as String?;
        expect(eq, isNotNull, reason: 'Exercise "$name" has null equipment');
        expect(eq!.isNotEmpty, isTrue);

        final loadMode = item['loadMode'] as String?;
        expect(validLoadModes.contains(loadMode), isTrue,
            reason: 'Exercise "$name" has invalid loadMode: $loadMode');

        final trackingType = item['trackingType'] as String?;
        expect(validTrackingTypes.contains(trackingType), isTrue,
            reason: 'Exercise "$name" has invalid trackingType: $trackingType');

        final weightStep = (item['weightStep'] as num?)?.toDouble();
        expect(weightStep, isNotNull, reason: 'Exercise "$name" has null weightStep');
        expect(weightStep! >= 0.0, isTrue);

        final repMin = (item['repMin'] as num?)?.toInt();
        final repMax = (item['repMax'] as num?)?.toInt();
        expect(repMin, isNotNull, reason: 'Exercise "$name" has null repMin');
        expect(repMax, isNotNull, reason: 'Exercise "$name" has null repMax');
        expect(repMin! >= 1, isTrue, reason: 'repMin < 1 for "$name"');
        expect(repMax! >= repMin, isTrue, reason: 'repMax < repMin for "$name"');

        final restSeconds = (item['restSeconds'] as num?)?.toInt();
        expect(restSeconds, isNotNull, reason: 'Exercise "$name" has null restSeconds');
        expect(restSeconds! >= 30 && restSeconds <= 300, isTrue,
            reason: 'restSeconds $restSeconds out of reasonable range for "$name"');
      }
    });

    test('exercise_instructions.json exists and contains coaching cues for exercises', () {
      final file = File('assets/exercises/exercise_instructions.json');
      expect(file.existsSync(), isTrue, reason: 'exercise_instructions.json must exist');

      final content = file.readAsStringSync();
      final Map<String, dynamic> instructionsMap = jsonDecode(content);
      expect(instructionsMap.length, greaterThanOrEqualTo(1300));

      // Verify a sample instruction has non-empty steps
      final firstKey = instructionsMap.keys.first;
      final steps = instructionsMap[firstKey] as List<dynamic>;
      expect(steps.isNotEmpty, isTrue);
      expect(steps.first, isA<String>());
    });
  });

  group('Drift SQLite Seeding & Foreign Key Integrity with Actual Data', () {
    test('seedOpenGymCatalog loads 1300+ exercises into Drift DB with 0 FK errors', () async {
      // 1. Initial state has default 160 seed exercises
      final initialExercises = await exerciseRepo.getExercises();
      expect(initialExercises.length, greaterThanOrEqualTo(150));

      // 2. Seed openGym catalog
      final insertedCount = await exerciseRepo.seedOpenGymCatalog();
      expect(insertedCount, greaterThanOrEqualTo(1200));

      // 3. Total exercises in DB should exceed 1400
      final allExercises = await exerciseRepo.getExercises();
      expect(allExercises.length, greaterThanOrEqualTo(1400));

      // 4. Verify foreign key integrity for every single exercise in the database
      final validDbMuscleGroups = (await exerciseRepo.getMuscleGroups()).map((m) => m.id).toSet();
      expect(validDbMuscleGroups.length, equals(10));

      for (final ex in allExercises) {
        expect(validDbMuscleGroups.contains(ex.muscleGroupId), isTrue,
            reason: 'Exercise ${ex.id} (${ex.name}) references invalid muscle group ${ex.muscleGroupId}');
        expect(ex.weightStep, isNotNull);
        expect(ex.weightStep >= 0.0, isTrue);
        expect(ex.repMin, isNotNull);
        expect(ex.repMax, isNotNull);
        expect(ex.repMin <= ex.repMax, isTrue);
        expect(ex.restSeconds, isNotNull);
        expect(ex.restSeconds >= 0, isTrue);
      }

      // 5. Reseeding must be idempotent and update existing rows without error
      final reseedCount = await exerciseRepo.seedOpenGymCatalog();
      expect(reseedCount, equals(0));

      final countAfterReseed = await exerciseRepo.getExercises();
      expect(countAfterReseed.length, equals(allExercises.length));
    });

    test('All 10 muscle groups return non-empty exercise sets from the catalog', () async {
      await exerciseRepo.seedOpenGymCatalog();

      final muscleGroups = await exerciseRepo.getMuscleGroups();
      expect(muscleGroups.length, 10);

      for (final mg in muscleGroups) {
        final list = await exerciseRepo.getExercises(muscleGroupId: mg.id);
        expect(list.isNotEmpty, isTrue,
            reason: 'Muscle group "${mg.name}" (${mg.id}) should have exercises');
      }
    });

    test('Search functionality queries across the entire 1400+ library', () async {
      await exerciseRepo.seedOpenGymCatalog();
      final all = await exerciseRepo.getExercises();

      final benchResults = all.where((e) => e.name.toLowerCase().contains('bench')).toList();
      expect(benchResults.length, greaterThanOrEqualTo(5));

      final curlResults = all.where((e) => e.name.toLowerCase().contains('curl')).toList();
      expect(curlResults.length, greaterThanOrEqualTo(10));

      final squatResults = all.where((e) => e.name.toLowerCase().contains('squat')).toList();
      expect(squatResults.length, greaterThanOrEqualTo(5));
    });
  });

  group('Workout Logging & Analytics Flow with Seeded openGym Exercises', () {
    test('Can log sets for openGym exercises with different load modes and calculate volume', () async {
      await exerciseRepo.seedOpenGymCatalog();

      final todayWorkout = await workoutRepo.getOrCreateTodayWorkout(routineTitle: 'Upper Body Test');
      expect(todayWorkout.id, isNotEmpty);

      // Find an openGym dumbbell exercise (per_hand)
      final allExercises = await exerciseRepo.getExercises();
      final dumbbellEx = allExercises.firstWhere(
        (e) => e.loadMode == LoadMode.perHand && e.muscleGroupId == 'biceps',
      );
      final barbellEx = allExercises.firstWhere(
        (e) => e.loadMode == LoadMode.total && e.muscleGroupId == 'chest',
      );
      final bodyweightEx = allExercises.firstWhere(
        (e) => e.loadMode == LoadMode.bodyweight && (e.muscleGroupId == 'core' || e.muscleGroupId == 'back'),
      );

      // Add all 3 to workout
      final weDb = await workoutRepo.addExerciseToWorkout(workoutId: todayWorkout.id, exerciseId: dumbbellEx.id);
      final weBb = await workoutRepo.addExerciseToWorkout(workoutId: todayWorkout.id, exerciseId: barbellEx.id);
      final weBw = await workoutRepo.addExerciseToWorkout(workoutId: todayWorkout.id, exerciseId: bodyweightEx.id);

      // Log sets for each
      await workoutRepo.logSet(
        workoutExerciseId: weDb,
        exerciseId: dumbbellEx.id,
        muscleGroupId: dumbbellEx.muscleGroupId,
        date: todayWorkout.date,
        weight: 14.0,
        reps: 12,
        rpe: 8.0,
      );

      await workoutRepo.logSet(
        workoutExerciseId: weBb,
        exerciseId: barbellEx.id,
        muscleGroupId: barbellEx.muscleGroupId,
        date: todayWorkout.date,
        weight: 85.0,
        reps: 8,
        rpe: 8.5,
      );

      await workoutRepo.logSet(
        workoutExerciseId: weBw,
        exerciseId: bodyweightEx.id,
        muscleGroupId: bodyweightEx.muscleGroupId,
        date: todayWorkout.date,
        weight: 0.0,
        reps: 15,
      );

      // Verify today's workout reflects these exercises and sets
      final reloaded = await workoutRepo.getTodayWorkout();
      expect(reloaded, isNotNull);
      expect(reloaded!.exercises.length, equals(3));

      // Verify set counts
      for (final we in reloaded.exercises) {
        expect(we.sets.length, equals(1));
      }

      // Verify e1RM calculation
      final e1rm = E1rmCalculator.calculate(85.0, 8);
      expect(e1rm, greaterThan(100.0));

      // Verify analytics query
      final breakdown = await workoutRepo.getMuscleGroupBreakdown(days: 7);
      expect(breakdown.isNotEmpty, isTrue);
    });
  });

  group('Universal CSV Importer with Real-World App Exports', () {
    test('Imports Strong export CSV and matches against openGym catalog', () async {
      final strongCsv = '''Date,Workout Name,Exercise Name,Set Order,Weight,Reps,RPE,Distance,Seconds,Notes
2026-09-21 17:30:00,Chest & Arms,Barbell Bench Press,1,100,5,8,,,First warm
2026-09-21 17:30:00,Chest & Arms,Barbell Bench Press,2,100,5,8.5,,,
2026-09-21 17:30:00,Chest & Arms,Dumbbell Bicep Curl,1,16,10,8,,,
2026-09-21 17:30:00,Chest & Arms,Custom Machine Shrug,1,50,12,,,,Custom machine''';

      final service = CsvImportService(db);
      final result = await service.importCsv(strongCsv);

      expect(result.sourceApp, equals('Strong'));
      expect(result.workoutsImported, equals(1));
      expect(result.setsImported, equals(4));
      expect(result.exercisesMatched, greaterThanOrEqualTo(2));
      expect(result.customExercisesCreated, equals(1));

      // Verify the custom exercise was created with inferred properties
      final allEx = await exerciseRepo.getExercises();
      final customMatches = allEx.where((e) => e.name.contains('Custom Machine Shrug')).toList();
      expect(customMatches.isNotEmpty, isTrue);
      final customEx = customMatches.first;
      expect(customEx.name, equals('Custom Machine Shrug'));
      expect(customEx.equipment, equals(EquipmentType.machine));
    });

    test('Imports Hevy export CSV with quotes and bracketed names', () async {
      final hevyCsv = '''"title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_kg","reps","distance_km","duration_seconds","rpe"
"Leg Day","2026-09-22 10:00:00","2026-09-22 11:15:00","","Squat (Barbell)",,"",1,"normal",120,5,,,8.5
"Leg Day","2026-09-22 10:00:00","2026-09-22 11:15:00","","Squat (Barbell)",,"",2,"normal",120,5,,,9.0
"Leg Day","2026-09-22 10:00:00","2026-09-22 11:15:00","","Leg Press",,"",1,"normal",200,10,,,8''';

      final service = CsvImportService(db);
      final result = await service.importCsv(hevyCsv);

      expect(result.sourceApp, equals('Hevy'));
      expect(result.workoutsImported, equals(1));
      expect(result.setsImported, equals(3));
      expect(result.exercisesMatched, equals(2));
    });

    test('Imports FitNotes CSV with imperial lbs and converts to kg', () async {
      final fitNotesCsv = '''Date,Exercise,Category,Weight,Weight Unit,Reps
2026-09-23,Overhead Press,Shoulders,100,lbs,8
2026-09-23,Overhead Press,Shoulders,100,lbs,8''';

      final service = CsvImportService(db);
      final result = await service.importCsv(fitNotesCsv);

      expect(result.sourceApp, equals('FitNotes'));
      expect(result.workoutsImported, equals(1));
      expect(result.setsImported, equals(2));

      // Verify weight was converted from 100 lbs -> ~45.36 kg
      final allWorkouts = await db.select(db.workouts).get();
      expect(allWorkouts.any((w) => w.date.year == 2026 && w.date.day == 23), isTrue);

      final sets = await db.select(db.sets).get();
      final fitNotesSets = sets.where((s) => s.reps == 8).toList();
      expect(fitNotesSets.isNotEmpty, isTrue);
      expect(fitNotesSets.first.weight, closeTo(45.36, 0.1));
    });
  });
}
