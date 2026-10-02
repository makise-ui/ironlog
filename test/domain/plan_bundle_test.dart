import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/data/repositories/exercise_repository.dart';
import 'package:ironlog/data/repositories/routine_repository.dart';
import 'package:ironlog/domain/models/exercise_model.dart';
import 'package:ironlog/domain/services/weight_step_learner.dart';
import 'package:ironlog/domain/services/plan_share_service.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository exerciseRepo;
  late RoutineRepository routineRepo;

  setUp(() async {
    db = AppDatabase.memory();
    exerciseRepo = ExerciseRepository(db);
    routineRepo = RoutineRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PlanShareService Bundle Tests', () {
    test('exportRoutinesBundleToPayload and parseBundlePreview round-trip', () async {
      // 1. Create test exercises
      await exerciseRepo.createExercise(
        const ExerciseModel(
          id: 'ex1',
          name: 'Barbell Bench Press',
          muscleGroupId: 'chest',
          equipment: EquipmentType.barbell,
        ),
      );
      await exerciseRepo.createExercise(
        const ExerciseModel(
          id: 'ex2',
          name: 'Pull Up',
          muscleGroupId: 'back',
          equipment: EquipmentType.bodyweight,
        ),
      );

      // 2. Create test routines
      final r1Id = await routineRepo.createRoutine(
        name: 'Push Day A',
        description: 'Focus on chest and triceps',
        exerciseIds: ['ex1'],
      );

      final r2Id = await routineRepo.createRoutine(
        name: 'Pull Day A',
        description: 'Focus on back and biceps',
        exerciseIds: ['ex2'],
      );

      final routines = await routineRepo.getRoutines();
      final exportedRoutines = routines.where((r) => r.id == r1Id || r.id == r2Id).toList();

      // Export bundle payload
      final payload = PlanShareService.exportRoutinesBundleToPayload(
        exportedRoutines,
        bundleTitle: 'Push-Pull Split Pack',
      );
      expect(payload, isNotNull);
      expect(PlanShareService.isBundlePayload(payload), isTrue);

      // Preview bundle
      final preview = PlanShareService.parseBundlePreview(payload);
      expect(preview, isNotNull);
      expect(preview.title, 'Push-Pull Split Pack');
      expect(preview.routines.length, 2);
      expect(preview.routines[0].title, 'Push Day A');
      expect(preview.routines[1].title, 'Pull Day A');
      expect(preview.routines[0].exercises.length, 1);
      expect(preview.routines[1].exercises.length, 1);

      final beforeImportRoutines = await routineRepo.getRoutines();

      // Test importing selected subset (only the first routine)
      final imported = await PlanShareService.importRoutinesBundleFromPayload(
        payload,
        db,
        selectedIndices: [0],
      );

      expect(imported.length, 1);
      expect(imported.first.name.contains('Push Day A'), isTrue);

      // Verify the new routine exists in the database
      final allRoutines = await routineRepo.getRoutines();
      expect(allRoutines.length, beforeImportRoutines.length + 1);
    });

    test('isBundlePayload returns false for invalid payloads', () {
      expect(PlanShareService.isBundlePayload(''), isFalse);
      expect(PlanShareService.isBundlePayload('not_a_valid_bundle'), isFalse);
      expect(PlanShareService.isBundlePayload('ironlog_plan_v1:some_data'), isFalse);
    });
  });
}
