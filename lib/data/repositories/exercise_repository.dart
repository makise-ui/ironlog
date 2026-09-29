import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../domain/models/exercise_model.dart';
import '../../domain/services/weight_step_learner.dart';
import '../../domain/services/backup_service.dart';

class ExerciseRepository {
  final AppDatabase _db;

  ExerciseRepository(this._db);

  MuscleGroupModel _mapMuscleGroup(MuscleGroupData data) {
    return MuscleGroupModel(
      id: data.id,
      name: data.name,
      color: data.color,
      icon: data.icon,
      sort: data.sort,
    );
  }

  ExerciseModel _mapExercise(ExerciseData data) {
    final secondary = data.secondaryGroups.isEmpty
        ? <String>[]
        : data.secondaryGroups.split(',').map((s) => s.trim()).toList();

    EquipmentType equip = EquipmentType.barbell;
    try {
      equip = EquipmentType.values.byName(data.equipment.toLowerCase());
    } catch (_) {}

    ExerciseTrackingType? tracking;
    if (data.trackingType != null && data.trackingType!.isNotEmpty) {
      try {
        tracking = ExerciseTrackingType.values.byName(data.trackingType!);
      } catch (_) {}
    }

    return ExerciseModel(
      id: data.id,
      name: data.name,
      muscleGroupId: data.muscleGroupId,
      secondaryGroups: secondary,
      equipment: equip,
      loadMode: LoadMode.fromString(data.loadMode),
      isUnilateral: data.isUnilateral,
      weightStep: data.weightStep,
      repMin: data.repMin,
      repMax: data.repMax,
      restSeconds: data.restSeconds,
      isCustom: data.isCustom,
      archived: data.archived,
      imagePath: data.imagePath,
      customTrackingType: tracking,
    );
  }

  Future<List<MuscleGroupModel>> getMuscleGroups() async {
    final query = _db.select(_db.muscleGroups)
      ..orderBy([(t) => OrderingTerm(expression: t.sort)]);
    final list = await query.get();
    return list.map(_mapMuscleGroup).toList();
  }

  Stream<List<MuscleGroupModel>> watchMuscleGroups() {
    final query = _db.select(_db.muscleGroups)
      ..orderBy([(t) => OrderingTerm(expression: t.sort)]);
    return query.watch().map((list) => list.map(_mapMuscleGroup).toList());
  }

  Future<List<ExerciseModel>> getExercises({
    String? muscleGroupId,
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.exercises);
    if (!includeArchived) {
      query.where((t) => t.archived.equals(false));
    }
    if (muscleGroupId != null && muscleGroupId.isNotEmpty) {
      query.where((t) => t.muscleGroupId.equals(muscleGroupId));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);
    final list = await query.get();
    return list.map(_mapExercise).toList();
  }

