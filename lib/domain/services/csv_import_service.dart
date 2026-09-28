import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../data/database/database.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../domain/models/set_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/unit_converter.dart';

class CsvImportResult {
  final String sourceApp;
  final int totalRows;
  final int workoutsImported;
  final int exercisesMatched;
  final int customExercisesCreated;
  final int setsImported;
  final List<String> warnings;

  const CsvImportResult({
    required this.sourceApp,
    required this.totalRows,
    required this.workoutsImported,
    required this.exercisesMatched,
    required this.customExercisesCreated,
    required this.setsImported,
    this.warnings = const [],
  });
}

class CsvImportService {
  final AppDatabase _db;
  final _uuid = const Uuid();

  CsvImportService(this._db);

  /// Robust RFC-4180 CSV parser handling embedded newlines, quotes, commas, and BOM.
  static List<List<String>> parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var inQuotes = false;

    // Strip UTF-8 BOM if present
    final clean = text.startsWith('\uFEFF') ? text.substring(1) : text;

    for (int i = 0; i < clean.length; i++) {
      final c = clean[i];

      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < clean.length && clean[i + 1] == '"') {
            field.write('"');
            i++; // skip escaped quote
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          row.add(field.toString().trim());
          field.clear();
        } else if (c == '\n' || c == '\r') {
          if (c == '\r' && i + 1 < clean.length && clean[i + 1] == '\n') {
            i++;
          }
          row.add(field.toString().trim());
          field.clear();
          if (row.any((cell) => cell.isNotEmpty)) {
            rows.add(row);
          }
          row = <String>[];
        } else {
          field.write(c);
        }
      }
    }

    row.add(field.toString().trim());
    if (row.any((cell) => cell.isNotEmpty)) {
      rows.add(row);
    }

    return rows;
  }

  /// Automatically identifies the source application based on CSV headers
  static String detectSource(List<String> headerRow) {
    final h = headerRow.map((c) => _normalizeHeader(c)).toList();

    if (h.any((c) => c.contains('exercise title')) && h.any((c) => c.contains('set index') || c.contains('weight kg'))) {
      return 'Hevy';
    }
    if (h.any((c) => c.contains('exercise name')) && h.any((c) => c.contains('set order'))) {
      return 'Strong';
    }
    if (h.any((c) => c == 'exercise') && h.any((c) => c == 'kind')) {
      return 'FitNotes (iOS)';
    }
    if (h.any((c) => c == 'exercise') && h.any((c) => c.contains('category') || c.contains('weight unit'))) {
      return 'FitNotes';
    }
    if (h.any((c) => c.contains('exercise')) && h.any((c) => c.contains('reps') || c.contains('weight'))) {
      return 'Generic Workout CSV';
    }
    return 'Custom CSV';
  }

  static String _normalizeHeader(String header) {
    return header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static String normalizeExerciseName(String raw) {
    var s = raw.trim();
    // Strip common bracketed equipment tags: "Bench Press (Barbell)" -> "Bench Press"
    s = s.replaceAll(RegExp(r'\s*\((?:barbell|dumbbell|cable|machine|smith machine|bodyweight|pulley|leverage|band|plate loaded|selectorized)\)', caseSensitive: false), '');
    return s.trim();
  }

  /// Automatically infers the targeted muscle group from exercise title cues
  static String inferMuscleGroup(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('squat') || lower.contains('leg') || lower.contains('lunge') ||
        lower.contains('calf') || lower.contains('calves') || lower.contains('hamstring') ||
        lower.contains('quad') || lower.contains('hack') || lower.contains('thigh')) {
      return 'legs';
    }
    if (lower.contains('deadlift') || lower.contains('row') || lower.contains('lat') ||
        lower.contains('pull-up') || lower.contains('pull up') || lower.contains('chin-up') ||
        lower.contains('chin up') || lower.contains('pulldown') || lower.contains('back')) {
      return 'back';
    }
    if (lower.contains('bench') || lower.contains('chest') || lower.contains('push-up') ||
        lower.contains('push up') || lower.contains('dip') || lower.contains('pec') ||
        lower.contains('fly') || lower.contains('flye')) {
      return 'chest';
    }
    if (lower.contains('shoulder') || lower.contains('overhead') || lower.contains('press') ||
        lower.contains('delt') || lower.contains('raise') || lower.contains('military')) {
      return 'shoulders';
    }
    if (lower.contains('bicep') || lower.contains('curl')) {
      return 'biceps';
    }
    if (lower.contains('tricep') || lower.contains('skull') || lower.contains('pushdown') ||
        lower.contains('extension')) {
      return 'triceps';
    }
    if (lower.contains('glute') || lower.contains('hip') || lower.contains('thrust') ||
        lower.contains('kickback') || lower.contains('abductor') || lower.contains('adductor')) {
      return 'glutes';
    }
    if (lower.contains('ab') || lower.contains('core') || lower.contains('crunch') ||
        lower.contains('plank') || lower.contains('twist') || lower.contains('sit-up') ||
        lower.contains('sit up')) {
      return 'core';
    }
    if (lower.contains('run') || lower.contains('walk') || lower.contains('bike') ||
        lower.contains('rower') || lower.contains('cardio') || lower.contains('jump') ||
        lower.contains('elliptical') || lower.contains('treadmill')) {
      return 'cardio';
    }
    if (lower.contains('wrist') || lower.contains('forearm') || lower.contains('grip')) {
      return 'forearms';
    }
    return 'chest';
  }

  /// Automatically infers equipment, loadMode, and weightStep from exercise title cues
  static (String equipment, String loadMode, double weightStep) inferEquipment(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('dumbbell') || lower.contains('db ')) {
      return ('dumbbell', 'per_hand', 2.5);
    }
    if (lower.contains('cable') || lower.contains('pulley')) {
      return ('cable', 'total', 2.5);
    }
    if (lower.contains('machine') || lower.contains('smith') || lower.contains('selectorized')) {
      return ('machine', 'total', 5.0);
    }
    if (lower.contains('bodyweight') || lower.contains('assisted') ||
        lower.contains('pull-up') || lower.contains('pull up') ||
        lower.contains('dip') || lower.contains('push-up') || lower.contains('push up')) {
      if (lower.contains('assisted')) {
        return ('assisted', 'assisted', 5.0);
      }
      return ('bodyweight', 'bodyweight', 0.0);
    }
    return ('barbell', 'total', 2.5);
  }

  /// Executes full import of the given CSV string into SQLite within a transaction
  Future<CsvImportResult> importCsv(String csvContent) async {
    final parsed = parseCsv(csvContent);
    if (parsed.isEmpty) {
      throw const FormatException('The provided CSV file is empty.');
    }

    final headers = parsed.first;
    final sourceApp = detectSource(headers);
    final colMap = _buildColumnMap(headers);

    if (!colMap.containsKey('exercise') || !colMap.containsKey('date')) {
      throw const FormatException('Missing required columns: CSV must contain at least an exercise column and a date column.');
    }

    // Ensure the comprehensive 1,300+ exercise library is present in SQLite for high match rate
    var existingExercises = await _db.select(_db.exercises).get();
    if (existingExercises.length < 500) {
      await ExerciseRepository(_db).seedOpenGymCatalog();
      existingExercises = await _db.select(_db.exercises).get();
    }

    final exerciseMap = <String, ExerciseData>{};
    for (final ex in existingExercises) {
      final n1 = ex.name.toLowerCase().trim();
      final n2 = normalizeExerciseName(ex.name).toLowerCase();
      final n3 = n1.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ');
      final n4 = n2.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ');
      exerciseMap[n1] = ex;
      exerciseMap[n2] = ex;
      exerciseMap[n3] = ex;
      exerciseMap[n4] = ex;
      if (n1.endsWith('s')) exerciseMap[n1.substring(0, n1.length - 1)] = ex;
      if (n2.endsWith('s')) exerciseMap[n2.substring(0, n2.length - 1)] = ex;
    }

    // Parse data rows
    int matchedCount = 0;
    int customCount = 0;
    int setsCount = 0;
    final warnings = <String>[];

    // Grouping: Map<WorkoutKey, List<_ImportedSetRow>>
    final workoutGroups = <String, List<_ImportedSetRow>>{};

    for (int i = 1; i < parsed.length; i++) {
      final row = parsed[i];
      if (row.isEmpty || row.every((c) => c.isEmpty)) continue;

      final rawExName = _getField(row, colMap['exercise']);
      if (rawExName.isEmpty) continue;

      final rawDate = _getField(row, colMap['date']);
      final parsedDate = _parseDate(rawDate) ?? DateTime.now();
      final workoutDate = AppDateUtils.normalizeDate(parsedDate);

      final workoutTitle = _getField(row, colMap['workoutName']).isNotEmpty
          ? _getField(row, colMap['workoutName'])
          : 'Workout on ${AppDateUtils.formatShortDate(workoutDate)}';

      final weightRaw = _getField(row, colMap['weightKg']).isNotEmpty
          ? _getField(row, colMap['weightKg'])
          : _getField(row, colMap['weightLb']).isNotEmpty
              ? _getField(row, colMap['weightLb'])
              : _getField(row, colMap['weight']);

      final isLb = _getField(row, colMap['weightLb']).isNotEmpty ||
          _getField(row, colMap['weightUnit']).toLowerCase().contains('lb');

      double weight = double.tryParse(weightRaw.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      if (isLb && weight > 0) {
        weight = UnitConverter.toKg(weight, WeightUnit.lb);
      }

      final reps = int.tryParse(_getField(row, colMap['reps']).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final rpe = double.tryParse(_getField(row, colMap['rpe']).replaceAll(RegExp(r'[^0-9.]'), ''));
      final rawSetType = _getField(row, colMap['setType']).toLowerCase();

      SetType setType = SetType.working;
      if (rawSetType.contains('warm') || rawSetType == 'w') {
        setType = SetType.warmup;
      } else if (rawSetType.contains('drop') || rawSetType == 'd') {
        setType = SetType.drop;
      } else if (rawSetType.contains('fail') || rawSetType == 'f') {
        setType = SetType.failure;
      }

      final note = _getField(row, colMap['note']);

      // Unique workout key
      final workoutKey = '${workoutDate.toIso8601String()}_$workoutTitle';

      workoutGroups.putIfAbsent(workoutKey, () => []).add(
            _ImportedSetRow(
              date: workoutDate,
              workoutTitle: workoutTitle,
              rawExerciseName: rawExName,
              weight: weight,
              reps: reps,
              rpe: rpe,
              setType: setType,
              note: note,
            ),
          );
    }

    // Perform database insertion in a single transaction
    await _db.transaction(() async {
      for (final entry in workoutGroups.entries) {
        final rows = entry.value;
        if (rows.isEmpty) continue;

        final firstRow = rows.first;
        final workoutId = _uuid.v4();

        // 1. Create Workout
        await _db.into(_db.workouts).insert(
              WorkoutsCompanion.insert(
                id: workoutId,
                date: firstRow.date,
                title: firstRow.workoutTitle,
                startedAt: drift.Value(firstRow.date.add(const Duration(hours: 9))),
                endedAt: drift.Value(firstRow.date.add(const Duration(hours: 10, minutes: 15))),
                archived: const drift.Value(false),
              ),
            );

        // Group sets by exercise inside this workout
        final exerciseGroups = <String, List<_ImportedSetRow>>{};
        for (final r in rows) {
          exerciseGroups.putIfAbsent(r.rawExerciseName, () => []).add(r);
        }

        int exPosition = 0;
        for (final exEntry in exerciseGroups.entries) {
          final rawName = exEntry.key;
          final setRows = exEntry.value;
          final cleanName = normalizeExerciseName(rawName);

          final cleanLower = cleanName.toLowerCase();
          final noHyphen = cleanLower.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ');
          final noTrailingS = noHyphen.endsWith('s') ? noHyphen.substring(0, noHyphen.length - 1) : noHyphen;

          // Find or create Exercise
          ExerciseData? exData = exerciseMap[rawName.toLowerCase()] ??
              exerciseMap[cleanLower] ??
              exerciseMap[noHyphen] ??
              exerciseMap[noTrailingS];

          if (exData == null) {
            // Fuzzy search among existing
            for (final k in exerciseMap.keys) {
              if (k.length >= 4 && (cleanLower.contains(k) || k.contains(cleanLower) || noHyphen.contains(k) || k.contains(noHyphen))) {
                exData = exerciseMap[k];
                break;
              }
            }
          }

          String exId;
          String muscleGroupId;

          if (exData != null) {
            exId = exData.id;
            muscleGroupId = exData.muscleGroupId;
            matchedCount++;
          } else {
            // Create a smart custom exercise for unmapped lifts using biomechanical inference
            exId = _uuid.v4();
            muscleGroupId = inferMuscleGroup(cleanName);
            final (inferredEq, inferredLm, inferredStep) = inferEquipment(cleanName);

            final newCustom = ExercisesCompanion.insert(
              id: exId,
              name: cleanName.isNotEmpty ? cleanName : rawName,
              muscleGroupId: muscleGroupId,
              equipment: inferredEq,
              loadMode: drift.Value(inferredLm),
              weightStep: drift.Value(inferredStep),
              isCustom: const drift.Value(true),
              archived: const drift.Value(false),
            );
            await _db.into(_db.exercises).insert(newCustom);
            customCount++;
            exerciseMap[rawName.toLowerCase()] = ExerciseData(
              id: exId,
              name: cleanName,
              muscleGroupId: muscleGroupId,
              equipment: inferredEq,
              secondaryGroups: '',
              loadMode: inferredLm,
              isUnilateral: false,
              weightStep: inferredStep,
              repMin: 8,
              repMax: 12,
              restSeconds: 90,
              isCustom: true,
              archived: false,
            );
          }

          // 2. Create WorkoutExercise
          final weId = _uuid.v4();
          await _db.into(_db.workoutExercises).insert(
                WorkoutExercisesCompanion.insert(
                  id: weId,
                  workoutId: workoutId,
                  exerciseId: exId,
                  position: exPosition++,
                  archived: const drift.Value(false),
                ),
              );

          // 3. Create Sets
          int setIdx = 1;
          for (final s in setRows) {
            final setId = _uuid.v4();
            await _db.into(_db.sets).insert(
                  SetsCompanion.insert(
                    id: setId,
                    workoutExerciseId: weId,
                    exerciseId: exId,
                    muscleGroupId: muscleGroupId,
                    date: s.date,
                    setIndex: setIdx++,
                    weight: s.weight,
                    reps: s.reps,
                    setType: s.setType.name,
                    rpe: drift.Value(s.rpe),
                    completedAt: s.date.add(Duration(minutes: setIdx * 3)),
                    archived: const drift.Value(false),
                  ),
                );
            setsCount++;
          }
        }
      }
    });

    return CsvImportResult(
      sourceApp: sourceApp,
      totalRows: parsed.length - 1,
      workoutsImported: workoutGroups.length,
      exercisesMatched: matchedCount,
      customExercisesCreated: customCount,
      setsImported: setsCount,
      warnings: warnings,
    );
  }

  static String _getField(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  static Map<String, int> _buildColumnMap(List<String> headers) {
    final normHeaders = headers.map(_normalizeHeader).toList();
    final map = <String, int>{};

    final aliasDefinitions = <String, List<String>>{
      'exercise': ['exercise', 'exercise name', 'exercise title', 'exercise_title', 'lift'],
      'date': ['date', 'workout date', 'workout_date', 'start time', 'start_time', 'start date'],
      'workoutName': ['workout name', 'workout_name', 'title', 'routine', 'workout'],
      'weightKg': ['weight kg', 'weight_kg'],
      'weightLb': ['weight lbs', 'weight lb', 'weight_lbs'],
      'weight': ['weight', 'load'],
      'weightUnit': ['weight unit', 'weight_unit', 'unit'],
      'reps': ['reps', 'repetitions', 'rep'],
      'rpe': ['rpe', 'rpe rating', 'effort'],
      'setType': ['set type', 'set_type', 'kind'],
      'note': ['comment', 'comments', 'notes', 'note', 'exercise_notes', 'description'],
    };

    for (final entry in aliasDefinitions.entries) {
      final fieldKey = entry.key;
      final aliases = entry.value;

      for (int i = 0; i < normHeaders.length; i++) {
        final h = normHeaders[i];
        if (aliases.contains(h) && !map.containsKey(fieldKey)) {
          map[fieldKey] = i;
          break;
        }
      }
    }

    return map;
  }

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      // 1. Direct ISO 8601
      final iso = DateTime.tryParse(raw);
      if (iso != null) return iso;

      // 2. YYYY-MM-DD or YYYY/MM/DD
      final ymMatch = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(raw);
      if (ymMatch != null) {
        final y = int.parse(ymMatch.group(1)!);
        final m = int.parse(ymMatch.group(2)!);
        final d = int.parse(ymMatch.group(3)!);
        return DateTime(y, m, d);
      }

      // 3. DD/MM/YYYY or MM/DD/YYYY
      final dmMatch = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(raw);
      if (dmMatch != null) {
        final a = int.parse(dmMatch.group(1)!);
        final b = int.parse(dmMatch.group(2)!);
        final y = int.parse(dmMatch.group(3)!);
        // If a > 12, a is day
        if (a > 12) {
          return DateTime(y, b, a);
        }
        return DateTime(y, a, b);
      }
    } catch (_) {}
    return null;
  }
}

class _ImportedSetRow {
  final DateTime date;
  final String workoutTitle;
  final String rawExerciseName;
  final double weight;
  final int reps;
  final double? rpe;
  final SetType setType;
  final String note;

  const _ImportedSetRow({
    required this.date,
    required this.workoutTitle,
    required this.rawExerciseName,
    required this.weight,
    required this.reps,
    this.rpe,
    required this.setType,
    this.note = '',
  });
}
