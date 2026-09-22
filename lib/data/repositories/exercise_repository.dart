import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../domain/models/exercise_model.dart';
import '../../domain/services/weight_step_learner.dart';

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
      ),
    );
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
      ),
    );
  }

  Future<void> archiveExercise(String id, bool archive) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(archived: Value(archive)),
    );
  }

  /// Retrieves past logged weights for an exercise to learn weight_step
  Future<List<double>> getWeightHistory(String exerciseId) async {
    final query = _db.select(_db.sets)
      ..where((t) => t.exerciseId.equals(exerciseId) & t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm(expression: t.date)]);
    final list = await query.get();
    return list.map((s) => s.weight).toList();
  }
}
