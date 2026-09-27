import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/domain/models/exercise_model.dart';
import 'package:ironlog/domain/models/routine_model.dart';
import 'package:ironlog/domain/models/set_model.dart';
import 'package:ironlog/domain/services/effort_analytics_service.dart';
import 'package:ironlog/domain/services/plan_share_service.dart';
import 'package:ironlog/domain/services/plate_calculator.dart';
import 'package:ironlog/domain/services/strength_decay_service.dart';
import 'package:ironlog/domain/services/warmup_generator.dart';
import 'package:ironlog/domain/services/weight_step_learner.dart';

void main() {
  group('1. PlateCalculator Domain Service Tests', () {
    test('Calculates metric Olympic barbell loading accurately (100 kg on 20 kg bar)', () {
      final breakdown = PlateCalculator.calculate(
        targetWeight: 100.0,
        barWeight: 20.0,
        isLb: false,
      );

      expect(breakdown.targetWeight, 100.0);
      expect(breakdown.barWeight, 20.0);
      expect(breakdown.weightPerSide, 40.0);
      expect(breakdown.isExact, true);
      expect(breakdown.remainder, 0.0);

      // 40 kg per side with greedy Olympic spec: 25 kg + 15 kg
      final totalPlatesWeightPerSide = breakdown.platesPerSide.fold<double>(
        0.0,
        (sum, entry) => sum + (entry.spec.weight * entry.count),
      );
      expect(totalPlatesWeightPerSide, 40.0);
      expect(breakdown.totalLoadedWeight, 100.0);
    });

    test('Calculates imperial barbell loading accurately (225 lb on 45 lb bar)', () {
      final breakdown = PlateCalculator.calculate(
        targetWeight: 225.0,
        barWeight: 45.0,
        isLb: true,
      );

      expect(breakdown.weightPerSide, 90.0);
      expect(breakdown.isExact, true);
      expect(breakdown.totalLoadedWeight, 225.0);

      // 90 lbs per side = two 45 lb plates
      final plate45 = breakdown.platesPerSide.firstWhere((p) => p.spec.weight == 45.0);
      expect(plate45.count, 2);
    });

    test('Handles target below bar weight safely without crashing', () {
      final breakdown = PlateCalculator.calculate(
        targetWeight: 15.0,
        barWeight: 20.0,
        isLb: false,
      );

      expect(breakdown.platesPerSide, isEmpty);
      expect(breakdown.isExact, false);
      expect(breakdown.weightPerSide, 0.0);
      expect(breakdown.totalLoadedWeight, 20.0);
    });

    test('Detects impossible increments and flags remainder', () {
      final breakdown = PlateCalculator.calculate(
        targetWeight: 101.3,
        barWeight: 20.0,
        isLb: false,
      );

      expect(breakdown.isExact, false);
      expect(breakdown.remainder, greaterThan(0.0));
    });
  });

  group('2. WarmupGenerator Domain Service Tests', () {
    test('Generates scientific 4-tier ramp for heavy barbell movements', () {
      final proposals = WarmupGenerator.generate(
        targetWeight: 100.0,
        barWeight: 20.0,
        weightStep: 2.5,
        isBarbell: true,
      );

      expect(proposals.length, 4);

      // Stage 1: Empty bar
      expect(proposals[0].weight, 20.0);
      expect(proposals[0].reps, 10);
      expect(proposals[0].label, contains('Empty Bar'));

      // Stage 2: 50%
      expect(proposals[1].weight, 50.0);
      expect(proposals[1].reps, 5);

      // Stage 3: 70%
      expect(proposals[2].weight, 70.0);
      expect(proposals[2].reps, 3);

      // Stage 4: 85%
      expect(proposals[3].weight, 85.0);
      expect(proposals[3].reps, 1);
    });

    test('Generates 2-tier ramp for dumbbell / accessory movements', () {
      final proposals = WarmupGenerator.generate(
        targetWeight: 30.0,
        barWeight: 0.0,
        weightStep: 2.0,
        isBarbell: false,
      );

      expect(proposals.length, 2);
      expect(proposals[0].weight, 16.0); // 50% of 30 = 15 -> rounded to step 2.0 = 16.0
      expect(proposals[0].reps, 8);
      expect(proposals[1].weight, 22.0); // 75% of 30 = 22.5 -> rounded to step 2.0 = 22.0
      expect(proposals[1].reps, 4);
    });

    test('Generates joint activation for bodyweight movements', () {
      final proposals = WarmupGenerator.generate(
        targetWeight: 0.0,
        isBodyweight: true,
      );

      expect(proposals.length, 1);
      expect(proposals[0].weight, 0.0);
      expect(proposals[0].reps, 10);
      expect(proposals[0].label, contains('Joint Activation'));
    });
  });

  group('3. StrengthDecayService Domain Service Tests', () {
    final baseDate = DateTime(2026, 9, 1);

    test('Retains 100% capacity within 14-day neuromuscular plateau', () {
      final result = StrengthDecayService.evaluate(
        peak1Rm: 120.0,
        lastTrainedDate: baseDate,
        now: baseDate.add(const Duration(days: 10)),
      );

      expect(result.daysElapsed, 10);
      expect(result.decayFactor, 1.0);
      expect(result.currentExpected1Rm, 120.0);
      expect(result.isDetrained, false);
      expect(result.statusLabel, contains('Peak Capacity Retained'));
    });

    test('Executes exponential half-life decay after 14 days', () {
      // 14 days plateau + 28 days half-life = 42 days elapsed -> decay ~0.50
      final result = StrengthDecayService.evaluate(
        peak1Rm: 100.0,
        lastTrainedDate: baseDate,
        now: baseDate.add(const Duration(days: 42)),
        weightStep: 2.5,
      );

      expect(result.daysElapsed, 42);
      expect(result.decayFactor, closeTo(0.50, 0.05));
      expect(result.isDetrained, true);
      expect(result.suggestedReentryWeight, lessThan(result.currentExpected1Rm));
    });

    test('Enforces 50% neuromuscular strength floor (muscle memory anchor)', () {
      final result = StrengthDecayService.evaluate(
        peak1Rm: 100.0,
        lastTrainedDate: baseDate,
        now: baseDate.add(const Duration(days: 400)), // > 1 year layoff
      );

      expect(result.daysElapsed, 400);
      expect(result.decayFactor, 0.50);
      expect(result.currentExpected1Rm, 50.0);
      expect(result.isDetrained, true);
    });
  });

  group('4. EffortAnalyticsService Domain Service Tests', () {
    test('Converts RPE and RIR bidirectionally', () {
      expect(EffortAnalyticsService.rpeToRir(10.0), 0);
      expect(EffortAnalyticsService.rpeToRir(8.0), 2);
      expect(EffortAnalyticsService.rpeToRir(7.0), 3);
      expect(EffortAnalyticsService.rirToRpe(1), 9.0);
    });

    test('Identifies stimulating sets vs junk volume', () {
      final highEffortSet = SetModel(
        id: 's_high',
        workoutExerciseId: 'we1',
        exerciseId: 'ex1',
        muscleGroupId: 'chest',
        date: DateTime.now(),
        setIndex: 1,
        weight: 100,
        reps: 8,
        rpe: 9.0,
        setType: SetType.working,
        completedAt: DateTime.now(),
      );
      final highEffort = EffortAnalyticsService.evaluateSet(highEffortSet);
      expect(highEffort.isStimulating, true);
      expect(highEffort.isJunkVolume, false);
      expect(highEffort.effectiveReps, 4);

      final junkSetModel = SetModel(
        id: 's_junk',
        workoutExerciseId: 'we1',
        exerciseId: 'ex1',
        muscleGroupId: 'chest',
        date: DateTime.now(),
        setIndex: 2,
        weight: 100,
        reps: 8,
        rpe: 5.0,
        setType: SetType.working,
        completedAt: DateTime.now(),
      );
      final junkSet = EffortAnalyticsService.evaluateSet(junkSetModel);
      expect(junkSet.isStimulating, false);
      expect(junkSet.isJunkVolume, true);
      expect(junkSet.effectiveReps, 0);
    });

    test('Evaluates set collections and provides hypertrophy distribution', () {
      final sets = [
        SetModel(
          id: '1',
          workoutExerciseId: 'we1',
          exerciseId: 'ex1',
          muscleGroupId: 'chest',
          date: DateTime.now(),
          setIndex: 1,
          weight: 100,
          reps: 8,
          rpe: 9.0,
          setType: SetType.working,
          completedAt: DateTime.now(),
        ),
        SetModel(
          id: '2',
          workoutExerciseId: 'we1',
          exerciseId: 'ex1',
          muscleGroupId: 'chest',
          date: DateTime.now(),
          setIndex: 2,
          weight: 100,
          reps: 8,
          rpe: 8.5,
          setType: SetType.working,
          completedAt: DateTime.now(),
        ),
        SetModel(
          id: '3',
          workoutExerciseId: 'we1',
          exerciseId: 'ex1',
          muscleGroupId: 'chest',
          date: DateTime.now(),
          setIndex: 3,
          weight: 50,
          reps: 10,
          setType: SetType.warmup, // Warmups ignored from working sets
          completedAt: DateTime.now(),
        ),
      ];

      final summary = EffortAnalyticsService.evaluateCollection(sets);
      expect(summary.totalSets, 2);
      expect(summary.stimulatingSets, 2);
      expect(summary.junkVolumeSets, 0);
      expect(summary.stimulatingRatio, 1.0);
    });
  });

  group('5. PlanShareService Domain Service Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test('Serializes routine to standardized JSON QR payload', () {
      final dummyRoutine = RoutineModel(
        id: 'r_test',
        name: 'Hypertrophy Upper',
        description: '4-day split day A',
        items: [
          RoutineItemModel(
            id: 'item_1',
            routineId: 'r_test',
            exercise: const ExerciseModel(
              id: 'ex_bench',
              name: 'Barbell Bench Press',
              muscleGroupId: 'chest',
              equipment: EquipmentType.barbell,
            ),
            position: 0,
            targetSets: 3,
            repMin: 8,
            repMax: 12,
            restSeconds: 90,
          ),
        ],
      );

      final payload = PlanShareService.exportRoutineToPayload(dummyRoutine, isLb: false);
      expect(payload, isNotEmpty);

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded['ironlog_plan'], 1);
      expect(decoded['title'], 'Hypertrophy Upper');
      expect((decoded['exercises'] as List).length, 1);
    });

    test('Imports routine from QR payload into SQLite with atomic transaction', () async {
      const sampleQrJson = '''{
        "ironlog_plan": 1,
        "title": "Leg Day Destruction",
        "description": "Quads & Hamstrings Focus",
        "unit": "kg",
        "exercises": [
          {
            "name": "Barbell Squat",
            "muscle": "legs",
            "equipment": "barbell",
            "sets": 4,
            "repMin": 6,
            "repMax": 8,
            "rest": 120
          },
          {
            "name": "Custom Bulgarian Split Squat",
            "muscle": "legs",
            "equipment": "dumbbell",
            "sets": 3,
            "repMin": 10,
            "repMax": 12,
            "rest": 90
          }
        ]
      }''';

      final imported = await PlanShareService.importRoutineFromPayload(sampleQrJson, db);

      expect(imported.name, 'Leg Day Destruction');
      expect(imported.items.length, 2);
      expect(imported.items[0].targetSets, 4);
      expect(imported.items[1].exercise.name, 'Custom Bulgarian Split Squat');
    });
  });
}
