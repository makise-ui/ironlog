@Timeout(Duration(seconds: 120))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/domain/services/csv_import_service.dart';
import 'package:ironlog/domain/services/e1rm_calculator.dart';
import 'package:ironlog/domain/services/plan_share_service.dart';
import 'package:ironlog/domain/services/plate_calculator.dart';
import 'package:ironlog/domain/services/strength_decay_service.dart';
import 'package:ironlog/core/utils/unit_converter.dart';
import 'package:ironlog/domain/models/active_workout_input.dart';
import 'package:ironlog/domain/models/exercise_model.dart';
import 'package:ironlog/domain/models/set_model.dart';
import 'package:ironlog/domain/services/warmup_generator.dart';
import 'package:ironlog/domain/services/weight_step_learner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Calculation Bug Fixes Regression Tests', () {
    test('1. PlateCalculator computes accurate deficit remainder when target < bar', () {
      final res = PlateCalculator.calculate(
        targetWeight: 15.0,
        barWeight: 20.0,
        isLb: false,
      );

      expect(res.totalLoadedWeight, 20.0);
      expect(res.isExact, false);
      expect(res.remainder, -5.0);
      // Invariant: totalLoadedWeight + remainder == targetWeight
      expect(res.totalLoadedWeight + res.remainder, 15.0);
    });

    test('2. WarmupGenerator never proposes sub-barbell weights for light barbell target', () {
      final proposals = WarmupGenerator.generate(
        targetWeight: 30.0,
        barWeight: 20.0,
        weightStep: 2.5,
        isBarbell: true,
      );

      expect(proposals.isNotEmpty, true);
      for (final p in proposals) {
        expect(p.weight, greaterThanOrEqualTo(20.0));
      }
      expect(proposals.first.weight, 20.0);
    });

    test('3. E1rmCalculator preserves assisted volume instead of zeroing out', () {
      // Assisted dips with -20kg assistance, 10 reps
      final vol = E1rmCalculator.calculateSetVolume(
        -20.0,
        10,
        isAssisted: true,
        userBodyweight: 80.0,
      );
      // Effective moved weight: 80 - 20 = 60 kg * 10 reps = 600 kg
      expect(vol, 600.0);

      // Without bodyweight passed, uses absolute assistance load as working load proxy
      final fallbackVol = E1rmCalculator.calculateSetVolume(
        -20.0,
        10,
        isAssisted: true,
      );
      expect(fallbackVol, 200.0);
    });

    test('4. StrengthDecayService normalizes dates to midnight to prevent intra-day time loss', () {
      // Monday 21:00 vs Tuesday 09:00 (12 hours elapsed, but 1 calendar day elapsed)
      final mondayNight = DateTime(2026, 9, 21, 21, 0);
      final tuesdayMorning = DateTime(2026, 9, 22, 9, 0);

      final analysis = StrengthDecayService.evaluate(
        peak1Rm: 100.0,
        lastTrainedDate: mondayNight,
        now: tuesdayMorning,
      );

      expect(analysis.daysElapsed, 1);
    });

    test('5. CsvImportService extracts weight correctly from imperial lbs column header', () async {
      final db = AppDatabase.memory();
      final importer = CsvImportService(db);

      const csvData = '''Date,Workout Name,Exercise Name,Set Order,Weight (lbs),Reps
2026-09-01,Push Day,Bench Press,1,225,5
''';

      final result = await importer.importCsv(csvData);
      expect(result.workoutsImported, 1);
      expect(result.setsImported, 1);

      final sets = await db.select(db.sets).get();
      expect(sets.length, 1);
      // 225 lbs in kg is ~102.06 kg (> 0)
      expect(sets.first.weight, greaterThan(100.0));

      await db.close();
    });

    test('6. PlanShareService preserves explicitly shared equipment and loadMode', () async {
      final db = AppDatabase.memory();

      const planJson = '''{
        "ironlog_plan": 1,
        "title": "Chest Hypertrophy",
        "description": "Chest isolation block",
        "unit": "kg",
        "exercises": [
          {
            "name": "Custom Machine Press",
            "muscle": "chest",
            "equipment": "machine",
            "loadMode": "per_hand",
            "weightStep": 5.0,
            "sets": 3,
            "repMin": 8,
            "repMax": 12,
            "rest": 90
          }
        ]
      }''';

      final routine = await PlanShareService.importRoutineFromPayload(planJson, db);
      expect(routine.name, 'Chest Hypertrophy');

      final ex = await (db.select(db.exercises)..where((t) => t.name.equals('Custom Machine Press'))).getSingle();
      expect(ex.equipment, 'machine');
      expect(ex.loadMode, 'per_hand');
      expect(ex.weightStep, 5.0);

      await db.close();
    });

    test('6. ActiveWorkoutInput correctly parses European comma decimal and trims inputs', () {
      const input = ActiveWorkoutInput(
        workoutExerciseId: 'we1',
        exerciseId: 'ex1',
        exerciseName: 'Bench Press',
        equipment: EquipmentType.barbell,
        setIndex: 1,
        setType: SetType.working,
        activeField: WorkoutInputField.weight,
        weightInput: ' 82,5 ',
        repsInput: ' 10 ',
        unit: WeightUnit.kg,
        isCompleted: false,
      );

      expect(input.effectiveWeight, 82.5);
      expect(input.effectiveReps, 10);
    });
  });
}
