import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/database/database.dart';

class SampleTimelineService {
  SampleTimelineService._();

  /// Generates a realistic 90-day progressive overload journey with 48 workouts,
  /// 200+ sets, and milestone PR records.
  static Map<String, dynamic> generate90DaySampleJourneyData() {
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);
    final startDate = todayNormalized.subtract(const Duration(days: 88));

    final workouts = <Map<String, dynamic>>[];
    final workoutExercises = <Map<String, dynamic>>[];
    final sets = <Map<String, dynamic>>[];
    final prs = <Map<String, dynamic>>[];

    // Track personal records to insert PR milestones
    double maxBench = 0;
    double maxSquat = 0;
    double maxDeadlift = 0;

    int workoutCounter = 1;

    // 12 weeks, 4 days per week (Mon, Tue, Thu, Fri pattern)
    for (int week = 0; week < 13; week++) {
      final weekStart = startDate.add(Duration(days: week * 7));
      if (weekStart.isAfter(todayNormalized)) break;

      // Overload multiplier across 12 weeks: 1.0 -> 1.45
      final overload = 1.0 + (week * 0.038);

      final daysInWeek = [
        {'offset': 0, 'type': 'push', 'title': 'Push Day • Chest & Delts Focus'},
        {'offset': 1, 'type': 'pull', 'title': 'Pull Day • Back & Biceps Hypertrophy'},
        {'offset': 3, 'type': 'legs', 'title': 'Leg Day • Quad & Hamstring Power'},
        {'offset': 4, 'type': 'upper', 'title': 'Upper Body • Progressive Overload'},
      ];

      for (final session in daysInWeek) {
        final sessionDate = weekStart.add(Duration(days: session['offset'] as int));
        if (sessionDate.isAfter(todayNormalized)) continue;

        final workoutId = 'sample_wo_${week}_${session['type']}';
        final sessionType = session['type'] as String;
        final startHour = 17 + (session['offset'] as int) % 3;
        final startedAt = DateTime(sessionDate.year, sessionDate.month, sessionDate.day, startHour, 15);
        final durationMinutes = 55 + (week % 4) * 5;
        final endedAt = startedAt.add(Duration(minutes: durationMinutes));

        int feel = 4;
        if (week == 6 || week == 11) feel = 5; // PR weeks feel amazing!
        if (week == 4) feel = 3; // fatigue week

        workouts.add({
          'id': workoutId,
          'title': session['title'],
          'date': sessionDate.toIso8601String(),
          'started_at': startedAt.toIso8601String(),
          'ended_at': endedAt.toIso8601String(),
          'feel': feel,
          'note': 'Week ${week + 1} #$workoutCounter • Focused intensity and tempo.',
          'archived': false,
        });

        int position = 0;

        void addExerciseWithSets({
          required String exerciseId,
          required String muscleGroupId,
          required List<Map<String, dynamic>> setDefinitions,
        }) {
          final weId = 'sample_we_${workoutId}_$position';
          workoutExercises.add({
            'id': weId,
            'workout_id': workoutId,
            'exercise_id': exerciseId,
            'position': position,
            'archived': false,
          });

          for (int sIdx = 0; sIdx < setDefinitions.length; sIdx++) {
            final def = setDefinitions[sIdx];
            final weight = ((def['weight'] as num) * 10).round() / 10.0;
            final reps = def['reps'] as int;
            final isWarmup = def['is_warmup'] == true;
            final setId = 'sample_set_${weId}_$sIdx';

            sets.add({
              'id': setId,
              'workout_exercise_id': weId,
              'exercise_id': exerciseId,
              'muscle_group_id': muscleGroupId,
              'date': sessionDate.toIso8601String(),
              'set_index': sIdx,
              'weight': weight,
              'reps': reps,
              'set_type': isWarmup ? 'warmup' : 'working',
              'completed_at': startedAt.add(Duration(minutes: 6 * position + 2 * sIdx)).toIso8601String(),
              'archived': false,
            });

            // Check PRs on working sets
            if (!isWarmup && weight > 0 && reps > 0) {
              if (exerciseId == 'ex_c_01' && weight > maxBench) {
                maxBench = weight;
                prs.add({
                  'id': 'sample_pr_${prs.length + 1}',
                  'exercise_id': 'ex_c_01',
                  'kind': 'heaviest',
                  'value': weight,
                  'set_id': setId,
                  'achieved_at': sessionDate.toIso8601String(),
                });
              } else if (exerciseId == 'ex_l_01' && weight > maxSquat) {
                maxSquat = weight;
                prs.add({
                  'id': 'sample_pr_${prs.length + 1}',
                  'exercise_id': 'ex_l_01',
                  'kind': 'heaviest',
                  'value': weight,
                  'set_id': setId,
                  'achieved_at': sessionDate.toIso8601String(),
                });
              } else if (exerciseId == 'ex_b_01' && weight > maxDeadlift) {
                maxDeadlift = weight;
                prs.add({
                  'id': 'sample_pr_${prs.length + 1}',
                  'exercise_id': 'ex_b_01',
                  'kind': 'heaviest',
                  'value': weight,
                  'set_id': setId,
                  'achieved_at': sessionDate.toIso8601String(),
                });
              }
            }
          }
          position++;
        }

        // Populate session exercises
        if (sessionType == 'push') {
          final benchW = (60.0 * overload / 2.5).round() * 2.5;
          final dbW = (20.0 * overload / 2.0).round() * 2.0;

          addExerciseWithSets(
            exerciseId: 'ex_c_01',
            muscleGroupId: 'chest',
            setDefinitions: [
              {'weight': benchW * 0.6, 'reps': 10, 'is_warmup': true},
              {'weight': benchW, 'reps': 8},
              {'weight': benchW, 'reps': 8},
              {'weight': benchW + 2.5, 'reps': 6},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_c_05',
            muscleGroupId: 'chest',
            setDefinitions: [
              {'weight': dbW, 'reps': 10},
              {'weight': dbW, 'reps': 10},
              {'weight': dbW + 2.0, 'reps': 8},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_c_15',
            muscleGroupId: 'chest',
            setDefinitions: [
              {'weight': 0.0, 'reps': 18 + week},
              {'weight': 0.0, 'reps': 15 + week},
              {'weight': 0.0, 'reps': 15 + week},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_tr_07',
            muscleGroupId: 'triceps',
            setDefinitions: [
              {'weight': 20.0 * overload, 'reps': 12},
              {'weight': 22.5 * overload, 'reps': 10},
              {'weight': 22.5 * overload, 'reps': 10},
            ],
          );
        } else if (sessionType == 'pull') {
          final deadliftW = (90.0 * overload / 5.0).round() * 5.0;
          final rowW = (50.0 * overload / 2.5).round() * 2.5;

          addExerciseWithSets(
            exerciseId: 'ex_b_01',
            muscleGroupId: 'back',
            setDefinitions: [
              {'weight': deadliftW * 0.6, 'reps': 8, 'is_warmup': true},
              {'weight': deadliftW, 'reps': 5},
              {'weight': deadliftW, 'reps': 5},
              {'weight': deadliftW + 5.0, 'reps': 4},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_b_02',
            muscleGroupId: 'back',
            setDefinitions: [
              {'weight': rowW, 'reps': 8},
              {'weight': rowW, 'reps': 8},
              {'weight': rowW + 2.5, 'reps': 7},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_b_11',
            muscleGroupId: 'back',
            setDefinitions: [
              {'weight': 0.0, 'reps': 8 + (week ~/ 2)},
              {'weight': 0.0, 'reps': 7 + (week ~/ 2)},
              {'weight': 0.0, 'reps': 6 + (week ~/ 2)},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_bi_01',
            muscleGroupId: 'biceps',
            setDefinitions: [
              {'weight': 25.0 * overload, 'reps': 10},
              {'weight': 27.5 * overload, 'reps': 8},
              {'weight': 27.5 * overload, 'reps': 8},
            ],
          );
        } else if (sessionType == 'legs') {
          final squatW = (70.0 * overload / 5.0).round() * 5.0;
          final rdlW = (60.0 * overload / 5.0).round() * 5.0;

          addExerciseWithSets(
            exerciseId: 'ex_l_01',
            muscleGroupId: 'legs',
            setDefinitions: [
              {'weight': squatW * 0.6, 'reps': 10, 'is_warmup': true},
              {'weight': squatW, 'reps': 8},
              {'weight': squatW, 'reps': 8},
              {'weight': squatW + 5.0, 'reps': 6},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_l_05',
            muscleGroupId: 'legs',
            setDefinitions: [
              {'weight': rdlW, 'reps': 10},
              {'weight': rdlW, 'reps': 10},
              {'weight': rdlW + 5.0, 'reps': 8},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_c_24',
            muscleGroupId: 'chest',
            setDefinitions: [
              {'weight': 0.0, 'reps': 16 + week},
              {'weight': 0.0, 'reps': 16 + week},
            ],
          );
        } else {
          // Upper body day
          final benchW = (62.5 * overload / 2.5).round() * 2.5;
          final pullW = 35.0 * overload;

          addExerciseWithSets(
            exerciseId: 'ex_c_01',
            muscleGroupId: 'chest',
            setDefinitions: [
              {'weight': benchW, 'reps': 8},
              {'weight': benchW, 'reps': 8},
              {'weight': benchW + 2.5, 'reps': 6},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_b_04',
            muscleGroupId: 'back',
            setDefinitions: [
              {'weight': pullW, 'reps': 10},
              {'weight': pullW, 'reps': 10},
              {'weight': pullW + 5.0, 'reps': 8},
            ],
          );
          addExerciseWithSets(
            exerciseId: 'ex_c_21', // Incline pushups
            muscleGroupId: 'chest',
            setDefinitions: [
              {'weight': 0.0, 'reps': 20 + week},
              {'weight': 0.0, 'reps': 20 + week},
            ],
          );
        }

        workoutCounter++;
      }
    }

    return {
      'format': 'ironlog_growth_timeline_sample_v1',
      'generated_at': DateTime.now().toIso8601String(),
      'description': '90-Day Progressive Overload Journey with PR Milestones and Bodyweight Exercises',
      'workouts_count': workouts.length,
      'sets_count': sets.length,
      'prs_count': prs.length,
      'workouts': workouts,
      'workout_exercises': workoutExercises,
      'sets': sets,
      'prs': prs,
    };
  }

  /// Imports the generated 90-day progressive journey directly into SQLite database
  static Future<int> importSampleJourney(AppDatabase db) async {
    final data = generate90DaySampleJourneyData();
    return importJourneyFromMap(db, data);
  }

  /// Imports from JSON map data into database
  static Future<int> importJourneyFromMap(AppDatabase db, Map<String, dynamic> data) async {
    final workoutsList = (data['workouts'] as List?) ?? [];
    final weList = (data['workout_exercises'] as List?) ?? [];
    final setsList = (data['sets'] as List?) ?? [];
    final prsList = (data['prs'] as List?) ?? [];

    await db.transaction(() async {
      // 1. Workouts
      for (final w in workoutsList) {
        await db.into(db.workouts).insertOnConflictUpdate(
          WorkoutsCompanion.insert(
            id: w['id'],
            title: w['title'] ?? 'Workout',
            date: DateTime.parse(w['date']),
            startedAt: Value(w['started_at'] != null ? DateTime.parse(w['started_at']) : null),
            endedAt: Value(w['ended_at'] != null ? DateTime.parse(w['ended_at']) : null),
            feel: Value(w['feel']),
            note: Value(w['note']),
            archived: Value(w['archived'] ?? false),
          ),
        );
      }

      // 2. Workout Exercises
      for (final we in weList) {
        await db.into(db.workoutExercises).insertOnConflictUpdate(
          WorkoutExercisesCompanion.insert(
            id: we['id'],
            workoutId: we['workout_id'],
            exerciseId: we['exercise_id'],
            position: we['position'] ?? 0,
            note: Value(we['note']),
            supersetGroup: Value(we['superset_group']),
            archived: Value(we['archived'] ?? false),
          ),
        );
      }

      // 3. Sets
      for (final s in setsList) {
        await db.into(db.sets).insertOnConflictUpdate(
          SetsCompanion.insert(
            id: s['id'],
            workoutExerciseId: s['workout_exercise_id'],
            exerciseId: s['exercise_id'],
            muscleGroupId: s['muscle_group_id'],
            date: DateTime.parse(s['date']),
            setIndex: s['set_index'] ?? 0,
            weight: (s['weight'] as num).toDouble(),
            reps: s['reps'] ?? 0,
            setType: s['set_type'] ?? 'working',
            completedAt: DateTime.parse(s['completed_at'] ?? s['date']),
            archived: Value(s['archived'] ?? false),
          ),
        );
      }

      // 4. PRs
      for (final p in prsList) {
        await db.into(db.prs).insertOnConflictUpdate(
          PrsCompanion.insert(
            id: p['id'],
            exerciseId: p['exercise_id'],
            kind: p['kind'] ?? 'heaviest',
            value: (p['value'] as num).toDouble(),
            setId: Value(p['set_id']),
            achievedAt: DateTime.parse(p['achieved_at']),
          ),
        );
      }
    });

    return workoutsList.length;
  }

  /// Exports sample JSON file to application documents directory
  static Future<File> exportSampleFileToDisk() async {
    final data = generate90DaySampleJourneyData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = Directory.current;
    }

    final file = File('${dir.path}/sample_growth_timeline_90days.json');
    await file.writeAsString(jsonStr);
    return file;
  }

  /// Parses JSON string and imports into SQLite
  static Future<int> importJourneyFromJson(AppDatabase db, String jsonString) async {
    final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
    return importJourneyFromMap(db, data);
  }
}
