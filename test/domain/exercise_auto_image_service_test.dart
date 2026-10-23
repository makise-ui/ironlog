import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/domain/services/exercise_auto_image_service.dart';
import 'package:ironlog/domain/services/exercise_image_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
    ExerciseAutoImageService.resolvedImagesNotifier.value = {};
  });

  tearDown(() async {
    await db.close();
  });

  group('ExerciseAutoImageService Tests', () {
    test('init loads saved exercise images from database into memory', () async {
      await db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          id: 'test_ex_1',
          name: 'Bulgarian Split Squat',
          muscleGroupId: 'legs',
          equipment: 'dumbbell',
          imagePath: const Value('/path/to/bulgarian_squat.jpg'),
        ),
      );

      await ExerciseAutoImageService.init(db);

      final path = ExerciseAutoImageService.getResolvedPath('Bulgarian Split Squat');
      expect(path, '/path/to/bulgarian_squat.jpg');

      final normPath = ExerciseAutoImageService.getResolvedPath('bulgarian split squat (dumbbell)');
      expect(normPath, '/path/to/bulgarian_squat.jpg');
    });

    test('getResolvedPath normalizes exercise names with parentheses and symbols', () {
      final map = {'incline dumbbell curl': 'https://example.com/curl.jpg'};
      ExerciseAutoImageService.resolvedImagesNotifier.value = map;

      expect(
        ExerciseAutoImageService.getResolvedPath('Incline Dumbbell Curl (Biceps)'),
        'https://example.com/curl.jpg',
      );
    });

    test('prefetch resolves image and populates resolvedImagesNotifier', () async {
      ExerciseImageSearchService.setSearchCacheForTesting('Standing Calf Raise', [
        const ExerciseImageCandidate(
          title: 'Standing Calf Raise Form',
          thumbnailUrl: 'https://ts1.mm.bing.net/th?id=test_calf&pid=15.1',
          fullUrl: 'https://ts1.mm.bing.net/th?id=test_calf&pid=15.1',
        ),
      ]);

      ExerciseAutoImageService.prefetch(
        exerciseName: 'Standing Calf Raise',
        exerciseId: 'test_calf_id',
        db: db,
      );

      // Allow background microtask / future to run
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final resolved = ExerciseAutoImageService.getResolvedPath('Standing Calf Raise');
      expect(resolved, contains('test_calf'));
    });
  });
}
