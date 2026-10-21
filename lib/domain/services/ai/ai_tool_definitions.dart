/// Static OpenAI tool function definitions for Agnes AI coach.
class AiToolDefinitions {
  AiToolDefinitions._();

  static List<Map<String, dynamic>> get all => [
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
            'description': 'Log a completed set into the workout session (today or a past date). Supports standard lifting (weight & reps), bodyweight exercises (pushups, pullups, dips, crunches - weight defaults to 0.0 unless weighted), timed isometric holds (planks, wall sits, dead hangs - reps or durationSeconds represents duration in seconds), and sports/games (football, basketball, boxing, running - reps or durationMinutes represents duration in minutes). Automatically creates the exercise if not found in catalog.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise or sport/game (e.g., Bench Press, Squat, Push-up, Plank, Football, Basketball, Running).',
                },
                'weight': {
                  'type': 'number',
                  'description': 'Weight used for the set in the current unit (kg or lbs). For bodyweight, timed holds, and sports/games, set to 0.0 unless extra added load was used (e.g. +10kg weighted dips). Defaults to 0.0.',
                },
                'reps': {
                  'type': 'integer',
                  'description': 'Number of repetitions completed. For timed isometric holds (Planks, Wall Sits), this is duration in seconds. For sports and games (Football, Basketball, Boxing), this is duration in minutes.',
                },
                'durationSeconds': {
                  'type': 'integer',
                  'description': 'Optional hold duration in seconds for isometric holds like Planks, Wall Sits, or Dead Hangs.',
                },
                'durationMinutes': {
                  'type': 'integer',
                  'description': 'Optional duration in minutes for sports, games, and cardio activities (Football, Running, Basketball).',
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
              'required': ['exerciseName'],
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
            'name': 'preview_preset',
            'description': 'Show an interactive visual preview card of a proposed routine or preset to the user. Use this whenever the user asks for a workout split, routine recommendation, preset creation, or asks to adjust/modify a routine. The interactive preview lets the user inspect the routine, tap to import it to their library, start the session immediately, or ask for changes.',
            'parameters': {
              'type': 'object',
              'properties': {
                'title': {
                  'type': 'string',
                  'description': 'Title of the routine (e.g. "Chest & Triceps Hypertrophy", "3-Day Full Body").',
                },
                'description': {
                  'type': 'string',
                  'description': 'Short description of goals, target muscles, and recommendations.',
                },
                'category': {
                  'type': 'string',
                  'description': 'Category of the routine (e.g., Push, Pull, Legs, Upper, Lower, Full Body).',
                },
                'exercises': {
                  'type': 'array',
                  'description': 'List of exercises in the routine.',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'name': {'type': 'string', 'description': 'Exercise name.'},
                      'targetSets': {'type': 'integer', 'description': 'Target number of sets (e.g., 3 or 4).'},
                      'targetReps': {'type': 'string', 'description': 'Target rep range (e.g., "8-10", "10-12").'},
                      'restSeconds': {'type': 'integer', 'description': 'Rest period in seconds (e.g. 90, 120).'},
                      'notes': {'type': 'string', 'description': 'Form cue, superset tip, or intensity technique.'},
                    },
                    'required': ['name'],
                  },
                },
              },
              'required': ['title', 'exercises'],
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
        {
          'type': 'function',
          'function': {
            'name': 'save_user_memory',
            'description': 'Save a key, lasting fact, physical condition, injury, equipment constraint, long-term goal, or preference about the user to long-term memory across sessions. Only call this when the user reveals lasting personal details (e.g. injuries, available equipment, target goals, schedule constraints, training preferences). Do NOT save temporary single-session workout logs or small talk.',
            'parameters': {
              'type': 'object',
              'properties': {
                'fact': {
                  'type': 'string',
                  'description': 'The concise fact or preference to remember (e.g. "Left rotator cuff impingement - needs warmups before pressing", "Home gym with dumbbells up to 32kg", "Aiming for 100kg bench press").',
                },
                'category': {
                  'type': 'string',
                  'description': 'Optional category: "injury", "goal", "equipment", "preference", "schedule", or "general".',
                },
              },
              'required': ['fact'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'delete_user_memory',
            'description': 'Delete a previously saved memory by its ID or keyword when the user asks to forget or remove a remembered fact.',
            'parameters': {
              'type': 'object',
              'properties': {
                'memoryId': {
                  'type': 'string',
                  'description': 'The ID of the memory to delete (e.g. "mem_1727371200"), or the keyword/phrase to forget.',
                },
              },
              'required': ['memoryId'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'get_exercise_image',
            'description': 'Search for high-quality demonstration form images of a specific exercise or workout movement. Returns image URLs to embed inline into your explanation using markdown `![Exercise Form](url)`. Call this whenever explaining how to do an exercise or giving form cues.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise (e.g. "Bulgarian Split Squat", "Incline Dumbbell Press", "Romanian Deadlift").',
                },
              },
              'required': ['exerciseName'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'quick_exercise_guide',
            'description': 'Ultra-fast instant exercise guide with zero lag. Retrieves muscle groups worked, equipment, step-by-step form cues, common pitfalls, and verified demonstration image in a single instant response.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise (e.g. "Barbell Bench Press", "Romanian Deadlift", "Lat Pulldown").',
                },
              },
              'required': ['exerciseName'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'calculate_1rm_and_plates',
            'description': 'Calculate estimated One-Rep Max (1RM) using Epley & Brzycki scientific formulas, generate training percentage loads (60% to 95%), and determine exact barbell plate combinations per side for any target load.',
            'parameters': {
              'type': 'object',
              'properties': {
                'weight': {
                  'type': 'number',
                  'description': 'Weight lifted (in kg or lbs).',
                },
                'reps': {
                  'type': 'integer',
                  'description': 'Number of reps completed (e.g. 5, 8, 10).',
                },
                'targetWeight': {
                  'type': 'number',
                  'description': 'Optional specific target load to calculate plate loading for (defaults to calculated 1RM).',
                },
                'isLb': {
                  'type': 'boolean',
                  'description': 'Whether the athlete uses pounds (lbs). Defaults to false (kg).',
                },
              },
              'required': ['weight', 'reps'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'search_exercise_catalog',
            'description': 'Fast search across the 1,400+ exercise library by muscle group, equipment type, or search keyword. Returns matched exercises with equipment, target muscle, and tracking mode.',
            'parameters': {
              'type': 'object',
              'properties': {
                'query': {
                  'type': 'string',
                  'description': 'Search keyword (e.g., "incline", "pulldown", "curl", "squat").',
                },
                'muscleGroupId': {
                  'type': 'string',
                  'description': 'Filter by target muscle group (e.g., chest, back, shoulders, arms, legs, core, cardio).',
                },
                'equipment': {
                  'type': 'string',
                  'description': 'Filter by equipment type (e.g., barbell, dumbbell, cable, machine, bodyweight).',
                },
                'limit': {
                  'type': 'integer',
                  'description': 'Maximum number of exercises to return (default 8).',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'get_nutrition_overview',
            'description': 'Retrieve today\'s (or past date\'s) nutrition summary, including total calories consumed, protein (g), carbs (g), fat (g), water intake (ml), and AI-calculated targets based on the user\'s workout and goals.',
            'parameters': {
              'type': 'object',
              'properties': {
                'date': {
                  'type': 'string',
                  'description': 'Date to query (e.g., "today", "yesterday", or "YYYY-MM-DD"). Defaults to today.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'get_multiple_exercise_images',
            'description': 'Retrieve demonstration visuals, equipment details, and muscle targets for multiple exercises simultaneously in a single fast parallel batch call. Call this whenever recommending or explaining 2 or more exercises so all visuals load together in one go.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseNames': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'List of exercise names (e.g. ["Barbell Bench Press", "Incline Dumbbell Press", "Dips", "Cable Flyes"]).',
                },
              },
              'required': ['exerciseNames'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'render_visual_diagram',
            'description': 'Render an interactive visual flowchart, routine roadmap, periodization timeline, or decision tree in the chat. Use this to visually walk the athlete through workout order, split layout, warm-up flow, or plateau breakthroughs.',
            'parameters': {
              'type': 'object',
              'properties': {
                'title': {
                  'type': 'string',
                  'description': 'Title of the diagram (e.g. "Push Day Execution Flow", "Plateau Breakthrough Decision Tree").',
                },
                'diagramType': {
                  'type': 'string',
                  'enum': ['flowchart', 'timeline', 'decision_tree', 'split_overview'],
                  'description': 'Category of visual diagram.',
                },
                'summary': {
                  'type': 'string',
                  'description': 'Brief coach explanation of the diagram.',
                },
                'nodes': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'id': {'type': 'string', 'description': 'Unique node identifier (e.g. "1", "2")'},
                      'label': {'type': 'string', 'description': 'Step or exercise name'},
                      'phase': {'type': 'string', 'description': 'Phase badge: Warm-up, Compound, Accessory, Finisher, Rest, Decision'},
                      'description': {'type': 'string', 'description': 'Sets x reps, key cues, or decision branches'},
                      'next': {
                        'type': 'array',
                        'items': {'type': 'string'},
                        'description': 'Next connected node IDs in the sequence',
                      },
                    },
                    'required': ['id', 'label'],
                  },
                  'description': 'Ordered nodes and connections in the diagram.',
                },
                'mermaidCode': {
                  'type': 'string',
                  'description': 'Optional raw Mermaid.js graph definition (e.g. "graph TD\\nA[Dynamic Warm-up] --> B[Bench Press 4x6]\\nB --> C[Incline DB Press 3x10]").',
                },
              },
              'required': ['title', 'nodes'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'render_progression_chart',
            'description': 'Render an interactive visual line or bar progression chart in the chat. Use this to visually illustrate strength progression, load forecasts over weeks, volume accumulation, or rep-max trends.',
            'parameters': {
              'type': 'object',
              'properties': {
                'title': {
                  'type': 'string',
                  'description': 'Title of the chart (e.g. "Bench Press 8-Week Linear Progression Forecast").',
                },
                'chartType': {
                  'type': 'string',
                  'enum': ['line', 'bar'],
                  'description': 'Type of chart.',
                },
                'unit': {
                  'type': 'string',
                  'description': 'Unit of measurement (e.g. "kg", "lbs", "sets", "reps").',
                },
                'summary': {
                  'type': 'string',
                  'description': 'Coach takeaway or interpretation of the graph.',
                },
                'dataPoints': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'label': {'type': 'string', 'description': 'X-axis label (e.g. "W1", "W2", "W3", "Day 1")'},
                      'value': {'type': 'number', 'description': 'Y-axis value (e.g. 70.0, 72.5, 75.0)'},
                      'note': {'type': 'string', 'description': 'Optional milestone note'},
                    },
                    'required': ['label', 'value'],
                  },
                  'description': 'Ordered list of data points to plot.',
                },
              },
              'required': ['title', 'dataPoints'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'visualize_pr_history',
            'description': 'Render an interactive Personal Record (PR) milestone showcase card in the chat. Displays all-time max weight PR, estimated 1RM, rep PR ladder (3RM, 5RM, 8RM), volume PRs, and an interactive strength progression curve over time for specific exercises or overall training.',
            'parameters': {
              'type': 'object',
              'properties': {
                'exerciseName': {
                  'type': 'string',
                  'description': 'Name of the exercise to display PR milestones for (e.g., "Barbell Bench Press", "Barbell Squat", "Conventional Deadlift"). If omitted, displays recent all-time PR records across all exercises.',
                },
                'summary': {
                  'type': 'string',
                  'description': 'Coach takeaway or highlight message about the PR milestone.',
                },
              },
            },
          },
        },
      ];
}
