import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../data/database/database.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/repositories/routine_repository.dart';
import '../models/routine_model.dart';
import '../services/csv_import_service.dart';

class PlanShareService {
  static const int currentFormatVersion = 1;
  static final _uuid = const Uuid();

  /// Serializes a routine into a compact, standardized JSON payload for QR codes or instant sharing
  static String exportRoutineToPayload(RoutineModel routine, {bool isLb = false}) {
    final Map<String, dynamic> data = {
      'ironlog_plan': currentFormatVersion,
      'title': routine.name,
      'description': routine.description,
      'unit': isLb ? 'lb' : 'kg',
      'exercises': routine.items.map((item) {
        return {
          'name': item.exercise.name,
          'muscle': item.exercise.muscleGroupId,
          'equipment': item.exercise.equipment.name,
          'sets': item.targetSets,
          'repMin': item.repMin,
          'repMax': item.repMax,
          'rest': item.restSeconds,
        };
      }).toList(),
    };

    return jsonEncode(data);
  }

  /// Parses a QR payload or JSON string and imports the routine into SQLite without overwriting existing data
  static Future<RoutineModel> importRoutineFromPayload(
    String payload,
    AppDatabase db,
  ) async {
    final Map<String, dynamic> data = jsonDecode(payload.trim());

    if (!data.containsKey('ironlog_plan') && !data.containsKey('title')) {
      throw const FormatException('Invalid routine format: Missing required IronLog plan headers.');
    }

    final title = data['title'] as String? ?? 'Imported Routine';
    final description = data['description'] as String? ?? '';
    final rawExercises = data['exercises'] as List<dynamic>? ?? [];

    if (rawExercises.isEmpty) {
      throw const FormatException('Routine contains no exercises.');
    }

    final exerciseRepo = ExerciseRepository(db);
    final allDbExercises = await exerciseRepo.getExercises();

    // Map for fast lookup
    final Map<String, String> nameToId = {};
    for (final ex in allDbExercises) {
      nameToId[ex.name.toLowerCase().trim()] = ex.id;
      final clean = CsvImportService.normalizeExerciseName(ex.name).toLowerCase();
      nameToId[clean] = ex.id;
    }

    final newRoutineId = _uuid.v4();

    // Create routine and items inside an atomic transaction
    await db.transaction(() async {
      await db.into(db.routines).insert(
            RoutinesCompanion.insert(
              id: newRoutineId,
              name: title,
              description: drift.Value(description),
              archived: const drift.Value(false),
            ),
          );

      int position = 0;
      for (final raw in rawExercises) {
        final itemMap = raw as Map<String, dynamic>;
        final exName = (itemMap['name'] as String? ?? '').trim();
        if (exName.isEmpty) continue;

        String? exId = nameToId[exName.toLowerCase()];
        if (exId == null) {
          final clean = CsvImportService.normalizeExerciseName(exName).toLowerCase();
          exId = nameToId[clean];
        }

        // If exercise does not exist in DB, create it with smart inference
        if (exId == null) {
          exId = _uuid.v4();
          final muscle = itemMap['muscle'] as String? ?? CsvImportService.inferMuscleGroup(exName);
          final (eq, lm, step) = CsvImportService.inferEquipment(exName);

          await db.into(db.exercises).insert(
                ExercisesCompanion.insert(
                  id: exId,
                  name: exName,
                  muscleGroupId: muscle,
                  equipment: eq,
                  loadMode: drift.Value(lm),
                  weightStep: drift.Value(step),
                  isCustom: const drift.Value(true),
                  archived: const drift.Value(false),
                ),
                mode: drift.InsertMode.insertOrIgnore,
              );
          nameToId[exName.toLowerCase()] = exId;
        }

        final targetSets = (itemMap['sets'] as num?)?.toInt() ?? 3;
        final repMin = (itemMap['repMin'] as num?)?.toInt() ?? 8;
        final repMax = (itemMap['repMax'] as num?)?.toInt() ?? 12;
        final rest = (itemMap['rest'] as num?)?.toInt() ?? 90;

        await db.into(db.routineItems).insert(
              RoutineItemsCompanion.insert(
                id: _uuid.v4(),
                routineId: newRoutineId,
                exerciseId: exId,
                position: position++,
                targetSets: drift.Value(targetSets),
                repMin: drift.Value(repMin),
                repMax: drift.Value(repMax),
                restSeconds: drift.Value(rest),
              ),
            );
      }
    });

    final routineRepo = RoutineRepository(db);
    final allRoutines = await routineRepo.getRoutines();
    return allRoutines.firstWhere((r) => r.id == newRoutineId);
  }
}