  Stream<List<ExerciseModel>> watchExercises({String? muscleGroupId}) {
    final query = _db.select(_db.exercises)
      ..where((t) => t.archived.equals(false));
    if (muscleGroupId != null && muscleGroupId.isNotEmpty) {
      query.where((t) => t.muscleGroupId.equals(muscleGroupId));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.watch().map((list) => list.map(_mapExercise).toList());
  }

  Future<ExerciseModel?> getExerciseById(String id) async {
    final query = _db.select(_db.exercises)..where((t) => t.id.equals(id));
    final data = await query.getSingleOrNull();
    if (data == null) return null;
    return _mapExercise(data);
  }

  Future<void> createExercise(ExerciseModel model) async {
    await _db.into(_db.exercises).insert(
      ExercisesCompanion.insert(
        id: model.id,
        name: model.name,
        muscleGroupId: model.muscleGroupId,
        secondaryGroups: Value(model.secondaryGroups.join(',')),
        equipment: model.equipment.name,
        loadMode: Value(model.loadMode.dbValue),
        isUnilateral: Value(model.isUnilateral),
        weightStep: Value(model.weightStep),
        repMin: Value(model.repMin),
        repMax: Value(model.repMax),
        restSeconds: Value(model.restSeconds),
        isCustom: Value(model.isCustom),
        archived: Value(model.archived),
        imagePath: Value(model.imagePath),
        trackingType: Value(model.customTrackingType?.name),
      ),
    );
    BackupService.scheduleAutoBackup(_db);
  }

  Future<void> updateExercise(ExerciseModel model) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(model.id))).write(
      ExercisesCompanion(
        name: Value(model.name),
        muscleGroupId: Value(model.muscleGroupId),
        secondaryGroups: Value(model.secondaryGroups.join(',')),
        equipment: Value(model.equipment.name),
        loadMode: Value(model.loadMode.dbValue),
        isUnilateral: Value(model.isUnilateral),
        weightStep: Value(model.weightStep),
        repMin: Value(model.repMin),
        repMax: Value(model.repMax),
        restSeconds: Value(model.restSeconds),
        archived: Value(model.archived),
        imagePath: Value(model.imagePath),
        trackingType: Value(model.customTrackingType?.name),
      ),
    );
    BackupService.scheduleAutoBackup(_db);
  }

  Future<void> updateExerciseImage(String id, String? imagePath) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        imagePath: Value(imagePath),
      ),
    );
    BackupService.scheduleAutoBackup(_db);
  }

  Future<void> updateExerciseTrackingType(String id, ExerciseTrackingType trackingType) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        trackingType: Value(trackingType.name),
      ),
    );
    BackupService.scheduleAutoBackup(_db);
  }

  Future<void> archiveExercise(String id, bool archive) async {
    await _db.transaction(() async {
      await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
        ExercisesCompanion(archived: Value(archive)),
      );
      await (_db.update(_db.sets)..where((t) => t.exerciseId.equals(id))).write(
        SetsCompanion(archived: Value(archive)),
      );
      if (archive) {
        await (_db.delete(_db.prs)..where((t) => t.exerciseId.equals(id))).go();
      }
    });
    BackupService.scheduleAutoBackup(_db);
  }

  /// Retrieves past logged weights for an exercise to learn weight_step
  Future<List<double>> getWeightHistory(String exerciseId) async {
    final query = _db.select(_db.sets)
      ..where((t) => t.exerciseId.equals(exerciseId) & t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm(expression: t.date)]);
    final list = await query.get();
    return list.map((s) => s.weight).toList();
  }

  /// Sets a custom name or renames an exercise
  Future<void> renameExercise(String id, String newName) async {
    if (newName.trim().isEmpty) return;
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        name: Value(newName.trim()),
      ),
    );
    BackupService.scheduleAutoBackup(_db);
  }

  /// Creates and persists a custom exercise
  Future<ExerciseModel> createCustomExercise({
    required String name,
    required String muscleGroupId,
    EquipmentType equipment = EquipmentType.barbell,
    LoadMode? loadMode,
    double? weightStep,
    int repMin = 8,
    int repMax = 12,
    int restSeconds = 90,
    ExerciseTrackingType? trackingType,
    String? imagePath,
  }) async {
    final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final isBw = equipment == EquipmentType.bodyweight || trackingType == ExerciseTrackingType.bodyweightReps;
    final resolvedLoadMode = loadMode ?? (isBw ? LoadMode.bodyweight : LoadMode.total);
    final resolvedWeightStep = weightStep ?? (isBw ? 0.0 : 2.5);
    final model = ExerciseModel(
      id: newId,
      name: name.trim(),
      muscleGroupId: muscleGroupId,
      secondaryGroups: const [],
      equipment: equipment,
      loadMode: resolvedLoadMode,
      isUnilateral: false,
      weightStep: resolvedWeightStep,
      repMin: repMin,
      repMax: repMax,
      restSeconds: restSeconds,
      isCustom: true,
      archived: false,
      imagePath: imagePath,
      customTrackingType: trackingType,
    );
    await createExercise(model);
    return model;
  }

  /// Seeds or updates the comprehensive 1,300+ exercise library from openGym
  Future<int> seedOpenGymCatalog() async {
    int insertedCount = 0;
    try {
      final jsonStr = await rootBundle.loadString('assets/exercises/opengym_exercises.json');
      final List<dynamic> list = jsonDecode(jsonStr);

      final existing = await _db.select(_db.exercises).get();
      final Map<String, ExerciseData> existingByName = {
        for (final e in existing) e.name.toLowerCase().trim(): e
      };
      final Map<String, ExerciseData> existingById = {
        for (final e in existing) e.id: e
      };

      const validMuscleGroups = {
        'chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs', 'glutes', 'core', 'forearms', 'cardio'
      };
      const validEquipments = {
        'barbell', 'dumbbell', 'machine', 'cable', 'bodyweight', 'assisted', 'other'
      };

      await _db.transaction(() async {
        for (final item in list) {
          final name = (item['name'] as String? ?? '').trim();
          final id = (item['id'] as String? ?? '').trim();
          if (name.isEmpty) continue;

          String rawMgId = (item['muscleGroupId'] as String? ?? 'legs').trim().toLowerCase();
          final secList = List<String>.from((item['secondaryGroups'] as List<dynamic>? ?? []).map((e) => e.toString()));
          if (rawMgId == 'calves') {
            rawMgId = 'legs';
            if (!secList.contains('calves')) {
              secList.add('calves');
            }
          }
          final mgId = validMuscleGroups.contains(rawMgId) ? rawMgId : 'legs';

          String rawEq = (item['equipment'] as String? ?? 'barbell').trim().toLowerCase();
          final eqStr = validEquipments.contains(rawEq) ? rawEq : 'other';

          // --- Intelligent Gym Specification Inference ---
          final lowerName = name.toLowerCase();
          final isUnilateral = lowerName.contains('single') ||
              lowerName.contains('one-arm') ||
              lowerName.contains('one arm') ||
              lowerName.contains('one-leg') ||
              lowerName.contains('one leg') ||
              lowerName.contains('alternating');

          final isHold = lowerName.contains('plank') ||
              lowerName.contains('hang') ||
              lowerName.contains('wall sit') ||
              lowerName.contains('hold') ||
              lowerName.contains('l-sit');

          final isHeavyCompound = lowerName.contains('squat') ||
              lowerName.contains('deadlift') ||
              lowerName.contains('clean') ||
              lowerName.contains('snatch');

          final isPressOrRow = lowerName.contains('bench press') ||
              lowerName.contains('overhead press') ||
              lowerName.contains('military press') ||
              lowerName.contains('barbell row');

          // Rest time
          final jsonRest = (item['restSeconds'] as num?)?.toInt();
          int restSeconds = jsonRest ?? 90;
          if (jsonRest == null) {
            if (isHeavyCompound) {
              restSeconds = 120;
            } else if (isPressOrRow) {
              restSeconds = 90;
            } else if (mgId == 'core' || mgId == 'cardio' || isHold) {
              restSeconds = 45;
            } else if (eqStr == 'cable' || mgId == 'biceps' || mgId == 'triceps' || mgId == 'forearms') {
              restSeconds = 60;
            }
          }

          // Rep ranges
          final jsonRepMin = (item['repMin'] as num?)?.toInt();
          final jsonRepMax = (item['repMax'] as num?)?.toInt();
          int repMin = jsonRepMin ?? 8;
          int repMax = jsonRepMax ?? 12;
          if (jsonRepMin == null) {
            if (isHeavyCompound) {
              repMin = 5;
              repMax = 8;
            } else if (isPressOrRow) {
              repMin = 6;
              repMax = 10;
            } else if (mgId == 'core' || mgId == 'cardio') {
              repMin = 12;
              repMax = 20;
            } else if (eqStr == 'cable' || lowerName.contains('raise') || lowerName.contains('fly')) {
              repMin = 10;
              repMax = 15;
            }
          }

          // Weight step
          final jsonStep = (item['weightStep'] as num?)?.toDouble();
          double weightStep = jsonStep ?? 2.5;
          if (jsonStep == null) {
            if (eqStr == 'machine') {
              weightStep = 5.0;
            } else if (eqStr == 'bodyweight') {
              weightStep = 0.0;
            }
          }

          // Load mode
          final jsonLoadMode = item['loadMode'] as String?;
          String loadMode = jsonLoadMode ?? 'total';
          if (jsonLoadMode == null) {
            if (eqStr == 'bodyweight') {
              loadMode = 'bodyweight';
            } else if (eqStr == 'assisted') {
              loadMode = 'assisted';
            } else if (eqStr == 'dumbbell') {
              loadMode = 'per_hand';
            }
          }

          // Unilateral
          final jsonUnilateral = item['isUnilateral'] as bool?;
          final isUnilateralFinal = jsonUnilateral ?? isUnilateral;

          // Custom tracking type
          final jsonTrackingType = item['trackingType'] as String?;
          String? trackingType = jsonTrackingType;
          if (trackingType == null) {
            if (isHold) {
              trackingType = ExerciseTrackingType.duration.name;
            } else if (eqStr == 'bodyweight' && (mgId == 'core' || mgId == 'cardio')) {
              trackingType = ExerciseTrackingType.bodyweightReps.name;
            }
          }

          final existingEx = existingByName[name.toLowerCase()] ?? (id.isNotEmpty ? existingById[id] : null);
          if (existingEx != null) {
            // If already in database and from openGym, update its specs to the smart inferred values
            if (existingEx.id.startsWith('og_')) {
              await (_db.update(_db.exercises)..where((t) => t.id.equals(existingEx.id))).write(
                ExercisesCompanion(
                  loadMode: Value(loadMode),
                  isUnilateral: Value(isUnilateralFinal),
                  weightStep: Value(weightStep),
                  repMin: Value(repMin),
                  repMax: Value(repMax),
                  restSeconds: Value(restSeconds),
                  trackingType: Value(trackingType),
                ),
              );
            }
            continue;
          }

          await _db.into(_db.exercises).insert(
            ExercisesCompanion.insert(
              id: id.isNotEmpty ? id : 'og_${DateTime.now().microsecondsSinceEpoch}',
              name: name,
              muscleGroupId: mgId,
              secondaryGroups: Value(secList.join(',')),
              equipment: eqStr,
              loadMode: Value(loadMode),
              isUnilateral: Value(isUnilateralFinal),
              weightStep: Value(weightStep),
              repMin: Value(repMin),
              repMax: Value(repMax),
              restSeconds: Value(restSeconds),
              trackingType: Value(trackingType),
              isCustom: const Value(false),
              archived: const Value(false),
            ),
            mode: InsertMode.insertOrIgnore,
          );
          existingByName[name.toLowerCase()] = ExerciseData(
            id: id,
            name: name,
            muscleGroupId: mgId,
            secondaryGroups: secList.join(','),
            equipment: eqStr,
            loadMode: loadMode,
            isUnilateral: isUnilateralFinal,
            weightStep: weightStep,
            repMin: repMin,
            repMax: repMax,
            restSeconds: restSeconds,
            isCustom: false,
            archived: false,
            trackingType: trackingType,
          );
          insertedCount++;
        }
      });
      BackupService.scheduleAutoBackup(_db);
    } catch (e) {
      debugPrint('[ExerciseRepository] Error seeding openGym catalog: $e');
    }
    return insertedCount;
  }
}
