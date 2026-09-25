import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/data/database/database.dart';
import 'package:ironlog/domain/services/backup_service.dart';
import 'package:drift/drift.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('BackupService Tests', () {
    test('createBackupJson and restoreFromJson include all tables and preserve routine_id', () async {
      final now = DateTime.now();

      // 1. Insert routine
      await db.into(db.routines).insert(
        RoutinesCompanion.insert(
          id: 'routine_1',
          name: 'Upper Body Power',
        ),
      );

      // 2. Insert workout with routineId
      await db.into(db.workouts).insert(
        WorkoutsCompanion.insert(
          id: 'workout_1',
          date: now,
          title: 'Upper Session',
          routineId: const Value('routine_1'),
        ),
      );

      // 3. Insert body metric
      await db.into(db.bodyMetrics).insert(
        BodyMetricsCompanion.insert(
          id: 'metric_1',
          date: now,
          metricType: 'weight',
          value: 78.5,
          unit: 'kg',
        ),
      );

      // 4. Insert achievement
      await db.into(db.achievements).insert(
        AchievementsCompanion.insert(
          id: 'achieve_1',
          code: 'first_workout',
          title: 'First Workout',
          description: 'Completed first session',
          badgeIcon: 'fitness_center',
        ),
      );

      // 5. Insert photo
      await db.into(db.photos).insert(
        PhotosCompanion.insert(
          id: 'photo_1',
          date: now,
          filePath: '/path/to/photo.jpg',
          pose: 'front',
        ),
      );

      // 6. Insert custom exercise
      await db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          id: 'custom_ex_1',
          name: 'Deficit Deadlift',
          muscleGroupId: 'back',
          equipment: 'barbell',
          isCustom: const Value(true),
        ),
      );

      // 7. Insert settings
      await db.into(db.settings).insert(
        SettingsCompanion.insert(
          k: 'theme_mode',
          v: 'dark',
        ),
      );

      // Export JSON
      final json = await BackupService.createBackupJson(db, stripSecrets: false);

      expect(json['workouts'], isNotEmpty);
      expect(json['workouts'][0]['routine_id'], 'routine_1');
      expect(json['body_metrics'], isNotEmpty);
      expect(json['body_metrics'][0]['value'], 78.5);
      expect(json['achievements'], isNotEmpty);
      expect(json['achievements'][0]['code'], 'first_workout');
      expect(json['photos'], isNotEmpty);
      expect(json['photos'][0]['file_path'], '/path/to/photo.jpg');
      expect(json['custom_exercises'], isNotEmpty);

      // Restore into fresh db
      final db2 = AppDatabase.memory();
      try {
        final restoredCount = await BackupService.restoreFromJson(db2, json);
        expect(restoredCount, 1);

        final restoredWorkouts = await db2.select(db2.workouts).get();
        expect(restoredWorkouts.length, 1);
        expect(restoredWorkouts.first.routineId, 'routine_1');

        final restoredMetrics = await db2.select(db2.bodyMetrics).get();
        expect(restoredMetrics.length, 1);
        expect(restoredMetrics.first.value, 78.5);

        final restoredAchievements = await db2.select(db2.achievements).get();
        expect(restoredAchievements.length, 1);
        expect(restoredAchievements.first.code, 'first_workout');

        final restoredPhotos = await db2.select(db2.photos).get();
        expect(restoredPhotos.length, 1);
        expect(restoredPhotos.first.filePath, '/path/to/photo.jpg');

        final restoredExercises = await (db2.select(db2.exercises)..where((e) => e.isCustom.equals(true))).get();
        expect(restoredExercises.length, 1);
        expect(restoredExercises.first.name, 'Deficit Deadlift');
      } finally {
        await db2.close();
      }
    });
  });
}
