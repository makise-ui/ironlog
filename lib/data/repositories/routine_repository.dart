import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../database/seed_data.dart';
import '../../domain/models/exercise_model.dart';
import '../../domain/models/routine_model.dart';
import '../../domain/services/weight_step_learner.dart';
import '../../domain/services/backup_service.dart';

class RoutineRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  RoutineRepository(this._db);

  ExerciseModel _mapExercise(ExerciseData data) {
    final secondary = data.secondaryGroups.isEmpty
        ? <String>[]
        : data.secondaryGroups.split(',').map((s) => s.trim()).toList();

    EquipmentType equip = EquipmentType.barbell;
    try {
      equip = EquipmentType.values.byName(data.equipment.toLowerCase());
    } catch (_) {}

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
    );
  }

  Future<List<RoutineModel>> getRoutines() async {
    final rList = await (_db.select(_db.routines)
          ..where((t) => t.archived.equals(false)))
        .get();

    final result = <RoutineModel>[];
    for (final r in rList) {
      final itemsQuery = _db.select(_db.routineItems).join([
        innerJoin(_db.exercises, _db.exercises.id.equalsExp(_db.routineItems.exerciseId)),
      ])
        ..where(_db.routineItems.routineId.equals(r.id))
        ..orderBy([OrderingTerm(expression: _db.routineItems.position)]);

      final itemRows = await itemsQuery.get();
      final items = itemRows.map((row) {
        final ri = row.readTable(_db.routineItems);
        final ex = row.readTable(_db.exercises);
        return RoutineItemModel(
          id: ri.id,
          routineId: ri.routineId,
          exercise: _mapExercise(ex),
          position: ri.position,
          targetSets: ri.targetSets,
          repMin: ri.repMin,
          repMax: ri.repMax,
          restSeconds: ri.restSeconds,
        );
      }).toList();

      result.add(RoutineModel(
        id: r.id,
        name: r.name,
        description: r.description,
        items: items,
        archived: r.archived,
      ));
    }

    return result;
  }

  Future<String> createRoutine({
    required String name,
    required String description,
    required List<String> exerciseIds,
  }) async {
    final routineId = _uuid.v4();
    await _db.into(_db.routines).insert(
      RoutinesCompanion.insert(
        id: routineId,
        name: name,
        description: Value(description),
        archived: const Value(false),
      ),
    );

    for (int i = 0; i < exerciseIds.length; i++) {
      await _db.into(_db.routineItems).insert(
        RoutineItemsCompanion.insert(
          id: '${routineId}_item_$i',
          routineId: routineId,
          exerciseId: exerciseIds[i],
          position: i,
        ),
      );
    }

    BackupService.scheduleAutoBackup(_db);
    return routineId;
  }

  Future<void> updateRoutine({
    required String routineId,
    String? name,
    String? description,
    List<String>? exerciseIds,
  }) async {
    if (name != null || description != null) {
      await (_db.update(_db.routines)..where((t) => t.id.equals(routineId))).write(
        RoutinesCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          description: description != null ? Value(description) : const Value.absent(),
        ),
      );
    }

    if (exerciseIds != null) {
      await (_db.delete(_db.routineItems)..where((t) => t.routineId.equals(routineId))).go();
      for (int i = 0; i < exerciseIds.length; i++) {
        await _db.into(_db.routineItems).insert(
          RoutineItemsCompanion.insert(
            id: '${routineId}_item_${DateTime.now().millisecondsSinceEpoch}_$i',
            routineId: routineId,
            exerciseId: exerciseIds[i],
            position: i,
          ),
        );
      }
    }
    BackupService.scheduleAutoBackup(_db);
  }

  Future<void> deleteRoutine(String routineId) async {
    await (_db.update(_db.routines)..where((t) => t.id.equals(routineId))).write(
      const RoutinesCompanion(archived: Value(true)),
    );
    BackupService.scheduleAutoBackup(_db);
  }

  Future<void> restoreDefaultRoutines() async {
    for (final routine in SeedData.defaultRoutines) {
      final routineId = routine['id'] as String;
      await (_db.update(_db.routines)..where((t) => t.id.equals(routineId))).write(
        const RoutinesCompanion(archived: Value(false)),
      );
    }
  }

  Stream<List<RoutineModel>> watchRoutines() {
    return (_db.select(_db.routines)..where((t) => t.archived.equals(false)))
        .watch()
        .asyncMap((_) => getRoutines());
  }
}
