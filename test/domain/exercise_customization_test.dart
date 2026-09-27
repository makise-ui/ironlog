import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/data/repositories/exercise_repository.dart';
import 'package:ironlog/domain/models/exercise_model.dart';
import 'package:ironlog/domain/services/exercise_image_search_service.dart';
import 'package:ironlog/domain/services/weight_step_learner.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository exerciseRepo;

  setUp(() {
    db = AppDatabase.memory();
    exerciseRepo = ExerciseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Exercise Tracking Types and Heuristic Tests', () {
    test('Correctly identifies standard weight and rep exercises', () {
      const bench = ExerciseModel(
        id: 'bench_press',
        name: 'Barbell Bench Press',
        muscleGroupId: 'chest',
        equipment: EquipmentType.barbell,
      );
      expect(bench.trackingType, ExerciseTrackingType.weightAndReps);
      expect(bench.isStandardWeightAndReps, isTrue);
      expect(bench.isHoldDuration, isFalse);
      expect(bench.isBodyweight, isFalse);
    });

    test('Correctly detects bodyweight rep exercises by name and equipment', () {
      const pushup = ExerciseModel(
        id: 'pushup',
        name: 'Standard Push-Up',
        muscleGroupId: 'chest',
        equipment: EquipmentType.bodyweight,
      );
      expect(pushup.trackingType, ExerciseTrackingType.bodyweightReps);
      expect(pushup.isBodyweight, isTrue);

      const pullup = ExerciseModel(
        id: 'pullup',
        name: 'Wide Grip Pull Up',
        muscleGroupId: 'back',
        equipment: EquipmentType.bodyweight,
      );
      expect(pullup.trackingType, ExerciseTrackingType.bodyweightReps);
      expect(pullup.isBodyweight, isTrue);
    });

    test('Correctly detects timed hold exercises (plank, hollow hold, wall sit)', () {
      const plank = ExerciseModel(
        id: 'plank',
        name: 'Standard Plank',
        muscleGroupId: 'core',
        equipment: EquipmentType.bodyweight,
      );
      expect(plank.trackingType, ExerciseTrackingType.duration);
      expect(plank.isHoldDuration, isTrue);

      const wallSit = ExerciseModel(
        id: 'wall_sit',
        name: 'Wall Sit',
        muscleGroupId: 'legs',
        equipment: EquipmentType.bodyweight,
      );
      expect(wallSit.trackingType, ExerciseTrackingType.duration);
      expect(wallSit.isHoldDuration, isTrue);
    });

    test('Correctly respects custom tracking type override', () {
      const customPlank = ExerciseModel(
        id: 'custom_plank',
        name: 'Weighted Plank Hold',
        muscleGroupId: 'core',
        equipment: EquipmentType.other,
        customTrackingType: ExerciseTrackingType.duration,
      );
      expect(customPlank.trackingType, ExerciseTrackingType.duration);
      expect(customPlank.isHoldDuration, isTrue);

      const customPushup = ExerciseModel(
        id: 'custom_pushup',
        name: 'Diamond Push-Up',
        muscleGroupId: 'chest',
        equipment: EquipmentType.bodyweight,
        customTrackingType: ExerciseTrackingType.bodyweightReps,
      );
      expect(customPushup.trackingType, ExerciseTrackingType.bodyweightReps);
      expect(customPushup.isBodyweight, isTrue);
    });
  });

  group('Exercise Repository Image and Tracking Persistence', () {
    test('Creates custom exercise with custom tracking type and image path', () async {
      final created = await exerciseRepo.createCustomExercise(
        name: 'Dynamic Plank Reach',
        muscleGroupId: 'core',
        equipment: EquipmentType.bodyweight,
        trackingType: ExerciseTrackingType.duration,
        imagePath: '/data/user/0/ironlog/files/plank.jpg',
      );

      expect(created.name, 'Dynamic Plank Reach');
      expect(created.customTrackingType, ExerciseTrackingType.duration);
      expect(created.trackingType, ExerciseTrackingType.duration);
      expect(created.imagePath, '/data/user/0/ironlog/files/plank.jpg');

      final fetched = await exerciseRepo.getExerciseById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.customTrackingType, ExerciseTrackingType.duration);
      expect(fetched.imagePath, '/data/user/0/ironlog/files/plank.jpg');
    });

    test('Updates image path of an existing seeded exercise', () async {
      final exercises = await exerciseRepo.getExercises(muscleGroupId: 'chest');
      expect(exercises.isNotEmpty, isTrue);
      final target = exercises.first;

      await exerciseRepo.updateExerciseImage(target.id, 'https://example.com/custom_image.jpg');

      final updated = await exerciseRepo.getExerciseById(target.id);
      expect(updated, isNotNull);
      expect(updated!.imagePath, 'https://example.com/custom_image.jpg');
    });

    test('Updates tracking type of an existing exercise', () async {
      final exercises = await exerciseRepo.getExercises(muscleGroupId: 'core');
      expect(exercises.isNotEmpty, isTrue);
      final target = exercises.first;

      await exerciseRepo.updateExerciseTrackingType(target.id, ExerciseTrackingType.duration);

      final updated = await exerciseRepo.getExerciseById(target.id);
      expect(updated, isNotNull);
      expect(updated!.customTrackingType, ExerciseTrackingType.duration);
      expect(updated.trackingType, ExerciseTrackingType.duration);
    });
  });

  group('Exercise Image Search Service Candidate Construction', () {
    test('ExerciseImageCandidate properties', () {
      const candidate = ExerciseImageCandidate(
        title: 'Pushup demonstration',
        thumbnailUrl: 'https://upload.wikimedia.org/test.jpg',
        fullUrl: 'https://upload.wikimedia.org/test_full.jpg',
        source: 'Wikimedia Commons',
      );

      expect(candidate.title, 'Pushup demonstration');
      expect(candidate.thumbnailUrl, 'https://upload.wikimedia.org/test.jpg');
      expect(candidate.fullUrl, 'https://upload.wikimedia.org/test_full.jpg');
      expect(candidate.source, 'Wikimedia Commons');
    });

    test('ExerciseImageCandidate properties and tagging', () {
      const candidate = ExerciseImageCandidate(
        title: 'Ab Wheel Rollout demonstration',
        thumbnailUrl: 'https://example.com/ab_wheel.jpg',
        fullUrl: 'https://example.com/ab_wheel_full.jpg',
        source: 'Web Search',
        positionTag: 'FORM DEMONSTRATION',
      );

      expect(candidate.title, 'Ab Wheel Rollout demonstration');
      expect(candidate.thumbnailUrl, 'https://example.com/ab_wheel.jpg');
      expect(candidate.fullUrl, 'https://example.com/ab_wheel_full.jpg');
      expect(candidate.source, 'Web Search');
      expect(candidate.positionTag, 'FORM DEMONSTRATION');
    });

    test('getExerciseDemonstrationImages respects current active selection', () async {
      ExerciseImageSearchService.setSearchCacheForTesting('Ab Wheel Rollout', []);
      final candidates = await ExerciseImageSearchService.getExerciseDemonstrationImages(
        'Ab Wheel Rollout',
        currentImagePath: 'https://example.com/active.jpg',
      );

      expect(candidates, isNotEmpty);
      expect(candidates.first.thumbnailUrl, 'https://example.com/active.jpg');
      expect(candidates.first.positionTag, 'ACTIVE SELECTION');
    });
  });
}
