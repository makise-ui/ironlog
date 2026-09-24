import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../data/providers.dart';
import '../../domain/models/set_model.dart';
import '../../domain/models/workout_model.dart';
import '../../domain/models/exercise_model.dart';
import '../../domain/services/pr_detector.dart';
import '../../domain/services/backup_service.dart';
import '../../domain/services/e1rm_calculator.dart';
import '../../domain/services/weight_step_learner.dart';
import '../../domain/models/routine_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/unit_converter.dart';
import '../models/ai_chat_message.dart';

class AiToolService {
  final Ref _ref;

  AiToolService(this._ref);

  static List<Map<String, dynamic>> get openAiToolDefinitions => [
        {
          'type': 'function',
          'function': {
            'name': 'get_today_workout',
            'description': 'Retrieve real-time details of today\'s workout session (or any specific date), including all exercises added, completed sets with weights and reps, total volume, and duration.',
            'parameters': {
              'type': 'object',
              'properties': {
                'date': {
                  'type': 'string',
                  'description': 'Optional date to inspect (e.g. "today", "yesterday", or "2026-09-23"). Defaults to "today" if omitted.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'query_workout_history',
            'description': 'Search and inspect historical workout sessions across the entire training history. Filter by muscle group (e.g. "glutes", "chest", "back", "legs", "shoulders", "biceps", "triceps", "core"), exercise name, or retrieve recent sessions. Returns compact session summaries safe for long-term gym histories (handles 1+ year data without context overflow).',
            'parameters': {
              'type': 'object',
              'properties': {
                'muscleGroup': {
                  'type': 'string',
                  'description': 'Optional muscle group to search for (e.g. "glutes", "chest", "back", "legs", "shoulders", "biceps", "triceps", "core", "cardio").',
                },
                'exerciseName': {
                  'type': 'string',
                  'description': 'Optional exercise name to filter sessions by (e.g. "Hip Thrust", "Squat", "Cable Kickbacks").',
                },
                'limit': {
                  'type': 'integer',
                  'description': 'Max number of sessions to return (default: 10, max: 25).',
                },
                'offset': {
                  'type': 'integer',
                  'description': 'Pagination offset (default: 0).',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'search_web',
            'description': 'Search the web for scientific workout advice, exercise technique cues, hypertrophy research, injury prevention, or nutrition guidelines.',
            'parameters': {
              'type': 'object',
              'properties': {
                'query': {
                  'type': 'string',
                  'description': 'The search query to look up on the web.',
                },
              },
              'required': ['query'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'log_set',
            'description': 'Log a completed set into the workout session (today or a past date). Automatically creates the exercise if not found in catalog.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise or sport/game (e.g., Bench Press, Squat, Lat Pulldown, Football, Basketball).',
                },
                'weight': {
                  'type': 'number',
                  'description': 'Weight used for the set in the current unit (kg or lbs).',
                },
                'reps': {
                  'type': 'integer',
                  'description': 'Number of repetitions completed.',
                },
                'setType': {
                  'type': 'string',
                  'enum': ['working', 'warmup', 'drop', 'failure'],
                  'description': 'Type of set. Defaults to working.',
                },
                'date': {
                  'type': 'string',
                  'description': 'Date of the workout (e.g., "today", "yesterday", "2 days ago", or "2026-09-22"). Defaults to today if omitted.',
                },
              },
              'required': ['exerciseName', 'weight', 'reps'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'add_exercise',
            'description': 'Add an exercise to the active workout session. Automatically creates the exercise if not found in catalog.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise to add to the workout.',
                },
              },
              'required': ['exerciseName'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'create_custom_exercise',
            'description': 'Create a new custom exercise, sport, or game in the catalog if it does not already exist.',
            'parameters': {
              'type': 'object',
              'properties': {
                'name': {
                  'type': 'string',
                  'description': 'Name of the exercise, sport, or game (e.g., Football, Basketball, Incline Hammer Press, Boxing).',
                },
                'muscleGroup': {
                  'type': 'string',
                  'description': 'Primary muscle group or category: chest, back, shoulders, biceps, triceps, legs, glutes, core, forearms, cardio (use cardio for sports/games).',
                },
                'equipment': {
                  'type': 'string',
                  'description': 'Equipment type: barbell, dumbbell, cable, machine, bodyweight, or other.',
                },
              },
              'required': ['name'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'set_rest_day',
            'description': 'Mark or unmark a date as a Rest & Recovery Day (supports today, yesterday, or any past/target date like "2026-09-22").',
            'parameters': {
              'type': 'object',
              'properties': {
                'date': {
                  'type': 'string',
                  'description': 'Date to mark/unmark: "today", "yesterday", "2 days ago", or "YYYY-MM-DD". Defaults to today.',
                },
                'isRest': {
                  'type': 'boolean',
                  'description': 'True to mark as rest day, false to unmark (resume training). Defaults to true.',
                },
                'note': {
                  'type': 'string',
                  'description': 'Optional recovery note (e.g., "Deep tissue recovery", "Active walk & mobility").',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'start_workout',
            'description': 'Start a new workout session or resume a workout on today or a past date.',
            'parameters': {
              'type': 'object',
              'properties': {
                'title': {
                  'type': 'string',
                  'description': 'Title of the workout (e.g., Push Day, Leg Hypertrophy).',
                },
                'exerciseNames': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of exercise names to include in this session.',
                },
                'date': {
                  'type': 'string',
                  'description': 'Date of the workout (e.g., "today", "yesterday", "2026-09-22"). Defaults to today.',
                },
              },
              'required': ['title'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'finish_workout',
            'description': 'Finish and save the current active workout session.',
            'parameters': {
              'type': 'object',
              'properties': {},
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'create_routine',
            'description': 'Create and save a new routine preset template that the user can use anytime.',
            'parameters': {
              'type': 'object',
              'properties': {
                'name': {
                  'type': 'string',
                  'description': 'Routine name (e.g., 4-Day Push, Upper Body Power).',
                },
                'category': {
                  'type': 'string',
                  'description': 'Category of the routine (e.g., Push, Pull, Legs, Upper, Lower, Full Body).',
                },
                'exerciseNames': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'Complete, ordered list of ALL exercise names in this routine. Include every single exercise requested by the user without truncating or limiting.',
                },
              },
              'required': ['name', 'category', 'exerciseNames'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'start_rest_timer',
            'description': 'Start the countdown rest timer for the user between sets.',
            'parameters': {
              'type': 'object',
              'properties': {
                'seconds': {
                  'type': 'integer',
                  'description': 'Timer duration in seconds (e.g., 60, 90, 120, 180).',
                },
                'exerciseName': {
                  'type': 'string',
                  'description': 'Optional name of the exercise being rested from.',
                },
              },
              'required': ['seconds'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'recommend_weights',
            'description': 'Analyze user historical performance and provide progressive overload weight & rep recommendation for an exercise.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'The exercise to calculate progression for.',
                },
              },
              'required': ['exerciseName'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'query_prs_and_history',
            'description': 'Look up personal records (PRs), estimated 1-rep max, and past performance history from SQLite.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Optional exercise name to inspect. If omitted, returns recent PRs and workout summary.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'export_backup',
            'description': 'Export user workout data and database backup to phone storage.',
            'parameters': {
              'type': 'object',
              'properties': {},
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'edit_set',
            'description': 'Edit a previously logged set in the active workout session (change weight, reps, set type, or RPE).',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise (e.g. Bench Press). Defaults to the last logged exercise if omitted.',
                },
                'setIndex': {
                  'type': 'integer',
                  'description': '1-based index of the set to edit (e.g. 1 for first set, 2 for second). Defaults to the last set if omitted.',
                },
                'weight': {
                  'type': 'number',
                  'description': 'New weight value.',
                },
                'reps': {
                  'type': 'integer',
                  'description': 'New repetition count.',
                },
                'setType': {
                  'type': 'string',
                  'enum': ['working', 'warmup', 'drop', 'failure'],
                  'description': 'New set type.',
                },
                'rpe': {
                  'type': 'number',
                  'description': 'New RPE rating (e.g. 8.5).',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'delete_set',
            'description': 'Delete a set from the active workout session.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise whose set should be deleted. Defaults to the last exercise if omitted.',
                },
                'setIndex': {
                  'type': 'integer',
                  'description': '1-based index of the set to delete. Defaults to the last set if omitted.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'remove_exercise',
            'description': 'Remove an exercise and all its sets from the active workout session.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise to remove from the workout.',
                },
              },
              'required': ['exerciseName'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'edit_workout',
            'description': 'Edit active or today\'s workout details like title, notes, or rating/feeling (1 to 5).',
            'parameters': {
              'type': 'object',
              'properties': {
                'title': {
                  'type': 'string',
                  'description': 'New title for the workout session.',
                },
                'note': {
                  'type': 'string',
                  'description': 'Workout note or reflections.',
                },
                'feel': {
                  'type': 'integer',
                  'description': 'Rating / feeling score from 1 (poor) to 5 (great).',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'delete_workout',
            'description': 'Delete a logged workout from the database. Requires explicit user confirmation before executing deletion.',
            'parameters': {
              'type': 'object',
              'properties': {
                'workoutId': {
                  'type': 'string',
                  'description': 'ID of the workout to delete. If omitted, targets today\'s or active workout.',
                },
                'date': {
                  'type': 'string',
                  'description': 'Date of the workout (e.g. "today", "yesterday", "2026-09-23").',
                },
                'confirmed': {
                  'type': 'boolean',
                  'description': 'Must be true ONLY when user has explicitly granted permission to delete this workout.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'edit_routine',
            'description': 'Edit an existing routine preset: rename it, change its category, add/remove exercises, or replace its exercise list.',
            'parameters': {
              'type': 'object',
              'properties': {
                'routineName': {
                  'type': 'string',
                  'description': 'Name of the existing routine to edit.',
                },
                'newName': {
                  'type': 'string',
                  'description': 'New name for the routine preset.',
                },
                'newCategory': {
                  'type': 'string',
                  'description': 'New category or description for the routine.',
                },
                'addExercises': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of exercise names to append to the routine.',
                },
                'removeExercises': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of exercise names to remove from the routine.',
                },
                'setExercises': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'Replacement list of ALL exercises for this routine.',
                },
              },
              'required': ['routineName'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'delete_routine',
            'description': 'Delete an existing routine preset.',
            'parameters': {
              'type': 'object',
              'properties': {
                'routineName': {
                  'type': 'string',
                  'description': 'Name of the routine preset to delete.',
                },
              },
              'required': ['routineName'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'edit_exercise',
            'description': 'Edit an exercise in the exercise catalog: rename it, change muscle group, rest seconds, rep range, or archive it.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Current name of the exercise to edit.',
                },
                'newName': {
                  'type': 'string',
                  'description': 'New name for the exercise.',
                },
                'muscleGroup': {
                  'type': 'string',
                  'description': 'Primary muscle group (e.g. chest, back, legs, shoulders, arms, core).',
                },
                'restSeconds': {
                  'type': 'integer',
                  'description': 'Default rest timer countdown in seconds.',
                },
                'repMin': {
                  'type': 'integer',
                  'description': 'Target repetition minimum.',
                },
                'repMax': {
                  'type': 'integer',
                  'description': 'Target repetition maximum.',
                },
                'archive': {
                  'type': 'boolean',
                  'description': 'Whether to archive or unarchive the exercise.',
                },
              },
              'required': ['exerciseName'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'edit_setting',
            'description': 'Edit an app setting or user preference (e.g. weight_unit, include_warmups_in_volume).',
            'parameters': {
              'type': 'object',
              'properties': {
                'key': {
                  'type': 'string',
                  'description': 'Setting key (e.g. weight_unit, include_warmups_in_volume).',
                },
                'value': {
                  'type': 'string',
                  'description': 'New setting value (e.g. kg, lbs, true, false).',
                },
              },
              'required': ['key', 'value'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'ask_user_question',
            'description': 'Ask the user an interactive question with 2 to 4 selectable choices for confirmation, preference, routine choice, or target weight. This halts further execution until the user answers.',
            'parameters': {
              'type': 'object',
              'properties': {
                'summary': {
                  'type': 'string',
                  'description': 'A concise explanation or context of what is happening or why this question is being asked before presenting options.',
                },
                'question': {
                  'type': 'string',
                  'description': 'The question to present to the user.',
                },
                'options': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': '2 to 4 concise selectable options for the user to tap (e.g. ["80 kg", "85 kg", "90 kg"] or ["Push Day", "Pull Day", "Leg Day"]).',
                },
              },
              'required': ['question', 'options'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'calculate_warmup_sets',
            'description': 'Calculate a scientific warmup ramp-up progression for an exercise up to a target working weight, including exact plate loading calculations per side and optional automatic logging to today\'s active workout.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise (e.g. Bench Press, Squat, Deadlift, Shoulder Press).',
                },
                'targetWeight': {
                  'type': 'number',
                  'description': 'The target working weight (in active unit, kg or lbs).',
                },
                'barWeight': {
                  'type': 'number',
                  'description': 'Weight of the empty barbell (defaults to 20 kg or 45 lbs).',
                },
                'addToWorkout': {
                  'type': 'boolean',
                  'description': 'If true, automatically logs and adds the generated warmup sets to today\'s active workout.',
                },
              },
              'required': ['exerciseName', 'targetWeight'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'analyze_muscle_balance',
            'description': 'Analyze weekly and monthly volume distribution across all muscle groups, calculate push/pull and upper/lower ratios, and identify lagging or neglected muscles from logged workout history.',
            'parameters': {
              'type': 'object',
              'properties': {
                'days': {
                  'type': 'integer',
                  'description': 'Number of past days to analyze (e.g. 7 for past week, 14 for 2 weeks, 30 for past month). Defaults to 14.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'get_exercise_technique',
            'description': 'Retrieve biomechanical technique cues, setup checklist, mind-muscle cues, common failure mistakes, and safe joint-friendly alternative exercises for any movement or injury accommodation.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise to analyze (e.g. Barbell Squat, Romanian Deadlift, Bench Press, Lat Pulldown).',
                },
                'focus': {
                  'type': 'string',
                  'enum': ['cues', 'safety', 'alternatives', 'hypertrophy'],
                  'description': 'Optional primary focus area. Defaults to cues.',
                },
              },
              'required': ['exerciseName'],
            },
          },
        },
      ];

  /// Execute a tool by name with arguments
  Future<AiToolExecutionResult> executeTool(AiToolCall call) async {
    try {
      switch (call.name) {
        case 'query_workout_history':
          return await _executeQueryWorkoutHistory(
            muscleGroup: call.arguments['muscleGroup']?.toString(),
            exerciseName: call.arguments['exerciseName']?.toString(),
            limit: (call.arguments['limit'] as num?)?.toInt() ?? 10,
            offset: (call.arguments['offset'] as num?)?.toInt() ?? 0,
          );
        case 'calculate_warmup_sets':
          return await _executeCalculateWarmupSets(
            exerciseName: call.arguments['exerciseName']?.toString() ?? '',
            targetWeight: (call.arguments['targetWeight'] as num?)?.toDouble() ?? 0.0,
            barWeight: (call.arguments['barWeight'] as num?)?.toDouble(),
            addToWorkout: call.arguments['addToWorkout'] as bool? ?? false,
          );
        case 'analyze_muscle_balance':
          return await _executeAnalyzeMuscleBalance(
            days: (call.arguments['days'] as num?)?.toInt() ?? 14,
          );
        case 'get_exercise_technique':
          return await _executeGetExerciseTechnique(
            exerciseName: call.arguments['exerciseName']?.toString() ?? '',
            focus: call.arguments['focus']?.toString() ?? 'cues',
          );
        case 'ask_user_question':
          return await _executeAskUserQuestion(
            question: call.arguments['question']?.toString() ?? '',
            options: (call.arguments['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
            summary: call.arguments['summary']?.toString(),
          );
        case 'search_web':
          return await _executeSearchWeb(call.arguments['query']?.toString() ?? '');
        case 'log_set':
          return await _executeLogSet(
            exerciseName: call.arguments['exerciseName']?.toString() ?? '',
            weight: (call.arguments['weight'] as num?)?.toDouble() ?? 0.0,
            reps: (call.arguments['reps'] as num?)?.toInt() ?? 0,
            setTypeStr: call.arguments['setType']?.toString(),
            dateStr: call.arguments['date']?.toString(),
          );
        case 'edit_set':
          return await _executeEditSet(
            exerciseName: call.arguments['exerciseName']?.toString() ?? '',
            setIndex: (call.arguments['setIndex'] as num?)?.toInt(),
            weight: (call.arguments['weight'] as num?)?.toDouble(),
            reps: (call.arguments['reps'] as num?)?.toInt(),
            setTypeStr: call.arguments['setType']?.toString(),
            rpe: (call.arguments['rpe'] as num?)?.toDouble(),
          );
        case 'delete_set':
          return await _executeDeleteSet(
            exerciseName: call.arguments['exerciseName']?.toString(),
            setIndex: (call.arguments['setIndex'] as num?)?.toInt(),
          );
        case 'add_exercise':
          return await _executeAddExercise(call.arguments['exerciseName']?.toString() ?? '');
        case 'create_custom_exercise':
          return await _executeCreateCustomExercise(
            name: call.arguments['name']?.toString() ?? '',
            muscleGroup: call.arguments['muscleGroup']?.toString(),
            equipmentStr: call.arguments['equipment']?.toString(),
          );
        case 'set_rest_day':
          return await _executeSetRestDay(
            dateStr: call.arguments['date']?.toString(),
            isRest: call.arguments['isRest'] as bool? ?? true,
            note: call.arguments['note']?.toString(),
          );
        case 'remove_exercise':
          return await _executeRemoveExercise(call.arguments['exerciseName']?.toString() ?? '');
        case 'start_workout':
          final exerciseNamesRaw = call.arguments['exerciseNames'];
          final exerciseNames = exerciseNamesRaw is List
              ? exerciseNamesRaw.map((e) => e.toString()).toList()
              : <String>[];
          return await _executeStartWorkout(
            title: call.arguments['title']?.toString() ?? 'AI Workout Session',
            exerciseNames: exerciseNames,
            dateStr: call.arguments['date']?.toString(),
          );
        case 'finish_workout':
          return await _executeFinishWorkout();
        case 'edit_workout':
          return await _executeEditWorkout(
            title: call.arguments['title']?.toString(),
            note: call.arguments['note']?.toString(),
            feel: (call.arguments['feel'] as num?)?.toInt(),
          );
        case 'delete_workout':
          return await _executeDeleteWorkout(
            workoutId: call.arguments['workoutId']?.toString(),
            date: call.arguments['date']?.toString(),
            confirmed: call.arguments['confirmed'] as bool?,
          );
        case 'create_routine':
          final exerciseNamesRaw = call.arguments['exerciseNames'];
          final exerciseNames = exerciseNamesRaw is List
              ? exerciseNamesRaw.map((e) => e.toString()).toList()
              : <String>[];
          return await _executeCreateRoutine(
            name: call.arguments['name']?.toString() ?? 'Custom Routine',
            category: call.arguments['category']?.toString() ?? 'Custom',
            exerciseNames: exerciseNames,
          );
        case 'edit_routine':
          final addRaw = call.arguments['addExercises'];
          final remRaw = call.arguments['removeExercises'];
          final setRaw = call.arguments['setExercises'];
          return await _executeEditRoutine(
            routineName: call.arguments['routineName']?.toString() ?? '',
            newName: call.arguments['newName']?.toString(),
            newCategory: call.arguments['newCategory']?.toString(),
            addExercises: addRaw is List ? addRaw.map((e) => e.toString()).toList() : null,
            removeExercises: remRaw is List ? remRaw.map((e) => e.toString()).toList() : null,
            setExercises: setRaw is List ? setRaw.map((e) => e.toString()).toList() : null,
          );
        case 'delete_routine':
          return await _executeDeleteRoutine(call.arguments['routineName']?.toString() ?? '');
        case 'edit_exercise':
          return await _executeEditExercise(
            exerciseName: call.arguments['exerciseName']?.toString() ?? '',
            newName: call.arguments['newName']?.toString(),
            muscleGroup: call.arguments['muscleGroup']?.toString(),
            restSeconds: (call.arguments['restSeconds'] as num?)?.toInt(),
            repMin: (call.arguments['repMin'] as num?)?.toInt(),
            repMax: (call.arguments['repMax'] as num?)?.toInt(),
            archive: call.arguments['archive'] as bool?,
          );
        case 'edit_setting':
          return await _executeEditSetting(
            key: call.arguments['key']?.toString() ?? '',
            value: call.arguments['value']?.toString() ?? '',
          );
        case 'start_rest_timer':
          final secs = (call.arguments['seconds'] as num?)?.toInt() ?? 90;
          final exName = call.arguments['exerciseName']?.toString();
          return await _executeStartRestTimer(secs, exName);
        case 'recommend_weights':
          return await _executeRecommendWeights(call.arguments['exerciseName']?.toString() ?? '');
        case 'query_prs_and_history':
          return await _executeQueryPrs(call.arguments['exerciseName']?.toString());
        case 'get_today_workout':
        case 'query_today_workout':
        case 'get_workout_session':
          return await _executeGetTodayWorkout(call.arguments['date']?.toString());
        case 'export_backup':
          return await _executeExportBackup();
        default:
          return AiToolExecutionResult(
            toolName: call.name,
            success: false,
            summary: 'Unknown tool: ${call.name}',
          );
      }
    } catch (e) {
      return AiToolExecutionResult(
        toolName: call.name,
        success: false,
        summary: 'Error executing ${call.name}: $e',
      );
    }
  }

  Future<AiToolExecutionResult> _executeSearchWeb(String query) async {
    if (query.trim().isEmpty) {
      return const AiToolExecutionResult(
        toolName: 'search_web',
        success: false,
        summary: 'Search query was empty.',
      );
    }

    try {
      final uri = Uri.parse(
        'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}',
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = resp.body;
        final results = <Map<String, String>>[];
        final snippetRegex = RegExp(r'<a class="result__snippet[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>', dotAll: true);
        final matches = snippetRegex.allMatches(body);

        for (final m in matches.take(5)) {
          var rawUrl = m.group(1) ?? '';
          var text = m.group(2) ?? '';
          text = text.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&quot;', '"').replaceAll('&amp;', '&').trim();

          // Clean DDG redirect URL if present
          if (rawUrl.contains('uddg=')) {
            final split = rawUrl.split('uddg=');
            if (split.length > 1) {
              rawUrl = Uri.decodeComponent(split[1].split('&')[0]);
            }
          }

          if (text.isNotEmpty) {
            results.add({
              'snippet': text,
              'url': rawUrl,
            });
          }
        }

        if (results.isEmpty) {
          // Fallback plain regex
          final plainSnippets = RegExp(r'class="result__snippet[^>]*>([^<]+)<').allMatches(body);
          for (final m in plainSnippets.take(4)) {
            final t = m.group(1)?.trim();
            if (t != null && t.isNotEmpty) {
              results.add({'snippet': t, 'url': 'https://duckduckgo.com/?q=${Uri.encodeComponent(query)}'});
            }
          }
        }

        return AiToolExecutionResult(
          toolName: 'search_web',
          success: true,
          summary: 'Found ${results.length} web results for "$query"',
          data: results,
        );
      }

      return AiToolExecutionResult(
        toolName: 'search_web',
        success: false,
        summary: 'Web search returned status code: ${resp.statusCode}',
      );
    } catch (e) {
      return AiToolExecutionResult(
        toolName: 'search_web',
        success: false,
        summary: 'Web search network issue: $e',
      );
    }
  }

  // ─── Helpers for Custom Exercises & Dates ─────────────────────────────

  static DateTime _resolveDateString(String? dateStr) {
    final now = DateTime.now();
    if (dateStr == null || dateStr.trim().isEmpty) {
      return AppDateUtils.normalizeDate(now);
    }
    final lower = dateStr.trim().toLowerCase();
    if (lower == 'today') {
      return AppDateUtils.normalizeDate(now);
    }
    if (lower == 'yesterday') {
      return AppDateUtils.normalizeDate(now.subtract(const Duration(days: 1)));
    }
    if (lower.contains('day ago') || lower.contains('days ago')) {
      final match = RegExp(r'(\d+)').firstMatch(lower);
      if (match != null) {
        final days = int.tryParse(match.group(1) ?? '1') ?? 1;
        return AppDateUtils.normalizeDate(now.subtract(Duration(days: days)));
      }
    }
    const weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (lower.contains(entry.key)) {
        int diff = now.weekday - entry.value;
        if (diff <= 0) diff += 7;
        return AppDateUtils.normalizeDate(now.subtract(Duration(days: diff)));
      }
    }
    final parsed = DateTime.tryParse(dateStr);
    if (parsed != null) {
      return AppDateUtils.normalizeDate(parsed);
    }
    return AppDateUtils.normalizeDate(now);
  }

  static String _inferMuscleGroup(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('run') || lower.contains('walk') || lower.contains('bike') ||
        lower.contains('cycl') || lower.contains('swim') || lower.contains('cardio') ||
        lower.contains('jump') || lower.contains('hiit') || lower.contains('row') ||
        lower.contains('football') || lower.contains('soccer') || lower.contains('basketball') ||
        lower.contains('tennis') || lower.contains('badminton') || lower.contains('box') ||
        lower.contains('game') || lower.contains('sport') || lower.contains('cricket') ||
        lower.contains('rugby') || lower.contains('volleyball') || lower.contains('padel') ||
        lower.contains('skat') || lower.contains('aerobic') || lower.contains('jog')) {
      return 'cardio';
    }
    if (lower.contains('bench') || lower.contains('chest') || lower.contains('fly') ||
        lower.contains('pushup') || lower.contains('push-up') || lower.contains('pec') ||
        lower.contains('dip')) {
      return 'chest';
    }
    if (lower.contains('squat') || lower.contains('leg') || lower.contains('quad') ||
        lower.contains('hamstring') || lower.contains('calf') || lower.contains('calves') ||
        lower.contains('lunge') || lower.contains('hack')) {
      return 'legs';
    }
    if (lower.contains('deadlift') || lower.contains('pull') || lower.contains('lat') ||
        lower.contains('chin') || lower.contains('back') || lower.contains('shrug')) {
      return 'back';
    }
    if (lower.contains('shoulder') || lower.contains('overhead') || lower.contains('military') ||
        lower.contains('lateral') || lower.contains('delt') || lower.contains('arnold') ||
        lower.contains('press')) {
      return 'shoulders';
    }
    if (lower.contains('curl') || lower.contains('bicep')) {
      return 'biceps';
    }
    if (lower.contains('tricep') || lower.contains('skull') || lower.contains('pushdown') ||
        lower.contains('extension')) {
      return 'triceps';
    }
    if (lower.contains('crunch') || lower.contains('plank') || lower.contains('ab') ||
        lower.contains('situp') || lower.contains('core')) {
      return 'core';
    }
    if (lower.contains('glute') || lower.contains('hip') || lower.contains('thrust')) {
      return 'glutes';
    }
    if (lower.contains('wrist') || lower.contains('forearm') || lower.contains('grip')) {
      return 'forearms';
    }
    return 'cardio';
  }

  static EquipmentType _inferEquipment(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('dumbbell') || lower.contains('db')) return EquipmentType.dumbbell;
    if (lower.contains('barbell') || lower.contains('bb')) return EquipmentType.barbell;
    if (lower.contains('cable')) return EquipmentType.cable;
    if (lower.contains('machine') || lower.contains('smith')) return EquipmentType.machine;
    if (lower.contains('bodyweight') || lower.contains('pushup') || lower.contains('pullup') ||
        lower.contains('run') || lower.contains('walk') || lower.contains('game') ||
        lower.contains('football') || lower.contains('basketball')) {
      return EquipmentType.bodyweight;
    }
    return EquipmentType.other;
  }

  static EquipmentType? _parseEquipment(String? eqStr) {
    if (eqStr == null) return null;
    final lower = eqStr.toLowerCase();
    for (final eq in EquipmentType.values) {
      if (eq.name.toLowerCase() == lower) return eq;
    }
    return null;
  }

  Future<ExerciseModel> _ensureExercise(
    String exerciseName, {
    String? muscleGroupId,
    EquipmentType? equipment,
  }) async {
    final exRepo = _ref.read(exerciseRepositoryProvider);
    final allEx = await exRepo.getExercises();
    final cleanName = exerciseName.trim();
    final cleanLower = cleanName.toLowerCase();

    // 1. Exact match
    var matched = allEx.where((e) => e.name.toLowerCase() == cleanLower).firstOrNull;
    if (matched != null) return matched;

    // 2. Token match
    final searchTokens = cleanLower.replaceAll(RegExp(r'[^\w\s]'), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    matched = allEx.where((e) {
      final eTokens = e.name.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      return searchTokens.every((token) => eTokens.any((et) => et.contains(token) || token.contains(et)));
    }).firstOrNull;
    if (matched != null) return matched;

    // 3. Substring match
    matched = allEx.where((e) {
      final eName = e.name.toLowerCase();
      return eName.contains(cleanLower) || cleanLower.contains(eName);
    }).firstOrNull;
    if (matched != null) return matched;

    // 4. Not found in catalog: Create custom exercise / game / activity automatically!
    final resolvedMuscleGroup = muscleGroupId ?? _inferMuscleGroup(cleanName);
    final resolvedEquipment = equipment ?? _inferEquipment(cleanName);

    return await exRepo.createCustomExercise(
      name: cleanName,
      muscleGroupId: resolvedMuscleGroup,
      equipment: resolvedEquipment,
    );
  }

  // ─── Execution Methods ────────────────────────────────────────────────

  Future<AiToolExecutionResult> _executeCreateCustomExercise({
    required String name,
    String? muscleGroup,
    String? equipmentStr,
  }) async {
    if (name.trim().isEmpty) {
      return const AiToolExecutionResult(
        toolName: 'create_custom_exercise',
        success: false,
        summary: 'Exercise name cannot be empty.',
      );
    }

    final exRepo = _ref.read(exerciseRepositoryProvider);
    final allEx = await exRepo.getExercises();
    final cleanName = name.trim();
    final existing = allEx.where((e) => e.name.toLowerCase() == cleanName.toLowerCase()).firstOrNull;
    if (existing != null) {
      return AiToolExecutionResult(
        toolName: 'create_custom_exercise',
        success: true,
        summary: 'Exercise "${existing.name}" already exists in catalog (${existing.muscleGroupId}).',
        data: {'id': existing.id, 'name': existing.name, 'muscleGroup': existing.muscleGroupId},
      );
    }

    final mGroup = muscleGroup ?? _inferMuscleGroup(cleanName);
    final eq = _parseEquipment(equipmentStr) ?? _inferEquipment(cleanName);

    final created = await exRepo.createCustomExercise(
      name: cleanName,
      muscleGroupId: mGroup,
      equipment: eq,
    );

    return AiToolExecutionResult(
      toolName: 'create_custom_exercise',
      success: true,
      summary: 'Created custom exercise/activity "${created.name}" under ${created.muscleGroupId.toUpperCase()} (${created.equipment.name}).',
      data: {'id': created.id, 'name': created.name, 'muscleGroup': created.muscleGroupId, 'equipment': created.equipment.name},
    );
  }

  Future<AiToolExecutionResult> _executeSetRestDay({
    String? dateStr,
    bool isRest = true,
    String? note,
  }) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final targetDate = _resolveDateString(dateStr);

    await workoutRepo.markDateAsRestDay(targetDate, isRest: isRest, note: note);

    // Sync selectedWorkoutDateProvider so UI reflects it immediately
    _ref.read(selectedWorkoutDateProvider.notifier).state = targetDate;

    final formattedDate = AppDateUtils.formatShortDate(targetDate);
    final isToday = AppDateUtils.isSameDay(targetDate, DateTime.now());
    final dayLabel = isToday ? 'today' : formattedDate;

    return AiToolExecutionResult(
      toolName: 'set_rest_day',
      success: true,
      summary: isRest
          ? 'Marked $dayLabel as a Rest & Recovery Day.${note != null ? ' Note: $note' : ''}'
          : 'Unmarked Rest Day for $dayLabel. You are ready to train!',
      data: {
        'date': targetDate.toIso8601String(),
        'isRest': isRest,
        'note': note,
      },
    );
  }

  Future<AiToolExecutionResult> _executeLogSet({
    required String exerciseName,
    required double weight,
    required int reps,
    String? setTypeStr,
    String? dateStr,
  }) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final targetDate = _resolveDateString(dateStr);

    var workout = await workoutRepo.getOrCreateWorkoutForDate(targetDate);

    // Find or automatically create custom exercise/game
    final matchedEx = await _ensureExercise(exerciseName);

    // Check if exercise already in workout — reuse existing entry to avoid duplicates
    var weItem = workout.exercises.where((we) => we.exercise.id == matchedEx.id).firstOrNull;
    if (weItem == null) {
      final weId = await workoutRepo.addExerciseToWorkout(
        workoutId: workout.id,
        exerciseId: matchedEx.id,
      );
      final refreshed = await workoutRepo.getOrCreateWorkoutForDate(targetDate);
      weItem = refreshed.exercises.where((we) => we.id == weId).firstOrNull;
    }

    final weId = weItem?.id;
    if (weId == null) {
      return const AiToolExecutionResult(
        toolName: 'log_set',
        success: false,
        summary: 'Failed to bind exercise to workout session.',
      );
    }

    // Default to 'working' — only use warmup if caller explicitly says so
    SetType setType = SetType.working;
    if (setTypeStr != null) {
      final sLower = setTypeStr.toLowerCase();
      if (sLower.contains('warm')) {
        setType = SetType.warmup;
      } else if (sLower.contains('drop')) {
        setType = SetType.drop;
      } else if (sLower.contains('fail')) {
        setType = SetType.failure;
      }
    }

    await workoutRepo.logSet(
      workoutExerciseId: weId,
      exerciseId: matchedEx.id,
      muscleGroupId: matchedEx.muscleGroupId,
      date: targetDate,
      weight: weight,
      reps: reps,
      setType: setType,
    );

    // Trigger Rest Timer only if it's today
    if (AppDateUtils.isSameDay(targetDate, DateTime.now())) {
      _ref.read(restTimerProvider).start(
            seconds: matchedEx.restSeconds > 0 ? matchedEx.restSeconds : 90,
            exerciseName: matchedEx.name,
          );
    }

    // Check for PR
    final allHistory = await workoutRepo.getAllHistoricalSetsForExercise(matchedEx.id);
    final pr = PrDetector.checkSetPr(
      newSet: SetModel(
        id: 'new',
        workoutExerciseId: weId,
        exerciseId: matchedEx.id,
        muscleGroupId: matchedEx.muscleGroupId,
        date: targetDate,
        setIndex: (weItem?.sets.length ?? 0) + 1,
        weight: weight,
        reps: reps,
        setType: setType,
        completedAt: targetDate,
      ),
      historicalSets: allHistory,
    );

    final prText = pr.isPr ? ' NEW PR: ${pr.description}!' : '';
    final dateNotice = AppDateUtils.isSameDay(targetDate, DateTime.now())
        ? ''
        : ' on ${AppDateUtils.formatShortDate(targetDate)}';
    final customNotice = matchedEx.isCustom ? ' (custom exercise created)' : '';

    return AiToolExecutionResult(
      toolName: 'log_set',
      success: true,
      summary: 'Logged ${matchedEx.name}$customNotice: ${weight}kg × $reps (${setType.name})$dateNotice$prText',
      data: {
        'exercise': matchedEx.name,
        'weight': weight,
        'reps': reps,
        'setType': setType.name,
        'date': targetDate.toIso8601String(),
        'pr': pr.isPr ? pr.description : null,
        'isCustom': matchedEx.isCustom,
      },
    );
  }

  Future<AiToolExecutionResult> _executeAddExercise(String exerciseName) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final workout = await workoutRepo.getOrCreateTodayWorkout();
    final matchedEx = await _ensureExercise(exerciseName);

    // Prevent duplicate — if exercise is already in the session, just report it
    final alreadyIn = workout.exercises.any((we) => we.exercise.id == matchedEx.id);
    if (alreadyIn) {
      return AiToolExecutionResult(
        toolName: 'add_exercise',
        success: true,
        summary: '${matchedEx.name} is already in the active session.',
        data: {'exercise': matchedEx.name, 'duplicate': true},
      );
    }

    await workoutRepo.addExerciseToWorkout(
      workoutId: workout.id,
      exerciseId: matchedEx.id,
    );

    final customNotice = matchedEx.isCustom ? ' (custom exercise created)' : '';

    return AiToolExecutionResult(
      toolName: 'add_exercise',
      success: true,
      summary: 'Added ${matchedEx.name}$customNotice to active session.',
      data: {'exercise': matchedEx.name, 'muscleGroup': matchedEx.muscleGroupId, 'isCustom': matchedEx.isCustom},
    );
  }

  Future<AiToolExecutionResult> _executeStartWorkout({
    required String title,
    List<String> exerciseNames = const [],
    String? dateStr,
  }) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final targetDate = _resolveDateString(dateStr);

    final workout = await workoutRepo.getOrCreateWorkoutForDate(targetDate, routineTitle: title);
    int addedCount = 0;
    for (final name in exerciseNames) {
      final matched = await _ensureExercise(name);
      final alreadyHas = workout.exercises.any((we) => we.exercise.id == matched.id);
      if (!alreadyHas) {
        await workoutRepo.addExerciseToWorkout(
          workoutId: workout.id,
          exerciseId: matched.id,
        );
        addedCount++;
      }
    }

    final dateNotice = AppDateUtils.isSameDay(targetDate, DateTime.now())
        ? ''
        : ' on ${AppDateUtils.formatShortDate(targetDate)}';

    return AiToolExecutionResult(
      toolName: 'start_workout',
      success: true,
      summary: 'Started workout "$title"$dateNotice with $addedCount exercise(s).',
      data: {'workoutId': workout.id, 'title': title, 'exercisesAdded': addedCount, 'date': targetDate.toIso8601String()},
    );
  }

  Future<AiToolExecutionResult> _executeFinishWorkout() async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final workout = await workoutRepo.getOrCreateTodayWorkout();

    await workoutRepo.updateWorkoutMeta(
      workoutId: workout.id,
      endedAt: DateTime.now(),
      feel: 3,
      note: 'Finished via AI Assistant',
    );

    return AiToolExecutionResult(
      toolName: 'finish_workout',
      success: true,
      summary: 'Workout "${workout.title}" completed and saved!',
      data: {'workoutId': workout.id, 'title': workout.title},
    );
  }

  Future<AiToolExecutionResult> _executeCreateRoutine({
    required String name,
    required String category,
    required List<String> exerciseNames,
  }) async {
    final routineRepo = _ref.read(routineRepositoryProvider);
    final exRepo = _ref.read(exerciseRepositoryProvider);
    var allEx = await exRepo.getExercises();

    final matchedIds = <String>[];
    final addedExerciseNames = <String>[];

    for (final rawName in exerciseNames) {
      final cleanName = rawName.trim();
      if (cleanName.isEmpty) continue;
      final cleanLower = cleanName.toLowerCase();

      // 1. Exact match
      var found = allEx.where((e) => e.name.toLowerCase() == cleanLower).firstOrNull;

      // 2. Normalized token match (e.g. "bench press barbell" vs "bench press (barbell)")
      if (found == null) {
        final searchTokens = cleanLower.replaceAll(RegExp(r'[^\w\s]'), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
        found = allEx.where((e) {
          final eTokens = e.name.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
          return searchTokens.every((token) => eTokens.any((et) => et.contains(token) || token.contains(et)));
        }).firstOrNull;
      }

      // 3. Substring match either way
      found ??= allEx.where((e) {
        final eName = e.name.toLowerCase();
        return eName.contains(cleanLower) || cleanLower.contains(eName);
      }).firstOrNull;

      // 4. If still not in database, DO NOT LIMIT OR SKIP! Create the custom exercise automatically!
      if (found == null) {
        String muscleGroupId = 'chest';
        if (cleanLower.contains('squat') || cleanLower.contains('leg') || cleanLower.contains('quad') || cleanLower.contains('ham') || cleanLower.contains('calf') || cleanLower.contains('lunge')) {
          muscleGroupId = 'legs';
        } else if (cleanLower.contains('pull') || cleanLower.contains('row') || cleanLower.contains('lat') || cleanLower.contains('back') || cleanLower.contains('chin') || cleanLower.contains('deadlift')) {
          muscleGroupId = 'back';
        } else if (cleanLower.contains('press') || cleanLower.contains('shoulder') || cleanLower.contains('delt') || cleanLower.contains('raise') || cleanLower.contains('overhead')) {
          muscleGroupId = 'shoulders';
        } else if (cleanLower.contains('curl') || cleanLower.contains('bicep') || cleanLower.contains('tricep') || cleanLower.contains('extension') || cleanLower.contains('arm') || cleanLower.contains('skull')) {
          muscleGroupId = 'arms';
        } else if (cleanLower.contains('ab') || cleanLower.contains('crunch') || cleanLower.contains('core') || cleanLower.contains('plank')) {
          muscleGroupId = 'core';
        }

        EquipmentType equipment = EquipmentType.barbell;
        if (cleanLower.contains('dumbbell') || cleanLower.contains('db')) {
          equipment = EquipmentType.dumbbell;
        } else if (cleanLower.contains('cable')) {
          equipment = EquipmentType.cable;
        } else if (cleanLower.contains('machine') || cleanLower.contains('smith')) {
          equipment = EquipmentType.machine;
        } else if (cleanLower.contains('bodyweight') || cleanLower.contains('body') || cleanLower.contains('pull-up') || cleanLower.contains('dip') || cleanLower.contains('push-up')) {
          equipment = EquipmentType.bodyweight;
        }

        final newEx = await exRepo.createCustomExercise(
          name: cleanName,
          muscleGroupId: muscleGroupId,
          equipment: equipment,
        );
        allEx = await exRepo.getExercises();
        found = newEx;
      }

      if (!matchedIds.contains(found.id)) {
        matchedIds.add(found.id);
        addedExerciseNames.add(found.name);
      }
    }

    if (matchedIds.isEmpty) {
      return AiToolExecutionResult(
        toolName: 'create_routine',
        success: false,
        summary: 'No exercises provided for routine "$name".',
      );
    }

    final routineId = await routineRepo.createRoutine(
      name: name,
      description: category,
      exerciseIds: matchedIds,
    );

    return AiToolExecutionResult(
      toolName: 'create_routine',
      success: true,
      summary: 'Created routine "$name" ($category) with ${matchedIds.length} exercises: ${addedExerciseNames.join(', ')}.',
      data: {
        'routineId': routineId,
        'name': name,
        'category': category,
        'exerciseCount': matchedIds.length,
        'exercises': addedExerciseNames,
      },
    );
  }

  Future<AiToolExecutionResult> _executeStartRestTimer(int seconds, String? exName) async {
    _ref.read(restTimerProvider).start(
          seconds: seconds,
          exerciseName: exName ?? 'Set Recovery',
        );

    return AiToolExecutionResult(
      toolName: 'start_rest_timer',
      success: true,
      summary: 'Rest timer started for ${seconds}s ($exName).',
      data: {'seconds': seconds, 'exerciseName': exName},
    );
  }

  Future<AiToolExecutionResult> _executeRecommendWeights(String exerciseName) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final exRepo = _ref.read(exerciseRepositoryProvider);

    final allEx = await exRepo.getExercises();
    final matched = allEx.where((e) => e.name.toLowerCase().contains(exerciseName.toLowerCase())).firstOrNull;

    if (matched == null) {
      return AiToolExecutionResult(
        toolName: 'recommend_weights',
        success: false,
        summary: 'Exercise "$exerciseName" not found.',
      );
    }

    final prevSets = await workoutRepo.getPreviousSetsForExercise(matched.id);
    if (prevSets.isEmpty) {
      return AiToolExecutionResult(
        toolName: 'recommend_weights',
        success: true,
        summary: 'No previous data found for ${matched.name}. Start with a moderate weight (e.g. 50-60% effort) for 8-12 reps to build a baseline.',
        data: {'exercise': matched.name, 'hasHistory': false},
      );
    }

    final workingSets = prevSets.where((s) => s.setType == SetType.working).toList();
    final effectiveSets = workingSets.isNotEmpty ? workingSets : prevSets;
    final topSet = effectiveSets.reduce((a, b) => a.weight >= b.weight ? a : b);

    // Target progressive overload
    final nextWeight = topSet.weight + matched.weightStep;
    final targetReps = topSet.reps >= 10 ? 8 : topSet.reps + 1;

    return AiToolExecutionResult(
      toolName: 'recommend_weights',
      success: true,
      summary: 'Previous Best: ${topSet.weight}kg × ${topSet.reps}. Recommended Target: ${nextWeight}kg × $targetReps (Progressive Overload +${matched.weightStep}kg).',
      data: {
        'exercise': matched.name,
        'previousWeight': topSet.weight,
        'previousReps': topSet.reps,
        'targetWeight': nextWeight,
        'targetReps': targetReps,
      },
    );
  }

  Future<AiToolExecutionResult> _executeQueryPrs(String? exerciseName) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final exRepo = _ref.read(exerciseRepositoryProvider);
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final unit = await settingsRepo.getWeightUnit();

    if (exerciseName != null && exerciseName.trim().isNotEmpty) {
      final allEx = await exRepo.getExercises();
      final matched = allEx.where((e) => e.name.toLowerCase().contains(exerciseName.toLowerCase())).firstOrNull;

      if (matched != null) {
        final history = await workoutRepo.getAllHistoricalSetsForExercise(matched.id);

        // Also check today's workout for this exercise
        final today = await workoutRepo.getOrCreateTodayWorkout();
        final todayEx = today.exercises.where((e) => e.exercise.id == matched.id).firstOrNull;
        final todaySets = todayEx?.sets.where((s) => !s.archived).toList() ?? [];
        final todaySummary = todaySets.isNotEmpty
            ? ' | Logged Today: ${todaySets.map((s) => '${UnitConverter.formatWeight(s.weight, unit: unit)}×${s.reps}').join(', ')}'
            : '';

        if (history.isEmpty && todaySets.isEmpty) {
          return AiToolExecutionResult(
            toolName: 'query_prs_and_history',
            success: true,
            summary: 'No sets logged yet for ${matched.name}.',
          );
        }

        final bestWeightSet = history.isNotEmpty ? history.reduce((a, b) => a.weight >= b.weight ? a : b) : null;
        final bestE1rm = history.isNotEmpty ? history.map((s) => E1rmCalculator.calculate(s.weight, s.reps)).fold(0.0, (a, b) => a > b ? a : b) : 0.0;

        final prText = bestWeightSet != null
            ? '${matched.name} PR: ${UnitConverter.formatWeight(bestWeightSet.weight, unit: unit)} × ${bestWeightSet.reps} (e1RM: ${UnitConverter.formatWeight(bestE1rm, unit: unit)})'
            : '${matched.name}: No prior PR';

        return AiToolExecutionResult(
          toolName: 'query_prs_and_history',
          success: true,
          summary: '$prText$todaySummary',
          data: {
            'exercise': matched.name,
            'maxWeight': bestWeightSet?.weight ?? 0.0,
            'maxReps': bestWeightSet?.reps ?? 0,
            'e1rm': bestE1rm,
            'totalSets': history.length,
            'todaySets': todaySets.map((s) => {'weight': s.weight, 'reps': s.reps}).toList(),
          },
        );
      }
    }

    final todayWorkout = await workoutRepo.getOrCreateTodayWorkout();
    final todaySetsCount = todayWorkout.totalSetsCount;
    final todayExList = todayWorkout.exercises.where((e) => !e.archived).map((e) => e.exercise.name).toList();
    final recentWorkouts = await workoutRepo.getRecentWorkouts(limit: 5);

    final todayInfo = todaySetsCount > 0
        ? 'Today\'s workout has $todaySetsCount sets logged across: ${todayExList.join(", ")}.'
        : 'No sets logged yet in today\'s session.';

    return AiToolExecutionResult(
      toolName: 'query_prs_and_history',
      success: true,
      summary: '$todayInfo User has ${recentWorkouts.length} past sessions recorded.',
      data: {
        'todayExercises': todayExList,
        'todayTotalSets': todaySetsCount,
        'todayVolume': todayWorkout.totalVolume,
        'recentWorkoutCount': recentWorkouts.length,
      },
    );
  }

  Future<AiToolExecutionResult> _executeQueryWorkoutHistory({
    String? muscleGroup,
    String? exerciseName,
    int limit = 10,
    int offset = 0,
  }) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final exerciseRepo = _ref.read(exerciseRepositoryProvider);
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final unit = await settingsRepo.getWeightUnit();

    // 1. Resolve muscle group if provided
    String? targetMuscleGroupId;
    String? resolvedMuscleName;
    if (muscleGroup != null && muscleGroup.trim().isNotEmpty) {
      final allMuscleGroups = await exerciseRepo.getMuscleGroups();
      final q = muscleGroup.trim().toLowerCase();
      for (final m in allMuscleGroups) {
        if (m.name.toLowerCase() == q || m.id.toLowerCase() == q) {
          targetMuscleGroupId = m.id;
          resolvedMuscleName = m.name;
          break;
        }
      }
      if (targetMuscleGroupId == null) {
        for (final m in allMuscleGroups) {
          if (m.name.toLowerCase().contains(q) || q.contains(m.name.toLowerCase())) {
            targetMuscleGroupId = m.id;
            resolvedMuscleName = m.name;
            break;
          }
        }
      }
    }

    // 2. Resolve exercise ID if provided
    String? targetExerciseId;
    if (exerciseName != null && exerciseName.trim().isNotEmpty) {
      final allExercises = await exerciseRepo.getExercises();
      final q = exerciseName.trim().toLowerCase();
      for (final e in allExercises) {
        if (e.name.toLowerCase() == q || e.id.toLowerCase() == q) {
          targetExerciseId = e.id;
          break;
        }
      }
      if (targetExerciseId == null) {
        for (final e in allExercises) {
          if (e.name.toLowerCase().contains(q) || q.contains(e.name.toLowerCase())) {
            targetExerciseId = e.id;
            break;
          }
        }
      }
    }

    // 3. Query historical workouts (clamped limit to prevent prompt context explosion)
    final clampedLimit = limit.clamp(1, 25);
    final workouts = await workoutRepo.getHistoryWorkouts(
      muscleGroupId: targetMuscleGroupId,
      exerciseId: targetExerciseId,
      limit: clampedLimit,
      offset: offset,
    );

    if (workouts.isEmpty) {
      final filterDesc = resolvedMuscleName != null
          ? ' for $resolvedMuscleName'
          : (exerciseName != null ? ' for $exerciseName' : '');
      return AiToolExecutionResult(
        toolName: 'query_workout_history',
        success: true,
        summary: 'No historical workout sessions found$filterDesc.',
        data: {'workouts': []},
      );
    }

    // 4. Build compact summaries (PRECAUTION: Avoids dumping full set JSON to prevent context window bloat)
    final sessionsSummary = <Map<String, dynamic>>[];
    final buffer = StringBuffer();
    final filterTitle = resolvedMuscleName != null ? ' ($resolvedMuscleName Sessions)' : '';
    buffer.writeln('Found ${workouts.length} workout sessions$filterTitle:');

    for (final w in workouts) {
      final dateStr = AppDateUtils.formatShortDate(w.date);
      final weekday = DateFormat('EEEE').format(w.date);

      // Filter exercises to matching muscle group or show all if no filter
      final relevantExercises = w.exercises.where((we) {
        if (we.archived) return false;
        if (targetMuscleGroupId != null) {
          return we.exercise.muscleGroupId == targetMuscleGroupId;
        }
        if (targetExerciseId != null) {
          return we.exercise.id == targetExerciseId;
        }
        return true;
      }).toList();

      final exSummaries = <String>[];
      for (final we in relevantExercises) {
        final activeSets = we.sets.where((s) => !s.archived).toList();
        final maxW = activeSets.isNotEmpty
            ? activeSets.map((s) => s.weight).reduce((a, b) => a > b ? a : b)
            : 0.0;
        final maxWeightStr = maxW > 0 ? ', max ${UnitConverter.formatWeight(maxW, unit: unit)}' : '';
        exSummaries.add('${we.exercise.name} (${activeSets.length} sets$maxWeightStr)');
      }

      final exercisesText = exSummaries.isNotEmpty ? exSummaries.join(', ') : 'no matching sets';
      buffer.writeln('• "${w.title}" on $dateStr ($weekday): $exercisesText');

      sessionsSummary.add({
        'id': w.id,
        'date': w.date.toIso8601String(),
        'dateFormatted': dateStr,
        'weekday': weekday,
        'title': w.title,
        'matchedExercises': exSummaries,
        'totalSets': w.totalSetsCount,
        'totalVolume': w.totalVolume,
      });
    }

    return AiToolExecutionResult(
      toolName: 'query_workout_history',
      success: true,
      summary: buffer.toString().trim(),
      data: {
        'totalFound': workouts.length,
        'sessions': sessionsSummary,
      },
    );
  }

  Future<AiToolExecutionResult> _executeGetTodayWorkout(String? dateStr) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final unit = await settingsRepo.getWeightUnit();

    final normDate = _resolveDateString(dateStr);
    final workout = await workoutRepo.getWorkoutForDate(normDate);
    final isToday = AppDateUtils.isToday(normDate);
    final dateLabel = isToday ? 'Today (${AppDateUtils.formatShortDate(normDate)})' : AppDateUtils.formatShortDate(normDate);

    if (workout == null || workout.exercises.isEmpty) {
      return AiToolExecutionResult(
        toolName: 'get_today_workout',
        success: true,
        summary: 'No exercises or sets logged for $dateLabel yet.',
        data: {
          'date': normDate.toIso8601String(),
          'hasWorkout': workout != null,
          'exerciseCount': 0,
          'totalSets': 0,
          'totalVolume': 0.0,
          'isRestDay': workout?.isRestDay ?? false,
        },
      );
    }

    final exercisesData = <Map<String, dynamic>>[];
    final summaryBuffer = StringBuffer();
    summaryBuffer.writeln('Workout for $dateLabel: "${workout.title}"');
    summaryBuffer.writeln('Total Volume: ${UnitConverter.formatWeight(workout.totalVolume, unit: unit)} across ${workout.totalSetsCount} sets.');

    for (final we in workout.exercises) {
      if (we.archived) continue;
      final activeSets = we.sets.where((s) => !s.archived).toList();
      final setsList = activeSets.map((s) => {
        'setIndex': s.setIndex,
        'weight': s.weight,
        'reps': s.reps,
        'setType': s.setType.name,
        'e1rm': s.e1rm,
      }).toList();

      exercisesData.add({
        'exerciseId': we.exercise.id,
        'exerciseName': we.exercise.name,
        'muscleGroup': we.exercise.muscleGroupId,
        'sets': setsList,
      });

      final setsDesc = activeSets.isEmpty
          ? 'no sets logged'
          : activeSets.map((s) => '${UnitConverter.formatWeight(s.weight, unit: unit)}×${s.reps}').join(', ');
      summaryBuffer.writeln('• ${we.exercise.name}: $setsDesc');
    }

    return AiToolExecutionResult(
      toolName: 'get_today_workout',
      success: true,
      summary: summaryBuffer.toString().trim(),
      data: {
        'workoutId': workout.id,
        'title': workout.title,
        'date': normDate.toIso8601String(),
        'isRestDay': workout.isRestDay,
        'totalVolume': workout.totalVolume,
        'totalSets': workout.totalSetsCount,
        'exercises': exercisesData,
      },
    );
  }

  Future<AiToolExecutionResult> _executeExportBackup() async {
    final db = _ref.read(databaseProvider);
    final path = await BackupService.autoBackup(db);
    return AiToolExecutionResult(
      toolName: 'export_backup',
      success: true,
      summary: path != null
          ? 'Backup saved to device storage at:\n$path'
          : 'Backup export completed.',
      data: {'path': path},
    );
  }

  Future<AiToolExecutionResult> _executeEditSet({
    required String exerciseName,
    int? setIndex,
    double? weight,
    int? reps,
    String? setTypeStr,
    double? rpe,
  }) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final workout = await workoutRepo.getOrCreateTodayWorkout();

    WorkoutExerciseItem? weItem;
    final exLower = exerciseName.toLowerCase().trim();
    if (exLower.isNotEmpty) {
      weItem = workout.exercises.where((we) => we.exercise.name.toLowerCase() == exLower).firstOrNull;
      weItem ??= workout.exercises.where((we) => we.exercise.name.toLowerCase().contains(exLower)).firstOrNull;
      weItem ??= workout.exercises.where((we) => exLower.contains(we.exercise.name.toLowerCase())).firstOrNull;
    } else {
      weItem = workout.exercises.where((we) => we.sets.isNotEmpty).lastOrNull;
    }

    if (weItem == null || weItem.sets.isEmpty) {
      return AiToolExecutionResult(
        toolName: 'edit_set',
        success: false,
        summary: 'No sets found for "$exerciseName" in today\'s workout to edit.',
      );
    }

    SetModel targetSet;
    if (setIndex != null && setIndex > 0 && setIndex <= weItem.sets.length) {
      targetSet = weItem.sets[setIndex - 1];
    } else {
      targetSet = weItem.sets.last;
    }

    SetType setType = targetSet.setType;
    if (setTypeStr != null) {
      final s = setTypeStr.toLowerCase();
      if (s.contains('warm')) setType = SetType.warmup;
      if (s.contains('drop')) setType = SetType.drop;
      if (s.contains('fail')) setType = SetType.failure;
      if (s.contains('work')) setType = SetType.working;
    }

    final newWeight = weight ?? targetSet.weight;
    final newReps = reps ?? targetSet.reps;
    final newRpe = rpe ?? targetSet.rpe;

    await workoutRepo.updateSet(
      setId: targetSet.id,
      weight: newWeight,
      reps: newReps,
      setType: setType,
      rpe: newRpe,
    );

    return AiToolExecutionResult(
      toolName: 'edit_set',
      success: true,
      summary: 'Updated ${weItem.exercise.name} set #${targetSet.setIndex} to ${newWeight}kg × $newReps (${setType.name})',
      data: {
        'exercise': weItem.exercise.name,
        'setIndex': targetSet.setIndex,
        'weight': newWeight,
        'reps': newReps,
        'setType': setType.name,
      },
    );
  }

  Future<AiToolExecutionResult> _executeDeleteSet({
    String? exerciseName,
    int? setIndex,
  }) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final workout = await workoutRepo.getOrCreateTodayWorkout();

    WorkoutExerciseItem? weItem;
    if (exerciseName != null && exerciseName.trim().isNotEmpty) {
      final exLower = exerciseName.toLowerCase().trim();
      weItem = workout.exercises.where((we) => we.exercise.name.toLowerCase() == exLower).firstOrNull;
      weItem ??= workout.exercises.where((we) => we.exercise.name.toLowerCase().contains(exLower)).firstOrNull;
      weItem ??= workout.exercises.where((we) => exLower.contains(we.exercise.name.toLowerCase())).firstOrNull;
    } else {
      weItem = workout.exercises.where((we) => we.sets.isNotEmpty).lastOrNull;
    }

    if (weItem == null || weItem.sets.isEmpty) {
      return const AiToolExecutionResult(
        toolName: 'delete_set',
        success: false,
        summary: 'No sets found in today\'s workout to delete.',
      );
    }

    SetModel targetSet;
    if (setIndex != null && setIndex > 0 && setIndex <= weItem.sets.length) {
      targetSet = weItem.sets[setIndex - 1];
    } else {
      targetSet = weItem.sets.last;
    }

    await workoutRepo.deleteSet(targetSet.id);

    return AiToolExecutionResult(
      toolName: 'delete_set',
      success: true,
      summary: 'Deleted set #${targetSet.setIndex} of ${weItem.exercise.name} (${targetSet.weight}kg × ${targetSet.reps})',
      data: {'exercise': weItem.exercise.name, 'setIndex': targetSet.setIndex},
    );
  }

  Future<AiToolExecutionResult> _executeRemoveExercise(String exerciseName) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final workout = await workoutRepo.getOrCreateTodayWorkout();

    final exLower = exerciseName.toLowerCase().trim();
    var weItem = workout.exercises.where((we) => we.exercise.name.toLowerCase() == exLower).firstOrNull;
    weItem ??= workout.exercises.where((we) => we.exercise.name.toLowerCase().contains(exLower)).firstOrNull;
    weItem ??= workout.exercises.where((we) => exLower.contains(we.exercise.name.toLowerCase())).firstOrNull;

    if (weItem == null) {
      return AiToolExecutionResult(
        toolName: 'remove_exercise',
        success: false,
        summary: 'Exercise "$exerciseName" is not in today\'s workout session.',
      );
    }

    await workoutRepo.removeExerciseFromWorkout(weItem.id);

    return AiToolExecutionResult(
      toolName: 'remove_exercise',
      success: true,
      summary: 'Removed "${weItem.exercise.name}" from today\'s workout session.',
      data: {'exercise': weItem.exercise.name},
    );
  }

  Future<AiToolExecutionResult> _executeEditWorkout({
    String? title,
    String? note,
    int? feel,
  }) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final workout = await workoutRepo.getOrCreateTodayWorkout();

    await workoutRepo.updateWorkoutMeta(
      workoutId: workout.id,
      title: title,
      note: note,
      feel: feel,
    );

    final details = <String>[];
    if (title != null) details.add('title: "$title"');
    if (note != null) details.add('note: "$note"');
    if (feel != null) details.add('rating: $feel/5');

    return AiToolExecutionResult(
      toolName: 'edit_workout',
      success: true,
      summary: 'Updated workout details (${details.join(', ')})',
      data: {'title': title, 'note': note, 'feel': feel},
    );
  }

  Future<AiToolExecutionResult> _executeDeleteWorkout({
    String? workoutId,
    String? date,
    bool? confirmed,
  }) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);

    WorkoutModel? targetWorkout;
    if (workoutId != null && workoutId.isNotEmpty) {
      targetWorkout = await workoutRepo.getWorkoutByIdOrNull(workoutId);
    }
    if (targetWorkout == null && date != null && date.isNotEmpty) {
      final dLower = date.toLowerCase();
      DateTime targetDate = DateTime.now();
      if (dLower == 'yesterday') {
        targetDate = DateTime.now().subtract(const Duration(days: 1));
      } else {
        try {
          targetDate = DateTime.parse(date);
        } catch (_) {}
      }
      targetWorkout = await workoutRepo.getWorkoutForDate(targetDate);
    }
    targetWorkout ??= await workoutRepo.getTodayWorkout();

    if (targetWorkout == null) {
      return AiToolExecutionResult(
        toolName: 'delete_workout',
        success: false,
        summary: 'No workout found to delete.',
        data: {'error': 'No workout found'},
      );
    }

    final exCount = targetWorkout.exercises.where((e) => !e.archived).length;
    final setCount = targetWorkout.exercises.fold<int>(
      0,
      (acc, e) => acc + e.sets.where((s) => !s.archived).length,
    );

    // Explicit confirmation permission check
    if (confirmed != true) {
      return AiToolExecutionResult(
        toolName: 'delete_workout',
        success: true,
        summary: 'Requires confirmation: Delete "${targetWorkout.title}"?',
        data: {
          'status': 'pending_confirmation',
          'workoutId': targetWorkout.id,
          'workoutTitle': targetWorkout.title,
          'exerciseCount': exCount,
          'setCount': setCount,
          'date': targetWorkout.startedAt?.toIso8601String() ?? '',
          'message': 'Deleting "${targetWorkout.title}" ($exCount exercises, $setCount sets) requires your confirmation. This cannot be undone.',
        },
      );
    }

    // Deletion confirmed by user
    final title = targetWorkout.title;
    await workoutRepo.deleteWorkout(targetWorkout.id);
    _ref.invalidate(streakAndWeekProvider);
    _ref.read(isWorkoutActiveProvider.notifier).state = false;

    return AiToolExecutionResult(
      toolName: 'delete_workout',
      success: true,
      summary: 'Deleted workout "$title"',
      data: {
        'status': 'deleted',
        'workoutId': targetWorkout.id,
        'workoutTitle': title,
      },
    );
  }

  Future<AiToolExecutionResult> _executeEditRoutine({
    required String routineName,
    String? newName,
    String? newCategory,
    List<String>? addExercises,
    List<String>? removeExercises,
    List<String>? setExercises,
  }) async {
    final routineRepo = _ref.read(routineRepositoryProvider);
    final exRepo = _ref.read(exerciseRepositoryProvider);

    final routines = await routineRepo.getRoutines();
    final routine = _findMatchingRoutine(routines, routineName);

    if (routine == null) {
      return AiToolExecutionResult(
        toolName: 'edit_routine',
        success: false,
        summary: 'Routine preset "$routineName" not found in your routines.',
      );
    }

    var allEx = await exRepo.getExercises();
    List<String> currentExerciseIds = routine.items.map((i) => i.exercise.id).toList();

    if (setExercises != null && setExercises.isNotEmpty) {
      currentExerciseIds.clear();
      for (final en in setExercises) {
        final clean = en.trim();
        var found = allEx.where((e) => e.name.toLowerCase() == clean.toLowerCase()).firstOrNull;
        found ??= allEx.where((e) => e.name.toLowerCase().contains(clean.toLowerCase())).firstOrNull;
        if (found == null) {
          found = await exRepo.createCustomExercise(name: clean, muscleGroupId: 'chest');
          allEx = await exRepo.getExercises();
        }
        if (!currentExerciseIds.contains(found.id)) {
          currentExerciseIds.add(found.id);
        }
      }
    } else {
      if (addExercises != null) {
        for (final en in addExercises) {
          final clean = en.trim();
          var found = allEx.where((e) => e.name.toLowerCase() == clean.toLowerCase()).firstOrNull;
          found ??= allEx.where((e) => e.name.toLowerCase().contains(clean.toLowerCase())).firstOrNull;
          if (found == null) {
            found = await exRepo.createCustomExercise(name: clean, muscleGroupId: 'chest');
            allEx = await exRepo.getExercises();
          }
          if (!currentExerciseIds.contains(found.id)) {
            currentExerciseIds.add(found.id);
          }
        }
      }

      if (removeExercises != null) {
        for (final en in removeExercises) {
          final clean = en.trim().toLowerCase();
          currentExerciseIds.removeWhere((id) {
            final ex = allEx.where((e) => e.id == id).firstOrNull;
            if (ex == null) return false;
            return ex.name.toLowerCase() == clean || ex.name.toLowerCase().contains(clean);
          });
        }
      }
    }

    await routineRepo.updateRoutine(
      routineId: routine.id,
      name: newName,
      description: newCategory,
      exerciseIds: currentExerciseIds,
    );

    return AiToolExecutionResult(
      toolName: 'edit_routine',
      success: true,
      summary: 'Updated routine "${newName ?? routine.name}" (now has ${currentExerciseIds.length} exercises)',
      data: {
        'routineId': routine.id,
        'name': newName ?? routine.name,
        'exerciseCount': currentExerciseIds.length,
      },
    );
  }

  Future<AiToolExecutionResult> _executeDeleteRoutine(String routineName) async {
    final routineRepo = _ref.read(routineRepositoryProvider);
    final routines = await routineRepo.getRoutines();
    final routine = _findMatchingRoutine(routines, routineName);

    if (routine == null) {
      return AiToolExecutionResult(
        toolName: 'delete_routine',
        success: false,
        summary: 'Routine preset "$routineName" not found.',
      );
    }

    await routineRepo.deleteRoutine(routine.id);

    return AiToolExecutionResult(
      toolName: 'delete_routine',
      success: true,
      summary: 'Deleted routine preset "${routine.name}".',
      data: {'routineId': routine.id, 'name': routine.name},
    );
  }

  String _normalizeRoutineString(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  RoutineModel? _findMatchingRoutine(List<RoutineModel> routines, String query) {
    if (routines.isEmpty || query.trim().isEmpty) return null;
    final qRaw = query.trim().toLowerCase();

    // 1. Exact raw name or ID match
    for (final r in routines) {
      if (r.id.toLowerCase() == qRaw || r.name.toLowerCase() == qRaw) return r;
    }

    // 2. Normalized string matching (strips hyphens, punctuation, multiple spaces)
    final qNorm = _normalizeRoutineString(qRaw);
    final qClean = qNorm
        .replaceAll(RegExp(r'\b(routines?|rotines?|presets?|splits?|workouts?|templates?|the|day)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final r in routines) {
      final rNorm = _normalizeRoutineString(r.name);
      if (rNorm == qNorm) return r;
      if (qClean.isNotEmpty && rNorm.contains(qClean)) return r;
      if (rNorm.contains(qNorm) || qNorm.contains(rNorm)) return r;
    }

    // 3. Token-based / word overlap matching (e.g. "4 day hypertrophy upper b" matches "4-Day Hypertrophy - Upper B")
    final queryTokens = _normalizeRoutineString(qRaw)
        .split(' ')
        .where((t) => t.isNotEmpty && t != 'routine' && t != 'rotine' && t != 'preset' && t != 'the' && t != 'a' && t != 'to')
        .toSet();

    RoutineModel? bestMatch;
    int maxMatches = 0;

    for (final r in routines) {
      final rTokens = _normalizeRoutineString(r.name)
          .split(' ')
          .where((t) => t.isNotEmpty)
          .toSet();
      final intersection = queryTokens.intersection(rTokens).length;
      if (intersection > maxMatches) {
        maxMatches = intersection;
        bestMatch = r;
      }
    }

    if (bestMatch != null && (maxMatches >= 2 || (queryTokens.isNotEmpty && maxMatches == queryTokens.length))) {
      return bestMatch;
    }

    return null;
  }

  Future<AiToolExecutionResult> _executeEditExercise({
    required String exerciseName,
    String? newName,
    String? muscleGroup,
    int? restSeconds,
    int? repMin,
    int? repMax,
    bool? archive,
  }) async {
    final exRepo = _ref.read(exerciseRepositoryProvider);
    final allEx = await exRepo.getExercises(includeArchived: true);
    final exLower = exerciseName.toLowerCase().trim();
    var target = allEx.where((e) => e.name.toLowerCase() == exLower).firstOrNull;
    target ??= allEx.where((e) => e.name.toLowerCase().contains(exLower)).firstOrNull;
    target ??= allEx.where((e) => exLower.contains(e.name.toLowerCase())).firstOrNull;

    if (target == null) {
      return AiToolExecutionResult(
        toolName: 'edit_exercise',
        success: false,
        summary: 'Exercise "$exerciseName" not found in exercise catalog.',
      );
    }

    if (archive != null) {
      await exRepo.archiveExercise(target.id, archive);
    }

    final updated = ExerciseModel(
      id: target.id,
      name: newName != null && newName.trim().isNotEmpty ? newName.trim() : target.name,
      muscleGroupId: muscleGroup ?? target.muscleGroupId,
      secondaryGroups: target.secondaryGroups,
      equipment: target.equipment,
      loadMode: target.loadMode,
      isUnilateral: target.isUnilateral,
      weightStep: target.weightStep,
      repMin: repMin ?? target.repMin,
      repMax: repMax ?? target.repMax,
      restSeconds: restSeconds ?? target.restSeconds,
      isCustom: target.isCustom,
      archived: archive ?? target.archived,
    );

    await exRepo.updateExercise(updated);

    return AiToolExecutionResult(
      toolName: 'edit_exercise',
      success: true,
      summary: 'Updated exercise "${updated.name}" in catalog (rest: ${updated.restSeconds}s, reps: ${updated.repMin}-${updated.repMax})',
      data: {'id': updated.id, 'name': updated.name},
    );
  }

  Future<AiToolExecutionResult> _executeEditSetting({
    required String key,
    required String value,
  }) async {
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    await settingsRepo.setSetting(key, value);
    return AiToolExecutionResult(
      toolName: 'edit_setting',
      success: true,
      summary: 'Updated setting "$key" to "$value".',
      data: {'key': key, 'value': value},
    );
  }

  Future<AiToolExecutionResult> _executeCalculateWarmupSets({
    required String exerciseName,
    required double targetWeight,
    double? barWeight,
    bool addToWorkout = false,
  }) async {
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final unitEnum = await settingsRepo.getWeightUnit();
    final unit = unitEnum == WeightUnit.lb ? 'lbs' : 'kg';
    final defaultBar = (unit == 'lbs') ? 45.0 : 20.0;
    final bar = barWeight ?? defaultBar;

    if (targetWeight <= bar) {
      return AiToolExecutionResult(
        toolName: 'calculate_warmup_sets',
        success: true,
        summary: 'Target weight ($targetWeight $unit) is at or below barbell weight ($bar $unit). Start directly with the empty bar for 10-15 reps.',
        data: {'targetWeight': targetWeight, 'barWeight': bar, 'unit': unit},
      );
    }

    // Plate calculation helper per side
    List<double> availablePlates = (unit == 'lbs')
        ? [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]
        : [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

    Map<double, int> calculatePlatesPerSide(double totalWeight) {
      double perSide = (totalWeight - bar) / 2.0;
      if (perSide <= 0) return {};
      final map = <double, int>{};
      for (final p in availablePlates) {
        if (perSide >= p) {
          int count = (perSide / p).floor();
          map[p] = count;
          perSide -= count * p;
        }
      }
      return map;
    }

    String formatPlates(Map<double, int> plates) {
      if (plates.isEmpty) return 'Empty Bar';
      return plates.entries.map((e) => '${e.value}x${e.key}$unit').join(' + ');
    }

    // Standard scientific ramp-up scheme:
    // Set 1: Bar x 10
    // Set 2: 50% target x 5
    // Set 3: 70% target x 3
    // Set 4: 85% target x 1-2
    final step2Weight = (targetWeight * 0.50 / 2.5).round() * 2.5;
    final step3Weight = (targetWeight * 0.70 / 2.5).round() * 2.5;
    final step4Weight = (targetWeight * 0.85 / 2.5).round() * 2.5;

    final warmupSteps = <Map<String, dynamic>>[];

    warmupSteps.add({
      'set': 1,
      'weight': bar,
      'reps': 10,
      'purpose': 'Barbell groove & joint warmup',
      'platesPerSide': 'Empty Bar',
    });

    if (step2Weight > bar) {
      final p2 = calculatePlatesPerSide(step2Weight);
      warmupSteps.add({
        'set': 2,
        'weight': step2Weight,
        'reps': 5,
        'purpose': '50% target - pattern acceleration',
        'platesPerSide': formatPlates(p2),
      });
    }

    if (step3Weight > step2Weight && step3Weight < targetWeight) {
      final p3 = calculatePlatesPerSide(step3Weight);
      warmupSteps.add({
        'set': 3,
        'weight': step3Weight,
        'reps': 3,
        'purpose': '70% target - moderate load velocity',
        'platesPerSide': formatPlates(p3),
      });
    }

    if (step4Weight > step3Weight && step4Weight < targetWeight) {
      final p4 = calculatePlatesPerSide(step4Weight);
      warmupSteps.add({
        'set': 4,
        'weight': step4Weight,
        'reps': 1,
        'purpose': '85% target - CNS potentiation (zero fatigue)',
        'platesPerSide': formatPlates(p4),
      });
    }

    final targetPlates = calculatePlatesPerSide(targetWeight);

    if (addToWorkout) {
      for (final step in warmupSteps) {
        await _executeLogSet(
          exerciseName: exerciseName,
          weight: (step['weight'] as num).toDouble(),
          reps: (step['reps'] as num).toInt(),
          setTypeStr: 'warmup',
        );
      }
    }

    final summaryBuf = StringBuffer();
    summaryBuf.writeln('Warmup Progression for $exerciseName (Target: $targetWeight $unit):');
    for (final s in warmupSteps) {
      summaryBuf.writeln('• Set ${s['set']}: ${s['weight']} $unit x ${s['reps']} reps [Plates/side: ${s['platesPerSide']}] - ${s['purpose']}');
    }
    summaryBuf.writeln('Working Set: $targetWeight $unit [Plates/side: ${formatPlates(targetPlates)}]');
    if (addToWorkout) {
      summaryBuf.writeln('Automatically added ${warmupSteps.length} warmup sets to today\'s session.');
    }

    return AiToolExecutionResult(
      toolName: 'calculate_warmup_sets',
      success: true,
      summary: summaryBuf.toString().trim(),
      data: {
        'exerciseName': exerciseName,
        'targetWeight': targetWeight,
        'targetPlatesPerSide': formatPlates(targetPlates),
        'unit': unit,
        'warmupSteps': warmupSteps,
        'addedToWorkout': addToWorkout,
      },
    );
  }

  Future<AiToolExecutionResult> _executeAnalyzeMuscleBalance({
    int days = 14,
  }) async {
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final history = await workoutRepo.getHistoryWorkouts(limit: 100);
    final cutoff = DateTime.now().subtract(Duration(days: days));

    final recentWorkouts = history.where((w) => w.date.isAfter(cutoff)).toList();

    if (recentWorkouts.isEmpty) {
      return AiToolExecutionResult(
        toolName: 'analyze_muscle_balance',
        success: true,
        summary: 'No workouts found in the last $days days to analyze muscle balance. Log more sessions to generate recovery and volume audit.',
        data: {'workoutsCount': 0, 'days': days},
      );
    }

    final muscleSets = <String, int>{};
    final muscleVolume = <String, double>{};
    int totalSets = 0;
    double totalVol = 0.0;

    for (final w in recentWorkouts) {
      for (final e in w.exercises) {
        final raw = e.exercise.muscleGroupId;
        final muscle = raw.isNotEmpty
            ? '${raw[0].toUpperCase()}${raw.substring(1).toLowerCase()}'
            : 'Other';
        for (final s in e.sets) {
          if (!s.isWarmup) {
            muscleSets[muscle] = (muscleSets[muscle] ?? 0) + 1;
            final setVol = s.weight * s.reps;
            muscleVolume[muscle] = (muscleVolume[muscle] ?? 0.0) + setVol;
            totalSets += 1;
            totalVol += setVol;
          }
        }
      }
    }

    // Push vs Pull analysis
    int pushSets = (muscleSets['Chest'] ?? 0) + (muscleSets['Triceps'] ?? 0) + (muscleSets['Shoulders'] ?? 0);
    int pullSets = (muscleSets['Back'] ?? 0) + (muscleSets['Biceps'] ?? 0);
    int legsSets = (muscleSets['Legs'] ?? 0) + (muscleSets['Glutes'] ?? 0);

    double pushPullRatio = pullSets > 0 ? (pushSets / pullSets) : pushSets.toDouble();

    final laggingMuscles = <String>[];
    for (final m in ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Legs']) {
      final count = muscleSets[m] ?? 0;
      if (count < 4) {
        laggingMuscles.add(m);
      }
    }

    final buf = StringBuffer();
    buf.writeln('Muscle Balance & Volume Audit (Past $days Days, ${recentWorkouts.length} Workouts):');
    buf.writeln('• Total Working Sets: $totalSets | Total Volume: ${totalVol.toStringAsFixed(0)}');
    buf.writeln('• Push Sets: $pushSets | Pull Sets: $pullSets (Push-to-Pull Ratio: ${pushPullRatio.toStringAsFixed(2)})');
    buf.writeln('• Lower Body Sets: $legsSets');
    buf.writeln('• Breakdown by Muscle:');
    muscleSets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..forEach((entry) {
        buf.writeln('  - ${entry.key}: ${entry.value} sets');
      });

    if (pushPullRatio > 1.35) {
      buf.writeln('Warning: High Push-to-Pull imbalance ($pushPullRatio). Add more horizontal/vertical rows or face pulls to safeguard shoulder posture.');
    } else if (pushPullRatio < 0.70 && pushSets > 0) {
      buf.writeln('Note: Pull volume significantly exceeds push volume.');
    } else {
      buf.writeln('Excellent Push-to-Pull balance (${pushPullRatio.toStringAsFixed(2)} ratio).');
    }

    if (laggingMuscles.isNotEmpty) {
      buf.writeln('Low Volume Alert: ${laggingMuscles.join(', ')} (<4 sets across $days days). Consider dedicating attention in upcoming sessions.');
    }

    return AiToolExecutionResult(
      toolName: 'analyze_muscle_balance',
      success: true,
      summary: buf.toString().trim(),
      data: {
        'days': days,
        'workoutsCount': recentWorkouts.length,
        'totalSets': totalSets,
        'totalVolume': totalVol,
        'pushSets': pushSets,
        'pullSets': pullSets,
        'pushPullRatio': pushPullRatio,
        'legsSets': legsSets,
        'breakdown': muscleSets,
        'laggingMuscles': laggingMuscles,
      },
    );
  }

  Future<AiToolExecutionResult> _executeGetExerciseTechnique({
    required String exerciseName,
    String focus = 'cues',
  }) async {
    final lower = exerciseName.toLowerCase();

    String target = 'Target Muscle Group';
    List<String> setup = [];
    List<String> execution = [];
    List<String> pitfalls = [];
    List<String> alternatives = [];

    if (lower.contains('squat')) {
      target = 'Quadriceps, Gluteus Maximus, Adductor Magnus, Spinal Erectors';
      setup = [
        'Place bar across mid-traps (high bar) or rear delts (low bar)',
        'Feet shoulder-width apart, toes flared 15-30 degrees outward',
        'Take a deep belly breath and brace 360-degree core (Valsalva maneuver)',
      ];
      execution = [
        'Break at hips and knees simultaneously; drive knees in line with toes',
        'Maintain mid-foot balance; descend until hip crease is below parallel',
        'Drive through whole foot and push upper back into the bar on the ascent',
      ];
      pitfalls = [
        'Knee cave (valgus collapse) on turnaround',
        'Good-morning squatting (hips shooting up before chest)',
        'Losing thoracic extension at the bottom',
      ];
      alternatives = ['Bulgarian Split Squat', 'Hack Squat', 'Goblet Squat', 'Leg Press'];
    } else if (lower.contains('bench') || lower.contains('chest press')) {
      target = 'Pectoralis Major (Sternal & Clavicular), Anterior Deltoid, Triceps Brachii';
      setup = [
        'Retract and depress scapulae (pinch shoulder blades together and down)',
        'Grip bar slightly outside shoulder-width; wrap thumbs around bar',
        'Plant feet flat with aggressive quad drive to anchor pelvis',
      ];
      execution = [
        'Tuck elbows at 45-60 degree angle to torso (avoid 90-degree flare)',
        'Touch lower sternum with control; 1-second pause on chest',
        'Press upward in a slight J-curve back over the shoulder joints',
      ];
      pitfalls = [
        'Flaring elbows out 90 degrees (stresses rotator cuff)',
        'Bouncing bar off ribcage',
        'Losing scapular retraction during press lockout',
      ];
      alternatives = ['Dumbbell Bench Press', 'Incline Dumbbell Press', 'Floor Press (shoulder safe)', 'Dips'];
    } else if (lower.contains('deadlift')) {
      target = 'Gluteus Maximus, Hamstrings, Erector Spinae, Latissimus Dorsi, Traps';
      setup = [
        'Bar over mid-foot (1 inch from shins); hip-width stance',
        'Hinge at hips, grip bar, pull shins to bar without moving it forward',
        'Squeeze chest up, pull slack out of the bar until it clicks',
      ];
      execution = [
        'Push the floor away with your legs like a leg press until knees clear',
        'Snap hips forward to lockout; stand tall without hyperextending spine',
        'Break at hips first on descent; let bar slide smoothly down thighs',
      ];
      pitfalls = [
        'Rounding lumbar spine during initial pull',
        'Yanking the bar without pulling slack',
        'Hyperextending lower back at the top',
      ];
      alternatives = ['Romanian Deadlift (RDL)', 'Trap Bar Deadlift', 'Barbell Hip Thrust', 'Good Mornings'];
    } else if (lower.contains('row') || lower.contains('pull')) {
      target = 'Latissimus Dorsi, Rhomboids, Middle/Lower Traps, Posterior Deltoid, Biceps';
      setup = [
        'Hinge torso 45-60 degrees with flat spine; grip bar just outside knees',
        'Depress shoulders before initiating row',
      ];
      execution = [
        'Drive elbows back toward hips rather than straight up to the ceiling',
        'Squeeze shoulder blades together at peak contraction for 1 second',
        'Control 2-3 second eccentric stretch at the bottom',
      ];
      pitfalls = [
        'Using excessive body momentum / hip heave',
        'Shrugging shoulders into ears at contraction',
      ];
      alternatives = ['Chest-Supported T-Bar Row', 'Seated Cable Row', 'One-Arm Dumbbell Row', 'Meadows Row'];
    } else {
      target = 'Primary Movers and Stabilizers';
      setup = [
        'Anchor your base of support firmly with symmetric posture',
        'Establish mind-muscle connection and brace core before initiating set',
      ];
      execution = [
        'Control 2-3 second eccentric phase (resisting gravity)',
        'Brief pause at deepest stretched position',
        'Explosive concentric phase with full intent and squeeze',
      ];
      pitfalls = [
        'Cutting range of motion to lift heavier weight',
        'Rushing the negative (eccentric) phase',
      ];
      alternatives = ['Cable variation', 'Dumbbell variation', 'Machine equivalent'];
    }

    final buf = StringBuffer();
    buf.writeln('Biomechanics & Form Cues: $exerciseName');
    buf.writeln('Target Muscles: $target\n');

    if (focus == 'cues' || focus == 'safety') {
      buf.writeln('Setup Checklist:');
      for (final s in setup) {
        buf.writeln('  • $s');
      }
      buf.writeln('\nExecution Cues:');
      for (final e in execution) {
        buf.writeln('  • $e');
      }
      buf.writeln('\nMistakes to Avoid:');
      for (final p in pitfalls) {
        buf.writeln('  • $p');
      }
    }

    if (focus == 'alternatives' || focus == 'safety') {
      buf.writeln('\nJoint-Friendly & Injury-Safe Alternatives:');
      for (final a in alternatives) {
        buf.writeln('  • $a');
      }
    }

    return AiToolExecutionResult(
      toolName: 'get_exercise_technique',
      success: true,
      summary: buf.toString().trim(),
      data: {
        'exerciseName': exerciseName,
        'targetMuscles': target,
        'setup': setup,
        'execution': execution,
        'pitfalls': pitfalls,
        'alternatives': alternatives,
      },
    );
  }

  Future<AiToolExecutionResult> _executeAskUserQuestion({
    required String question,
    required List<String> options,
    String? summary,
  }) async {
    return AiToolExecutionResult(
      toolName: 'ask_user_question',
      success: true,
      summary: summary != null && summary.isNotEmpty ? '$summary\n\n$question' : 'Asked: $question',
      data: {
        'status': 'awaiting_answer',
        'question': question,
        'options': options,
        if (summary != null && summary.isNotEmpty) 'summary': summary,
      },
    );
  }
}

