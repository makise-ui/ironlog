import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../../domain/models/exercise_model.dart';
import '../../domain/models/set_model.dart';
import '../../domain/models/workout_model.dart';
import '../../domain/services/paste_parser.dart';
import '../../domain/services/weight_step_learner.dart';
import '../../domain/models/analytics_model.dart';
import '../../core/utils/fuzzy_matcher.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/services/backup_service.dart';

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

  /// Fetches existing non-archived workout for a specific date (if any)
  Future<WorkoutModel?> getWorkoutForDate(DateTime date) async {
    final normDate = AppDateUtils.normalizeDate(date);
    final existingList = await (_db.select(_db.workouts)
          ..where((t) => t.date.equals(normDate) & t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .get();
    final existing = existingList.firstOrNull;
    if (existing == null) return null;
    return getWorkoutById(existing.id);
  }

  /// Fetches or creates workout for a specific date (defaults to today)
  Future<WorkoutModel> getOrCreateWorkoutForDate(DateTime date, {String? routineTitle}) async {
    final normDate = AppDateUtils.normalizeDate(date);
    final existing = await getWorkoutForDate(normDate);
    if (existing != null) {
      return existing;
    }

    final newId = _uuid.v4();
    final title = routineTitle ?? 'Workout - ${AppDateUtils.formatShortDate(normDate)}';
    await _db.into(_db.workouts).insert(
      WorkoutsCompanion.insert(
        id: newId,
        date: normDate,
        startedAt: const Value(null),
        title: title,
        archived: const Value(false),
      ),
    );

    return getWorkoutById(newId);
  }

  /// Fetches or creates today's workout
  Future<WorkoutModel> getOrCreateTodayWorkout({String? routineTitle}) async {
    return getOrCreateWorkoutForDate(DateTime.now(), routineTitle: routineTitle);
  }

  /// Fetches today's non-archived workout if it exists (does not create a new one)
  Future<WorkoutModel?> getTodayWorkout() async {
    return getWorkoutForDate(DateTime.now());
  }

  /// Safe query for workout by ID returning null if not found
  Future<WorkoutModel?> getWorkoutByIdOrNull(String id) async {
    try {
      final wData = await (_db.select(_db.workouts)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (wData == null) return null;
      return getWorkoutById(id);
    } catch (_) {
      return null;
    }
  }

  /// Deletes a workout session
  Future<void> deleteWorkout(String workoutId) async {
    await discardWorkout(workoutId);
    BackupService.scheduleAutoBackup(_db);
  }

  /// Creates a fresh new workout session for a date
  Future<WorkoutModel> createNewWorkoutForDate(DateTime date, {String? routineTitle}) async {
    final normDate = AppDateUtils.normalizeDate(date);
    final count = await (_db.select(_db.workouts)
          ..where((t) => t.date.equals(normDate) & t.archived.equals(false)))
        .get();
    final sessionNum = count.length + 1;
    final newId = _uuid.v4();
    final title = routineTitle ?? 'Workout $sessionNum - ${AppDateUtils.formatShortDate(normDate)}';
    await _db.into(_db.workouts).insert(
      WorkoutsCompanion.insert(
        id: newId,
        date: normDate,
        startedAt: const Value(null),
        title: title,
        archived: const Value(false),
      ),
    );
    return getWorkoutById(newId);
  }

  /// Starts workout timer explicitly
  Future<void> startWorkout(String workoutId, {DateTime? startedAt}) async {
    await (_db.update(_db.workouts)..where((t) => t.id.equals(workoutId))).write(
      WorkoutsCompanion(
        startedAt: Value(startedAt ?? DateTime.now()),
      ),
    );
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

  /// Ensures that any orphan workout_exercises or sets belonging to an archived workout are properly marked archived
  Future<void> _cleanupArchivedWorkoutRelations() async {
    try {
      await _db.customStatement('''
        UPDATE workout_exercises SET archived = 1
        WHERE workout_id IN (SELECT id FROM workouts WHERE archived = 1);
      ''');
      await _db.customStatement('''
        UPDATE sets SET archived = 1
        WHERE workout_exercise_id IN (
          SELECT id FROM workout_exercises WHERE archived = 1
        );
      ''');
    } catch (_) {}
  }

  /// Discards / abandons a workout session (soft deletes workout, exercises, and sets)
  Future<void> discardWorkout(String workoutId) async {
    await (_db.update(_db.workouts)..where((t) => t.id.equals(workoutId))).write(
      const WorkoutsCompanion(archived: Value(true)),
    );
    try {
      await _db.customStatement('''
        UPDATE workout_exercises SET archived = 1 WHERE workout_id = ?;
      ''', [workoutId]);
      await _db.customStatement('''
        UPDATE sets SET archived = 1 
        WHERE workout_exercise_id IN (SELECT id FROM workout_exercises WHERE workout_id = ?);
      ''', [workoutId]);
    } catch (_) {
      final weRows = await (_db.select(_db.workoutExercises)..where((t) => t.workoutId.equals(workoutId))).get();
      for (final we in weRows) {
        await (_db.update(_db.workoutExercises)..where((t) => t.id.equals(we.id))).write(
          const WorkoutExercisesCompanion(archived: Value(true)),
        );
        await (_db.update(_db.sets)..where((t) => t.workoutExerciseId.equals(we.id))).write(
          const SetsCompanion(archived: Value(true)),
        );
      }
    }
    await _cleanupArchivedWorkoutRelations();
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

    // Auto-start workout timer if not already started
    final we = await (_db.select(_db.workoutExercises)..where((t) => t.id.equals(workoutExerciseId))).getSingleOrNull();
    if (we != null) {
      final w = await (_db.select(_db.workouts)..where((t) => t.id.equals(we.workoutId))).getSingleOrNull();
      if (w != null && w.startedAt == null) {
        await (_db.update(_db.workouts)..where((t) => t.id.equals(w.id))).write(
          WorkoutsCompanion(startedAt: Value(DateTime.now())),
        );
      }
    }

    BackupService.scheduleAutoBackup(_db);
    return id;
  }

  /// Soft deletes a set (undoable)
  Future<void> deleteSet(String setId) async {
    await (_db.update(_db.sets)..where((t) => t.id.equals(setId))).write(
      const SetsCompanion(archived: Value(true)),
    );
    BackupService.scheduleAutoBackup(_db);
  }

  /// Restores a soft-deleted set
  Future<void> restoreSet(String setId) async {
    await (_db.update(_db.sets)..where((t) => t.id.equals(setId))).write(
      const SetsCompanion(archived: Value(false)),
    );
    BackupService.scheduleAutoBackup(_db);
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
    BackupService.scheduleAutoBackup(_db);
  }

  /// Updates workout metadata (note, feel, title, endedAt)
  Future<void> updateWorkoutMeta({
    required String workoutId,
    String? title,
    String? note,
    bool clearNote = false,
    int? feel,
    DateTime? endedAt,
    bool clearEndedAt = false,
  }) async {
    await (_db.update(_db.workouts)..where((t) => t.id.equals(workoutId))).write(
      WorkoutsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        note: clearNote ? const Value(null) : (note != null ? Value(note) : const Value.absent()),
        feel: feel != null ? Value(feel) : const Value.absent(),
        endedAt: clearEndedAt ? const Value(null) : (endedAt != null ? Value(endedAt) : const Value.absent()),
      ),
    );
    BackupService.scheduleAutoBackup(_db);
  }

  /// Reopens a finished workout so the user can continue logging
  Future<void> reopenWorkout(String workoutId) async {
    await updateWorkoutMeta(workoutId: workoutId, clearEndedAt: true);
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
    await _db.transaction(() async {
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
    });
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

    await _db.transaction(() async {
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
    });

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
    if (wList.isEmpty) return [];

    final workoutIds = wList.map((w) => w.id).toList();

    // Query 2: Batch fetch all workout_exercises for these workouts
    final weQuery = _db.select(_db.workoutExercises).join([
      innerJoin(_db.exercises, _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId)),
    ])
      ..where(_db.workoutExercises.workoutId.isIn(workoutIds) & _db.workoutExercises.archived.equals(false))
      ..orderBy([OrderingTerm(expression: _db.workoutExercises.position)]);

    final weRows = await weQuery.get();
    final weIds = <String>[];
    final weItemsByWorkout = <String, List<WorkoutExerciseItem>>{};
    final weMap = <String, WorkoutExerciseItem>{};

    for (final row in weRows) {
      final we = row.readTable(_db.workoutExercises);
      final ex = row.readTable(_db.exercises);
      weIds.add(we.id);

      final item = WorkoutExerciseItem(
        id: we.id,
        workoutId: we.workoutId,
        exercise: _mapExercise(ex),
        position: we.position,
        supersetGroup: we.supersetGroup,
        note: we.note,
        sets: [],
        archived: we.archived,
      );

      weMap[we.id] = item;
      weItemsByWorkout.putIfAbsent(we.workoutId, () => []).add(item);
    }

    // Query 3: Batch fetch all sets for these workout exercises
    if (weIds.isNotEmpty) {
      for (var i = 0; i < weIds.length; i += 400) {
        final chunk = weIds.sublist(i, (i + 400 > weIds.length) ? weIds.length : i + 400);
        final setsQuery = _db.select(_db.sets)
          ..where((t) => t.workoutExerciseId.isIn(chunk) & t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]);
        final setRows = await setsQuery.get();

        for (final s in setRows) {
          final item = weMap[s.workoutExerciseId];
          if (item != null) {
            item.sets.add(_mapSet(s));
          }
        }
      }
    }

    final result = <WorkoutModel>[];
    for (final w in wList) {
      final exercises = weItemsByWorkout[w.id] ?? [];

      if (muscleGroupId != null && muscleGroupId.isNotEmpty) {
        final matches = exercises.any((e) => e.exercise.muscleGroupId == muscleGroupId);
        if (!matches) continue;
      }

      if (exerciseId != null && exerciseId.isNotEmpty) {
        final matches = exercises.any((e) => e.exercise.id == exerciseId);
        if (!matches) continue;
      }

      result.add(WorkoutModel(
        id: w.id,
        date: w.date,
        startedAt: w.startedAt,
        endedAt: w.endedAt,
        title: w.title,
        note: w.note,
        feel: w.feel,
        routineId: w.routineId,
        exercises: exercises,
        archived: w.archived,
      ));
    }

    return result;
  }

  /// Marks an arbitrary date as a Rest & Recovery Day
  Future<void> markDateAsRestDay(DateTime date, {bool isRest = true, String? note}) async {
    final workout = await getOrCreateWorkoutForDate(date);
    await markAsRestDay(workout.id, isRest: isRest, note: note);
  }

  /// Marks a workout date as a Rest & Recovery Day
  Future<void> markAsRestDay(String workoutId, {bool isRest = true, String? note}) async {
    final title = isRest ? 'Rest & Recovery Day' : 'Workout Today';
    final restNote = isRest ? (note ?? 'Scheduled Rest Day. Muscle recovery, hydration, and sleep.') : null;

    await updateWorkoutMeta(
      workoutId: workoutId,
      title: title,
      note: restNote,
      clearNote: !isRest,
      feel: isRest ? 4 : null,
      endedAt: isRest ? DateTime.now() : null,
    );
  }

  /// Applies a routine to a workout (updates title and adds routine exercises)
  Future<void> applyRoutineToWorkout(String workoutId, String routineId) async {
    final routineData = await (_db.select(_db.routines)..where((t) => t.id.equals(routineId))).getSingle();
    await updateWorkoutMeta(workoutId: workoutId, title: routineData.name);

    final items = await (_db.select(_db.routineItems)
          ..where((t) => t.routineId.equals(routineId))
          ..orderBy([(t) => OrderingTerm(expression: t.position)]))
        .get();

    for (final item in items) {
      await addExerciseToWorkout(workoutId: workoutId, exerciseId: item.exerciseId);
    }
  }

  /// Recent workouts for analytics and suggestions
  Future<List<WorkoutModel>> getRecentWorkouts({int limit = 30}) async {
    return getHistoryWorkouts(limit: limit);
  }

  /// Fetches previous session sets for an exercise
  Future<List<SetModel>> getPreviousSetsForExercise(String exerciseId, {DateTime? beforeDate}) async {

    final cutoff = beforeDate ?? AppDateUtils.normalizeDate(DateTime.now());
    final query = _db.select(_db.sets)
      ..where((t) => t.exerciseId.equals(exerciseId) & t.archived.equals(false) & t.date.isSmallerThanValue(cutoff))
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]);

    final rows = await query.get();
    if (rows.isEmpty) return [];

    // Find the latest workout date
    final latestDate = rows.first.date;
    final latestSets = rows.where((s) => s.date.year == latestDate.year && s.date.month == latestDate.month && s.date.day == latestDate.day).toList();
    latestSets.sort((a, b) => a.setIndex.compareTo(b.setIndex));
    return latestSets.map(_mapSet).toList();
  }

  /// Fetches all historical sets for an exercise (for PR detection)
  Future<List<SetModel>> getAllHistoricalSetsForExercise(String exerciseId) async {

    final query = _db.select(_db.sets)
      ..where((t) => t.exerciseId.equals(exerciseId) & t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]);

    final rows = await query.get();
    return rows.map(_mapSet).toList();
  }

  /// Analytics: daily volume and sets count for the last N days (default 7)
  Future<List<DailyVolumeStat>> getDailyVolumeStats({int days = 7}) async {

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(Duration(days: days - 1));

    final query = _db.select(_db.sets)
      ..where((t) => t.archived.equals(false) & t.date.isBiggerOrEqualValue(startDate))
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc)]);
    final rows = await query.get();

    final Map<DateTime, double> volumeMap = {};
    final Map<DateTime, int> setsMap = {};

    for (int i = 0; i < days; i++) {
      final d = startDate.add(Duration(days: i));
      final norm = DateTime(d.year, d.month, d.day);
      volumeMap[norm] = 0.0;
      setsMap[norm] = 0;
    }

    for (final s in rows) {
      final norm = DateTime(s.date.year, s.date.month, s.date.day);
      if (volumeMap.containsKey(norm)) {
        volumeMap[norm] = (volumeMap[norm] ?? 0.0) + (s.weight * s.reps);
        setsMap[norm] = (setsMap[norm] ?? 0) + 1;
      }
    }

    return volumeMap.entries.map((e) {
      return DailyVolumeStat(
        date: e.key,
        volume: e.value,
        setsCount: setsMap[e.key] ?? 0,
      );
    }).toList();
  }

  /// Analytics: muscle group breakdown (sets per muscle group)
  Future<Map<String, int>> getMuscleGroupBreakdown({int days = 30}) async {

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));

    final query = _db.select(_db.sets)
      ..where((t) => t.archived.equals(false) & t.date.isBiggerOrEqualValue(cutoff));
    final rows = await query.get();

    final mgQuery = await _db.select(_db.muscleGroups).get();
    final Map<String, String> mgNameMap = {for (final m in mgQuery) m.id: m.name};

    final Map<String, int> counts = {};
    for (final s in rows) {
      final name = mgNameMap[s.muscleGroupId] ?? s.muscleGroupId;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    return counts;
  }

  /// Analytics: Overview metrics
  Future<AnalyticsOverviewData> getAnalyticsOverview() async {

    final sets = await (_db.select(_db.sets)..where((t) => t.archived.equals(false))).get();
    final allWorkouts = await (_db.select(_db.workouts)..where((t) => t.archived.equals(false))).get();

    final activeSetWorkouts = await _db.customSelect(
      'SELECT DISTINCT we.workout_id FROM sets s '
      'INNER JOIN workout_exercises we ON s.workout_exercise_id = we.id '
      'WHERE s.archived = 0 AND (s.reps > 0 OR s.weight > 0)',
    ).get();
    final workoutIdsWithCompletedSets = activeSetWorkouts.map((row) => row.read<String>('workout_id')).toSet();

    final workouts = allWorkouts.where((w) => workoutIdsWithCompletedSets.contains(w.id) && !w.title.toLowerCase().contains('rest')).toList();
    final restWorkouts = allWorkouts.where((w) => w.title.toLowerCase().contains('rest')).toList();

    double totalVol = 0.0;
    int totalReps = 0;
    for (final s in sets) {
      totalVol += (s.weight * s.reps);
      totalReps += s.reps;
    }

    // Streak calculation (strictly consecutive active lifted-weight or rest-logged days)
    final allDates = workouts.map((w) => DateTime(w.date.year, w.date.month, w.date.day)).toSet();
    final restDates = restWorkouts.map((w) => DateTime(w.date.year, w.date.month, w.date.day)).toSet();
    final activeOrRestDates = {...allDates, ...restDates};

    int streak = 0;
    final now = DateTime.now();
    DateTime checkDate = DateTime(now.year, now.month, now.day);
    if (!activeOrRestDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    while (activeOrRestDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return AnalyticsOverviewData(
      totalVolume: totalVol,
      totalWorkouts: workouts.length,
      totalSets: sets.length,
      totalReps: totalReps,
      currentStreakDays: streak,
    );
  }

  /// Analytics: Recent PRs joined with exercise info
  Future<List<PrItemData>> getRecentPrs({int limit = 10}) async {
    final prRows = await (_db.select(_db.prs)
          ..orderBy([(t) => OrderingTerm(expression: t.achievedAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();

    final exRows = await _db.select(_db.exercises).get();
    final exMap = {for (final e in exRows) e.id: e};

    return prRows.map((pr) {
      final ex = exMap[pr.exerciseId];
      return PrItemData(
        id: pr.id,
        exerciseId: pr.exerciseId,
        exerciseName: ex?.name ?? 'Exercise',
        muscleGroupId: ex?.muscleGroupId ?? 'General',
        kind: pr.kind,
        value: pr.value,
        achievedAt: pr.achievedAt,
      );
    }).toList();
  }

  /// Calculates streak and this week's 7-day completion activity
  Future<StreakAndWeekData> getStreakAndWeekData() async {

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd = weekStart.add(const Duration(days: 7));

    final weekWorkouts = await (_db.select(_db.workouts)
          ..where((t) => t.date.isBiggerOrEqualValue(weekStart) & t.date.isSmallerThanValue(weekEnd) & t.archived.equals(false)))
        .get();

    final activeSetWorkouts = await _db.customSelect(
      'SELECT DISTINCT we.workout_id FROM sets s '
      'INNER JOIN workout_exercises we ON s.workout_exercise_id = we.id '
      'WHERE s.archived = 0 AND (s.reps > 0 OR s.weight > 0)',
    ).get();
    final workoutIdsWithCompletedSets = activeSetWorkouts.map((row) => row.read<String>('workout_id')).toSet();

    final completedWeekdays = <int>{};
    for (final w in weekWorkouts) {
      final isRest = w.title.toLowerCase().contains('rest');
      final hasLifted = workoutIdsWithCompletedSets.contains(w.id);
      if (isRest || hasLifted) {
        completedWeekdays.add(w.date.weekday);
      }
    }

    final allNonArchived = await (_db.select(_db.workouts)
          ..where((t) => t.archived.equals(false)))
        .get();

    final activeOrRestDates = allNonArchived
        .where((w) => workoutIdsWithCompletedSets.contains(w.id) || w.title.toLowerCase().contains('rest'))
        .map((w) => DateTime(w.date.year, w.date.month, w.date.day))
        .toSet();

    int streak = 0;
    DateTime checkDate = DateTime(now.year, now.month, now.day);
    if (!activeOrRestDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    while (activeOrRestDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    final nonRestCount = weekWorkouts
        .where((w) => workoutIdsWithCompletedSets.contains(w.id) && !w.title.toLowerCase().contains('rest'))
        .length;

    return StreakAndWeekData(
      streakDays: streak,
      completedWeekdays: completedWeekdays,
      workoutsThisWeek: nonRestCount,
    );
  }

  /// Advanced: avg reps per set per muscle group in window
  Future<Map<String, double>> getAvgRepsPerMuscleGroup({int days = 30}) async {

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final rows = await (_db.select(_db.sets)..where((t) => t.archived.equals(false) & t.date.isBiggerOrEqualValue(cutoff))).get();
    final mgQuery = await _db.select(_db.muscleGroups).get();
    final mgNameMap = {for (final m in mgQuery) m.id: m.name};
    final Map<String, List<int>> repsByMg = {};
    for (final s in rows) {
      final name = mgNameMap[s.muscleGroupId] ?? s.muscleGroupId;
      repsByMg.putIfAbsent(name, () => []).add(s.reps);
    }
    return {for (final e in repsByMg.entries) e.key: e.value.fold(0, (a, b) => a + b) / e.value.length};
  }

  /// Advanced: weekly frequency (workouts per week) over last N weeks
  Future<List<WeeklyFrequencyStat>> getWeeklyFrequency({int weeks = 8}) async {

    final now = DateTime.now();
    final result = <WeeklyFrequencyStat>[];
    for (int w = weeks - 1; w >= 0; w--) {
      final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1 + w * 7));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final rows = await (_db.select(_db.workouts)
            ..where((t) => t.date.isBiggerOrEqualValue(weekStart) & t.date.isSmallerThanValue(weekEnd) & t.archived.equals(false)))
          .get();
      final activeSetRows = await _db.customSelect(
        'SELECT DISTINCT we.workout_id FROM sets s '
        'INNER JOIN workout_exercises we ON s.workout_exercise_id = we.id '
        'WHERE s.archived = 0 AND (s.reps > 0 OR s.weight > 0)',
      ).get();
      final activeIds = activeSetRows.map((r) => r.read<String>('workout_id')).toSet();
      final activeCount = rows.where((r) => activeIds.contains(r.id) && !r.title.toLowerCase().contains('rest')).length;
      result.add(WeeklyFrequencyStat(weekStart: weekStart, workoutCount: activeCount));
    }
    return result;
  }

  /// Advanced: top 5 exercises by total volume
  Future<List<ExerciseVolumeStat>> getTopExercisesByVolume({int days = 30, int limit = 5}) async {

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final rows = await (_db.select(_db.sets)..where((t) => t.archived.equals(false) & t.date.isBiggerOrEqualValue(cutoff))).get();
    final exRows = await _db.select(_db.exercises).get();
    final exMap = {for (final e in exRows) e.id: e.name};
    final weRows = await _db.select(_db.workoutExercises).get();
    final weMap = {for (final e in weRows) e.id: e.exerciseId};
    final Map<String, double> volByEx = {};
    final Map<String, int> setsByEx = {};
    for (final s in rows) {
      final exId = weMap[s.workoutExerciseId] ?? '';
      final name = exMap[exId] ?? 'Unknown';
      volByEx[name] = (volByEx[name] ?? 0) + s.weight * s.reps;
      setsByEx[name] = (setsByEx[name] ?? 0) + 1;
    }
    final sorted = volByEx.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => ExerciseVolumeStat(exerciseName: e.key, totalVolume: e.value, setsCount: setsByEx[e.key] ?? 0)).toList();
  }

  /// Advanced: avg workout duration in minutes over last N days
  Future<double> getAvgWorkoutDurationMinutes({int days = 30}) async {

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final rows = await (_db.select(_db.workouts)
          ..where((t) => t.archived.equals(false) & t.date.isBiggerOrEqualValue(cutoff)))
        .get();
    final durations = rows.where((w) => w.startedAt != null && w.endedAt != null).map((w) => w.endedAt!.difference(w.startedAt!).inMinutes).where((d) => d > 0 && d < 300).toList();
    if (durations.isEmpty) return 0;
    return durations.fold(0, (a, b) => a + b) / durations.length;
  }

  /// Advanced: best set per exercise (heaviest weight x reps) in last N days
  Future<List<BestSetStat>> getBestSetsPerExercise({int days = 30, int limit = 8}) async {

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final rows = await (_db.select(_db.sets)..where((t) => t.archived.equals(false) & t.date.isBiggerOrEqualValue(cutoff))).get();
    final exRows = await _db.select(_db.exercises).get();
    final exMap = {for (final e in exRows) e.id: e.name};
    final weRows = await _db.select(_db.workoutExercises).get();
    final weMap = {for (final e in weRows) e.id: e.exerciseId};
    final Map<String, SetData> best = {};
    for (final s in rows) {
      if (s.weight <= 0 || s.reps <= 0) continue;
      final exId = weMap[s.workoutExerciseId] ?? '';
      final name = exMap[exId] ?? 'Unknown';
      final e1rm = s.weight * (1 + s.reps / 30.0);
      if (!best.containsKey(name) || e1rm > best[name]!.e1rm) {
        best[name] = SetData(weight: s.weight, reps: s.reps, e1rm: e1rm, date: s.date);
      }
    }
    final sorted = best.entries.toList()..sort((a, b) => b.value.e1rm.compareTo(a.value.e1rm));
    return sorted.take(limit).map((e) => BestSetStat(exerciseName: e.key, weight: e.value.weight, reps: e.value.reps, e1rm: e.value.e1rm, date: e.value.date)).toList();
  }

  /// Advanced: rep range distribution across strength (1-5), hypertrophy (6-12), and endurance (13+)
  Future<List<RepRangeStat>> getRepRangeDistribution({int days = 30}) async {

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final rows = await (_db.select(_db.sets)
          ..where((t) => t.archived.equals(false) & t.date.isBiggerOrEqualValue(cutoff)))
        .get();

    int strength = 0; // 1-5 reps
    int hypertrophy = 0; // 6-12 reps
    int endurance = 0; // 13+ reps

    for (final s in rows) {
      if (s.reps <= 0) continue;
      if (s.reps <= 5) {
        strength++;
      } else if (s.reps <= 12) {
        hypertrophy++;
      } else {
        endurance++;
      }
    }

    final total = strength + hypertrophy + endurance;
    if (total == 0) return [];

    return [
      RepRangeStat(
        label: 'Strength',
        rangeDescription: '1–5 reps',
        count: strength,
        percentage: strength / total,
      ),
      RepRangeStat(
        label: 'Hypertrophy',
        rangeDescription: '6–12 reps',
        count: hypertrophy,
        percentage: hypertrophy / total,
      ),
      RepRangeStat(
        label: 'Endurance',
        rangeDescription: '13+ reps',
        count: endurance,
        percentage: endurance / total,
      ),
    ];
  }
}

class StreakAndWeekData {
  final int streakDays;
  final Set<int> completedWeekdays; // 1 = Monday, 7 = Sunday
  final int workoutsThisWeek;

  const StreakAndWeekData({
    required this.streakDays,
    required this.completedWeekdays,
    required this.workoutsThisWeek,
  });
}

