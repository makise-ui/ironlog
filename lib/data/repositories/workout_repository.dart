import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../../domain/models/exercise_model.dart';
import '../../domain/models/set_model.dart';
import '../../domain/models/workout_model.dart';
import '../../domain/services/paste_parser.dart';
import '../../domain/services/weight_step_learner.dart';
import '../../core/utils/fuzzy_matcher.dart';
import '../../core/utils/date_utils.dart';

class WorkoutRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  WorkoutRepository(this._db);

  /// Helper to map ExerciseData to ExerciseModel
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

  /// Helper to map GymSetData to SetModel
  SetModel _mapSet(GymSetData s) {
    return SetModel(
      id: s.id,
      workoutExerciseId: s.workoutExerciseId,
      exerciseId: s.exerciseId,
      muscleGroupId: s.muscleGroupId,
      date: s.date,
      setIndex: s.setIndex,
      weight: s.weight,
      reps: s.reps,
      setType: SetType.fromString(s.setType),
      rpe: s.rpe,
      completedAt: s.completedAt,
      archived: s.archived,
    );
  }

  /// Fetches or creates today's workout
  Future<WorkoutModel> getOrCreateTodayWorkout({String? routineTitle}) async {
    final today = AppDateUtils.normalizeDate(DateTime.now());
    final existing = await (_db.select(_db.workouts)
          ..where((t) => t.date.equals(today) & t.archived.equals(false)))
        .getSingleOrNull();

    if (existing != null) {
      return getWorkoutById(existing.id);
    }

    final newId = _uuid.v4();
    final title = routineTitle ?? 'Workout - ${AppDateUtils.formatShortDate(today)}';
    await _db.into(_db.workouts).insert(
      WorkoutsCompanion.insert(
        id: newId,
        date: today,
        startedAt: Value(DateTime.now()),
        title: title,
        archived: const Value(false),
      ),
    );

    return getWorkoutById(newId);
  }

  Future<WorkoutModel> getWorkoutById(String id) async {
    final wData = await (_db.select(_db.workouts)..where((t) => t.id.equals(id))).getSingle();
    final weQuery = _db.select(_db.workoutExercises).join([
      innerJoin(_db.exercises, _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId)),
    ])
      ..where(_db.workoutExercises.workoutId.equals(id) & _db.workoutExercises.archived.equals(false))
      ..orderBy([OrderingTerm(expression: _db.workoutExercises.position)]);

    final weRows = await weQuery.get();
    final exerciseItems = <WorkoutExerciseItem>[];

    for (final row in weRows) {
      final we = row.readTable(_db.workoutExercises);
      final ex = row.readTable(_db.exercises);

      final setsQuery = _db.select(_db.sets)
        ..where((t) => t.workoutExerciseId.equals(we.id) & t.archived.equals(false))
        ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]);
      final setRows = await setsQuery.get();

      exerciseItems.add(WorkoutExerciseItem(
        id: we.id,
        workoutId: we.workoutId,
        exercise: _mapExercise(ex),
        position: we.position,
        supersetGroup: we.supersetGroup,
        note: we.note,
        sets: setRows.map(_mapSet).toList(),
        archived: we.archived,
      ));
    }

    return WorkoutModel(
      id: wData.id,
      date: wData.date,
      startedAt: wData.startedAt,
      endedAt: wData.endedAt,
      title: wData.title,
      note: wData.note,
      feel: wData.feel,
      routineId: wData.routineId,
      exercises: exerciseItems,
      archived: wData.archived,
    );
  }

  Stream<WorkoutModel?> watchWorkout(String id) {
    return (_db.select(_db.workouts)..where((t) => t.id.equals(id))).watchSingleOrNull().asyncMap((wData) async {
      if (wData == null) return null;
      return getWorkoutById(id);
    });
  }

  /// Adds an exercise to workout
  Future<String> addExerciseToWorkout({
    required String workoutId,
    required String exerciseId,
    String? supersetGroup,
  }) async {
    final existingCount = await (_db.select(_db.workoutExercises)
          ..where((t) => t.workoutId.equals(workoutId)))
        .get();

    final id = _uuid.v4();
    await _db.into(_db.workoutExercises).insert(
      WorkoutExercisesCompanion.insert(
        id: id,
        workoutId: workoutId,
        exerciseId: exerciseId,
        position: existingCount.length,
        supersetGroup: Value(supersetGroup),
        archived: const Value(false),
      ),
    );
    return id;
  }

  /// Soft deletes a workout exercise (with sets)
  Future<void> removeExerciseFromWorkout(String workoutExerciseId) async {
    await (_db.update(_db.workoutExercises)..where((t) => t.id.equals(workoutExerciseId))).write(
      const WorkoutExercisesCompanion(archived: Value(true)),
    );
    await (_db.update(_db.sets)..where((t) => t.workoutExerciseId.equals(workoutExerciseId))).write(
      const SetsCompanion(archived: Value(true)),
    );
  }

  /// Restores a soft deleted workout exercise (undo)
  Future<void> restoreWorkoutExercise(String workoutExerciseId) async {
    await (_db.update(_db.workoutExercises)..where((t) => t.id.equals(workoutExerciseId))).write(
      const WorkoutExercisesCompanion(archived: Value(false)),
    );
    await (_db.update(_db.sets)..where((t) => t.workoutExerciseId.equals(workoutExerciseId))).write(
      const SetsCompanion(archived: Value(false)),
    );
  }

  /// Records a new set
  Future<String> logSet({
    required String workoutExerciseId,
    required String exerciseId,
    required String muscleGroupId,
    required DateTime date,
    required double weight,
    required int reps,
    SetType? setType,
    double? rpe,
  }) async {
    final existingSets = await (_db.select(_db.sets)
          ..where((t) => t.workoutExerciseId.equals(workoutExerciseId) & t.archived.equals(false)))
        .get();

    final setIndex = existingSets.length + 1;

    // Auto-suggest "warmup" when set 1 is <= 80% of the heaviest set in history or expected
    SetType determinedType = setType ?? SetType.working;
    if (setType == null && setIndex == 1) {
      if (existingSets.isNotEmpty) {
        final maxW = existingSets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
        if (maxW > 0 && weight <= (maxW * 0.8)) {
          determinedType = SetType.warmup;
        }
      }
    }

    final id = _uuid.v4();
    await _db.into(_db.sets).insert(
      SetsCompanion.insert(
        id: id,
        workoutExerciseId: workoutExerciseId,
        exerciseId: exerciseId,
        muscleGroupId: muscleGroupId,
        date: date,
        setIndex: setIndex,
        weight: weight,
        reps: reps,
        setType: determinedType.name,
        rpe: Value(rpe),
        completedAt: DateTime.now(),
        archived: const Value(false),
      ),
    );

    return id;
  }

  /// Soft deletes a set (undoable)
  Future<void> deleteSet(String setId) async {
    await (_db.update(_db.sets)..where((t) => t.id.equals(setId))).write(
      const SetsCompanion(archived: Value(true)),
    );
  }

  /// Restores a soft-deleted set
  Future<void> restoreSet(String setId) async {
    await (_db.update(_db.sets)..where((t) => t.id.equals(setId))).write(
      const SetsCompanion(archived: Value(false)),
    );
  }

  /// Updates an existing set
  Future<void> updateSet({
    required String setId,
    required double weight,
    required int reps,
    required SetType setType,
    double? rpe,
  }) async {
    await (_db.update(_db.sets)..where((t) => t.id.equals(setId))).write(
      SetsCompanion(
        weight: Value(weight),
        reps: Value(reps),
        setType: Value(setType.name),
        rpe: Value(rpe),
      ),
    );
  }

  /// Updates workout metadata (note, feel, title, endedAt)
  Future<void> updateWorkoutMeta({
    required String workoutId,
    String? title,
    String? note,
    int? feel,
    DateTime? endedAt,
  }) async {
    await (_db.update(_db.workouts)..where((t) => t.id.equals(workoutId))).write(
      WorkoutsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        note: note != null ? Value(note) : const Value.absent(),
        feel: feel != null ? Value(feel) : const Value.absent(),
        endedAt: endedAt != null ? Value(endedAt) : const Value.absent(),
      ),
    );
  }

  /// Reorder workout exercises
  Future<void> reorderExercises(String workoutId, List<String> workoutExerciseIds) async {
    for (int i = 0; i < workoutExerciseIds.length; i++) {
      await (_db.update(_db.workoutExercises)..where((t) => t.id.equals(workoutExerciseIds[i]))).write(
        WorkoutExercisesCompanion(position: Value(i)),
      );
    }
  }

  /// Sets or clears superset group
  Future<void> setSupersetGroup(String workoutExerciseId, String? group) async {
    await (_db.update(_db.workoutExercises)..where((t) => t.id.equals(workoutExerciseId))).write(
      WorkoutExercisesCompanion(supersetGroup: Value(group)),
    );
  }

  /// Copies last session of this workout title / routine
  Future<void> copyLastSession(String targetWorkoutId, String previousWorkoutId) async {
    final prevWorkout = await getWorkoutById(previousWorkoutId);
    for (final prevEx in prevWorkout.exercises) {
      if (prevEx.archived) continue;
      final weId = await addExerciseToWorkout(
        workoutId: targetWorkoutId,
        exerciseId: prevEx.exercise.id,
        supersetGroup: prevEx.supersetGroup,
      );

      // Copy target sets
      for (final s in prevEx.sets) {
        if (s.archived) continue;
        await logSet(
          workoutExerciseId: weId,
          exerciseId: prevEx.exercise.id,
          muscleGroupId: s.muscleGroupId,
          date: DateTime.now(),
          weight: s.weight,
          reps: s.reps,
          setType: s.setType,
          rpe: s.rpe,
        );
      }
    }
  }

  /// Commits parsed blocks from the Paste-to-Log Importer
  Future<String> commitParsedWorkout({
    required List<ParsedExerciseBlock> blocks,
    required DateTime date,
    String? title,
  }) async {
    final allExercises = await (_db.select(_db.exercises)..where((t) => t.archived.equals(false))).get();
    final normalizedDate = AppDateUtils.normalizeDate(date);

    // Create or use workout
    final workoutId = _uuid.v4();
    final workoutTitle = title ?? 'Imported Workout - ${AppDateUtils.formatShortDate(normalizedDate)}';

    await _db.into(_db.workouts).insert(
      WorkoutsCompanion.insert(
        id: workoutId,
        date: normalizedDate,
        startedAt: Value(normalizedDate.add(const Duration(hours: 10))),
        endedAt: Value(normalizedDate.add(const Duration(hours: 11, minutes: 15))),
        title: workoutTitle,
        archived: const Value(false),
      ),
    );

    for (final block in blocks) {
      // Fuzzy-match exercise name
      final match = FuzzyMatcher.bestMatch<ExerciseData>(
        query: block.exerciseName,
        items: allExercises,
        textExtractor: (ex) => ex.name,
        threshold: 0.45,
      );

      String exerciseId;
      String muscleGroupId;

      if (match != null) {
        exerciseId = match.item.id;
        muscleGroupId = match.item.muscleGroupId;
      } else {
        // Unknown exercise creates inline custom exercise
        exerciseId = _uuid.v4();
        muscleGroupId = 'chest'; // default group for custom
        await _db.into(_db.exercises).insert(
          ExercisesCompanion.insert(
            id: exerciseId,
            name: block.exerciseName,
            muscleGroupId: muscleGroupId,
            equipment: 'other',
            isCustom: const Value(true),
            archived: const Value(false),
          ),
        );
      }

      final weId = await addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
      );

      for (final s in block.sets) {
        await logSet(
          workoutExerciseId: weId,
          exerciseId: exerciseId,
          muscleGroupId: muscleGroupId,
          date: normalizedDate,
          weight: s.weight,
          reps: s.reps,
          setType: SetType.working,
        );
      }
    }

    return workoutId;
  }

  /// History: fetches past workouts with optional filters
  Future<List<WorkoutModel>> getHistoryWorkouts({
    String? muscleGroupId,
    String? exerciseId,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = _db.select(_db.workouts)
      ..where((t) => t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
      ..limit(limit, offset: offset);

    final wList = await query.get();
    final result = <WorkoutModel>[];

    for (final w in wList) {
      final model = await getWorkoutById(w.id);

      // Apply filter if specified
      if (muscleGroupId != null && muscleGroupId.isNotEmpty) {
        final matchesGroup = model.exercises.any(
          (e) => e.exercise.muscleGroupId == muscleGroupId,
        );
        if (!matchesGroup) continue;
      }

      if (exerciseId != null && exerciseId.isNotEmpty) {
        final matchesEx = model.exercises.any(
          (e) => e.exercise.id == exerciseId,
        );
        if (!matchesEx) continue;
      }

      result.add(model);
    }

    return result;
  }
}
