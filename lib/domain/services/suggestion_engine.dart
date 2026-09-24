import 'dart:math';
import '../models/set_model.dart';
import '../models/workout_model.dart';
import '../models/suggestion_model.dart';
import 'e1rm_calculator.dart';

abstract class SuggestionRule {
  String get ruleId;
  String get ruleName;

  List<Suggestion> evaluate({
    required WorkoutModel currentWorkout,
    required List<WorkoutModel> history,
  });
}

/// Rule 1: Progressive Overload / Hold
/// If every working set of the last session hit rep_max -> next target = top weight + weight_step at rep_min.
/// Otherwise hold the weight and target (weakest set's reps + 1, capped at rep_max).
class ProgressHoldRule implements SuggestionRule {
  @override
  String get ruleId => 'rule_1_progress_hold';

  @override
  String get ruleName => 'Progressive Overload (Double Progression)';

  @override
  List<Suggestion> evaluate({
    required WorkoutModel currentWorkout,
    required List<WorkoutModel> history,
  }) {
    final suggestions = <Suggestion>[];

    for (final item in currentWorkout.exercises) {
      if (item.archived) continue;
      final ex = item.exercise;

      // Find the most recent previous session containing this exercise
      WorkoutModel? prevWorkout;
      WorkoutExerciseItem? prevItem;

      for (final w in history) {
        if (w.id == currentWorkout.id) continue;
        final match = w.exercises.where((e) => e.exercise.id == ex.id && !e.archived).toList();
        if (match.isNotEmpty) {
          prevWorkout = w;
          prevItem = match.first;
          break;
        }
      }

      if (prevWorkout == null || prevItem == null) continue;

      final workingSets = prevItem.sets
          .where((s) => !s.archived && s.setType != SetType.warmup && s.reps > 0)
          .toList();

      if (workingSets.isEmpty) continue;

      final repMax = ex.repMax > 0 ? ex.repMax : 12;
      final repMin = ex.repMin > 0 ? ex.repMin : 8;
      final weightStep = ex.weightStep > 0 ? ex.weightStep : 2.5;

      final allHitMax = workingSets.every((s) => s.reps >= repMax);
      final topWeight = workingSets.map((s) => s.weight).reduce(max);
      final minReps = workingSets.map((s) => s.reps).reduce(min);

      if (allHitMax) {
        final nextWeight = topWeight + weightStep;
        suggestions.add(Suggestion(
          id: 'prog_${ex.id}',
          type: SuggestionType.progress,
          title: 'Target: ${nextWeight.toStringAsFixed(1)} kg × $repMin (+${weightStep.toStringAsFixed(1)} kg)',
          body: 'Hit $repMax reps on all working sets last session. Step up the weight by $weightStep kg at $repMin reps.',
          reasonCode: 'PROGRESS_OVERLOAD_STEP_UP',
          confidence: 0.95,
          ruleName: ruleName,
          explanation: '''
### Rule Logic: Double Progression Overload
1. **Condition Met**: All ${workingSets.length} working sets hit the ceiling of $repMax reps in the previous session on ${prevWorkout.date.month}/${prevWorkout.date.day}.
2. **Formula Applied**:
   - `Next Weight = Top Weight ($topWeight kg) + Weight Step ($weightStep kg) = $nextWeight kg`
   - `Target Reps = Minimum Rep Range ($repMin reps)`
3. **Previous Performance**:
${workingSets.map((s) => '   • Set ${s.setIndex}: ${s.weight} kg × ${s.reps} reps').join('\n')}
''',
          payload: {
            'exerciseId': ex.id,
            'suggestedWeight': nextWeight,
            'suggestedReps': repMin,
            'step': weightStep,
          },
        ));
      } else {
        final targetReps = min(repMax, minReps + 1);
        suggestions.add(Suggestion(
          id: 'hold_${ex.id}',
          type: SuggestionType.progress,
          title: 'Target: ${topWeight.toStringAsFixed(1)} kg × $targetReps (Rep Progression)',
          body: 'Working sets achieved min $minReps reps. Keep weight at ${topWeight.toStringAsFixed(1)} kg and aim for $targetReps reps.',
          reasonCode: 'PROGRESS_HOLD_REPS_UP',
          confidence: 0.88,
          ruleName: ruleName,
          explanation: '''
### Rule Logic: Repetition Volume Accumulation
1. **Condition Met**: Working sets have not yet all reached the $repMax rep threshold (weakest set was $minReps reps).
2. **Formula Applied**:
   - `Target Weight = Hold Top Weight ($topWeight kg)`
   - `Target Reps = min($repMax, weakest reps ($minReps) + 1) = $targetReps reps`
3. **Previous Performance**:
${workingSets.map((s) => '   • Set ${s.setIndex}: ${s.weight} kg × ${s.reps} reps').join('\n')}
''',
          payload: {
            'exerciseId': ex.id,
            'suggestedWeight': topWeight,
            'suggestedReps': targetReps,
          },
        ));
      }
    }

    return suggestions;
  }
}

/// Rule 2: Stall Detection
/// e1RM (Epley: w * (1 + reps/30)) improved less than 1% across the last 3 sessions
/// -> offer deload -10%, a rep-range change, or a variation swap.
class StallRule implements SuggestionRule {
  @override
  String get ruleId => 'rule_2_stall';

  @override
  String get ruleName => 'Stall & Plateau Detection';

  @override
  List<Suggestion> evaluate({
    required WorkoutModel currentWorkout,
    required List<WorkoutModel> history,
  }) {
    final suggestions = <Suggestion>[];

    for (final item in currentWorkout.exercises) {
      if (item.archived) continue;
      final ex = item.exercise;

      // Collect last 3 sessions for this exercise in history
      final sessionE1rms = <double>[];
      final sessionTopWeights = <double>[];

      for (final w in history) {
        if (w.id == currentWorkout.id) continue;
        final match = w.exercises.where((e) => e.exercise.id == ex.id && !e.archived).toList();
        if (match.isNotEmpty) {
          final workingSets = match.first.sets
              .where((s) => !s.archived && s.setType != SetType.warmup && s.reps > 0)
              .toList();
          if (workingSets.isNotEmpty) {
            double bestE1rm = 0;
            double topW = 0;
            for (final s in workingSets) {
              final e1 = E1rmCalculator.calculate(s.weight, s.reps);
              if (e1 > bestE1rm) bestE1rm = e1;
              if (s.weight > topW) topW = s.weight;
            }
            sessionE1rms.add(bestE1rm);
            sessionTopWeights.add(topW);
            if (sessionE1rms.length == 3) break;
          }
        }
      }

      if (sessionE1rms.length == 3) {
        // sessionE1rms is [newest, middle, oldest]
        final oldestE1rm = sessionE1rms[2];
        final newestE1rm = sessionE1rms[0];

        if (oldestE1rm > 0) {
          final improvement = (newestE1rm - oldestE1rm) / oldestE1rm;
          if (improvement < 0.01) {
            final deloadWeight = (sessionTopWeights[0] * 0.90).roundToDouble();
            suggestions.add(Suggestion(
              id: 'stall_${ex.id}',
              type: SuggestionType.stall,
              title: 'Plateau Detected: Deload to $deloadWeight kg or Swap Variation',
              body: 'Est. 1RM gained only ${(improvement * 100).toStringAsFixed(1)}% over 3 sessions. Reset fatigue with a 10% deload or swap exercise.',
              reasonCode: 'STALL_PLATEAU_DELOAD',
              confidence: 0.92,
              ruleName: ruleName,
              explanation: '''
### Rule Logic: 3-Session Epley e1RM Plateau
1. **Condition Met**: Improvement across last 3 sessions is ${(improvement * 100).toStringAsFixed(1)}% (< 1.0% threshold).
2. **Session History**:
   - 3 Sessions Ago: ${oldestE1rm.toStringAsFixed(1)} kg e1RM
   - 2 Sessions Ago: ${sessionE1rms[1].toStringAsFixed(1)} kg e1RM
   - Last Session: ${newestE1rm.toStringAsFixed(1)} kg e1RM
3. **Recommended Action**: Deload working weight by 10% to $deloadWeight kg or alter the rep range to allow neuromuscular adaptation.
''',
              payload: {
                'exerciseId': ex.id,
                'deloadWeight': deloadWeight,
                'improvement': improvement,
              },
            ));
          }
        }
      }
    }

    return suggestions;
  }
}

/// Rule 3: Intra-Session Fatigue
/// (first working set reps - last working set reps) / first > 0.4
/// -> suggest more rest or lower weight.
class FatigueRule implements SuggestionRule {
  @override
  String get ruleId => 'rule_3_fatigue';

  @override
  String get ruleName => 'Intra-Session Fatigue Monitor';

  @override
  List<Suggestion> evaluate({
    required WorkoutModel currentWorkout,
    required List<WorkoutModel> history,
  }) {
    final suggestions = <Suggestion>[];

    for (final item in currentWorkout.exercises) {
      if (item.archived) continue;
      final activeWorkingSets = item.sets
          .where((s) => !s.archived && s.setType != SetType.warmup && s.reps > 0)
          .toList();

      if (activeWorkingSets.length >= 2) {
        final firstReps = activeWorkingSets.first.reps;
        final lastReps = activeWorkingSets.last.reps;

        if (firstReps > 0) {
          final dropOff = (firstReps - lastReps) / firstReps;
          if (dropOff > 0.4) {
            suggestions.add(Suggestion(
              id: 'fatigue_${item.exercise.id}',
              type: SuggestionType.fatigue,
              title: 'High Fatigue Drop: Rest +60s or Reduce Weight',
              body: 'Reps dropped ${(dropOff * 100).toStringAsFixed(0)}% from Set 1 ($firstReps reps) to Set ${activeWorkingSets.length} ($lastReps reps).',
              reasonCode: 'INTRA_SESSION_FATIGUE_DROP',
              confidence: 0.90,
              ruleName: ruleName,
              explanation: '''
### Rule Logic: Intra-Session Neuromuscular Drop-off
1. **Condition Met**: Rep decrease is ${(dropOff * 100).toStringAsFixed(0)}% (> 40% threshold).
2. **Current Sets**:
   - Set 1: ${activeWorkingSets.first.weight} kg × $firstReps reps
   - Set ${activeWorkingSets.length}: ${activeWorkingSets.last.weight} kg × $lastReps reps
3. **Recommendation**: Take an extra 60s of rest before the next set, or lower the weight by 5-10% to prevent junk volume.
''',
              payload: {
                'exerciseId': item.exercise.id,
                'dropOff': dropOff,
              },
            ));
          }
        }
      }
    }

    return suggestions;
  }
}

/// Rule 4: Comeback Protocol
/// 14+ days since the exercise was last logged -> start at 90% of the last top weight.
class ComebackRule implements SuggestionRule {
  @override
  String get ruleId => 'rule_4_comeback';

  @override
  String get ruleName => 'Comeback Detraining Protocol';

  @override
  List<Suggestion> evaluate({
    required WorkoutModel currentWorkout,
    required List<WorkoutModel> history,
  }) {
    final suggestions = <Suggestion>[];

    for (final item in currentWorkout.exercises) {
      if (item.archived) continue;
      final ex = item.exercise;

      WorkoutModel? lastWorkout;
      WorkoutExerciseItem? lastItem;

      for (final w in history) {
        if (w.id == currentWorkout.id) continue;
        final match = w.exercises.where((e) => e.exercise.id == ex.id && !e.archived).toList();
        if (match.isNotEmpty) {
          lastWorkout = w;
          lastItem = match.first;
          break;
        }
      }

      if (lastWorkout != null && lastItem != null) {
        final days = currentWorkout.date.difference(lastWorkout.date).inDays;
        if (days >= 14) {
          final workingSets = lastItem.sets.where((s) => !s.archived && s.setType != SetType.warmup).toList();
          if (workingSets.isNotEmpty) {
            final lastTopWeight = workingSets.map((s) => s.weight).reduce(max);
            final targetWeight = (lastTopWeight * 0.90).roundToDouble();

            suggestions.add(Suggestion(
              id: 'comeback_${ex.id}',
              type: SuggestionType.comeback,
              title: 'Comeback Target: $targetWeight kg (90% Load)',
              body: 'Last trained $days days ago. Starting at 90% avoids excessive soreness and recalibrates motor patterns.',
              reasonCode: 'COMEBACK_DETRAINING_RESET',
              confidence: 0.93,
              ruleName: ruleName,
              explanation: '''
### Rule Logic: 14+ Day Detraining Safety Buffer
1. **Condition Met**: $days days have elapsed since ${ex.name} was last logged on ${lastWorkout.date.month}/${lastWorkout.date.day}.
2. **Formula**: `Target = 90% of previous top weight ($lastTopWeight kg) = $targetWeight kg`.
3. **Rationale**: Neurological motor efficiency drops slightly after 2 weeks of disuse; starting at 90% preserves tendon health and prevents debilitating DOMS.
''',
              payload: {
                'exerciseId': ex.id,
                'targetWeight': targetWeight,
                'daysSince': days,
              },
            ));
          }
        }
      }
    }

    return suggestions;
  }
}

/// Rule 5: Weekly Volume Balance
/// Weekly (Mon-Sun) working sets per muscle group vs target (default 10-16) -> flag under/over-trained groups.
class BalanceRule implements SuggestionRule {
  final int minTarget;
  final int maxTarget;

  BalanceRule({this.minTarget = 10, this.maxTarget = 16});

  @override
  String get ruleId => 'rule_5_balance';

  @override
  String get ruleName => 'Weekly Volume Balance';

  @override
  List<Suggestion> evaluate({
    required WorkoutModel currentWorkout,
    required List<WorkoutModel> history,
  }) {
    final suggestions = <Suggestion>[];

    // Determine current week window (Monday to Sunday)
    final now = currentWorkout.date;
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd = weekStart.add(const Duration(days: 7));

    // Aggregate sets per muscle group in current week
    final groupSetCount = <String, int>{};

    final allWorkouts = [currentWorkout, ...history];
    for (final w in allWorkouts) {
      if (w.date.isBefore(weekStart) || w.date.isAfter(weekEnd)) continue;
      for (final item in w.exercises) {
        if (item.archived) continue;
        final mgId = item.exercise.muscleGroupId;
        final workingSets = item.sets.where((s) => !s.archived && s.setType != SetType.warmup).length;
        groupSetCount[mgId] = (groupSetCount[mgId] ?? 0) + workingSets;
      }
    }

    groupSetCount.forEach((mgId, count) {
      if (count < minTarget && now.weekday >= 4) {
        // Late in week and still under target
        suggestions.add(Suggestion(
          id: 'balance_under_$mgId',
          type: SuggestionType.balance,
          title: 'Volume Deficit: ${mgId.toUpperCase()} ($count / $minTarget sets)',
          body: '${mgId.toUpperCase()} has completed $count sets this week (target: $minTarget–$maxTarget). Consider adding sets today.',
          reasonCode: 'WEEKLY_VOLUME_DEFICIT',
          confidence: 0.85,
          ruleName: ruleName,
          explanation: '''
### Rule Logic: Weekly Volume Landmark
1. **Condition Met**: Muscle group $mgId has $count sets (target minimum is $minTarget).
2. **Weekly Window**: ${weekStart.month}/${weekStart.day} to ${weekEnd.month}/${weekEnd.day}.
3. **Action**: Target 2-4 additional sets this session to reach optimal hypertrophy stimulus.
''',
          payload: {'muscleGroupId': mgId, 'currentSets': count, 'targetMin': minTarget},
        ));
      } else if (count > maxTarget + 4) {
        suggestions.add(Suggestion(
          id: 'balance_over_$mgId',
          type: SuggestionType.balance,
          title: 'High Fatigue Volume: ${mgId.toUpperCase()} ($count sets)',
          body: '${mgId.toUpperCase()} exceeded optimal volume ($count > $maxTarget). Further sets may cause diminished returns.',
          reasonCode: 'WEEKLY_VOLUME_EXCESS',
          confidence: 0.82,
          ruleName: ruleName,
          explanation: '''
### Rule Logic: Maximum Recoverable Volume (MRV)
1. **Condition Met**: $count sets completed exceeds the $maxTarget set ceiling.
2. **Recommendation**: Focus on other muscle groups today to allow systemic recovery.
''',
          payload: {'muscleGroupId': mgId, 'currentSets': count, 'targetMax': maxTarget},
        ));
      }
    });

    return suggestions;
  }
}

/// Rule 6: Next Workout Recommendation
/// Ranks muscle groups by days since last trained + weekly set deficit - recent volume;
/// proposes 2-3 groups with their usual exercises.
class NextWorkoutRule implements SuggestionRule {
  @override
  String get ruleId => 'rule_6_next_workout';

  @override
  String get ruleName => 'Next Workout Recommendation';

  @override
  List<Suggestion> evaluate({
    required WorkoutModel currentWorkout,
    required List<WorkoutModel> history,
  }) {
    // Only recommend next workout if today's workout has no active exercises yet!
    final activeExercises = currentWorkout.exercises.where((e) => !e.archived).toList();
    if (activeExercises.isNotEmpty) return [];

    final muscleGroups = ['chest', 'back', 'legs', 'shoulders', 'biceps', 'triceps'];
    final scores = <String, double>{};
    final lastTrainedDays = <String, int>{};

    for (final mg in muscleGroups) {
      int daysSince = 7; // default if not found
      for (final w in history) {
        final match = w.exercises.where((e) => e.exercise.muscleGroupId == mg && !e.archived).toList();
        if (match.isNotEmpty) {
          daysSince = currentWorkout.date.difference(w.date).inDays;
          break;
        }
      }
      lastTrainedDays[mg] = daysSince;
      // Score = days since last trained * 2.0 (higher means needs training)
      scores[mg] = daysSince * 2.0;
    }

    // Determine best split: Push (chest/shoulders/triceps), Pull (back/biceps), Legs (legs/glutes)
    final pushScore = (scores['chest'] ?? 0) + (scores['shoulders'] ?? 0) + (scores['triceps'] ?? 0);
    final pullScore = (scores['back'] ?? 0) + (scores['biceps'] ?? 0);
    final legsScore = (scores['legs'] ?? 0) * 1.8;

    String recommendedRoutineName;
    String description;
    String routineKey;
    List<String> targetGroups;

    if (pushScore >= pullScore && pushScore >= legsScore) {
      recommendedRoutineName = 'Push Hypertrophy (Chest • Shoulders • Triceps)';
      routineKey = 'push_a';
      targetGroups = ['Chest', 'Shoulders', 'Triceps'];
      final days = lastTrainedDays['chest'] ?? 4;
      description = 'Chest and Triceps have rested $days days and are fully recovered. High neuromuscular readiness.';
    } else if (pullScore >= legsScore) {
      recommendedRoutineName = 'Pull Power & Lats (Back • Biceps)';
      routineKey = 'pull_a';
      targetGroups = ['Back', 'Biceps'];
      final days = lastTrainedDays['back'] ?? 4;
      description = 'Back and Biceps have rested $days days. Ready to attack vertical & horizontal pulls.';
    } else {
      recommendedRoutineName = 'Legs & Core (Quads • Hamstrings • Calves)';
      routineKey = 'legs_a';
      targetGroups = ['Legs', 'Glutes', 'Core'];
      final days = lastTrainedDays['legs'] ?? 5;
      description = 'Lower body has rested $days days. Quad and posterior chain recovery is optimal.';
    }

    return [
      Suggestion(
        id: 'next_workout_suggestion',
        type: SuggestionType.nextWorkout,
        title: 'Suggested Workout: $recommendedRoutineName',
        body: description,
        reasonCode: 'NEXT_WORKOUT_OPTIMAL_CADENCE',
        confidence: 0.94,
        ruleName: ruleName,
        actionLabel: 'Start Routine (1-Tap)',
        explanation: '''
### Rule Logic: Recovery & Cadence Optimization
1. **Scoring Algorithm**: Muscle groups are ranked based on `days_since_last_trained × cadence_weight`.
2. **Recovery Status**:
   - Push Cadence: Chest (${lastTrainedDays['chest']}d), Shoulders (${lastTrainedDays['shoulders']}d), Triceps (${lastTrainedDays['triceps']}d) -> Score: ${pushScore.toStringAsFixed(1)}
   - Pull Cadence: Back (${lastTrainedDays['back']}d), Biceps (${lastTrainedDays['biceps']}d) -> Score: ${pullScore.toStringAsFixed(1)}
   - Legs Cadence: Legs (${lastTrainedDays['legs']}d) -> Score: ${legsScore.toStringAsFixed(1)}
3. **Recommendation**: Launching $recommendedRoutineName ensures balanced weekly hypertrophy without overtraining.
''',
        payload: {
          'routineKey': routineKey,
          'targetGroups': targetGroups,
        },
      ),
    ];
  }
}

/// Rule 7: Training Reminders / Habit Cadence
/// Analyzes median start time and preferred weekdays from past 10 sessions.
class ReminderRule implements SuggestionRule {
  @override
  String get ruleId => 'rule_7_reminders';

  @override
  String get ruleName => 'Habit & Timing Cadence';

  @override
  List<Suggestion> evaluate({
    required WorkoutModel currentWorkout,
    required List<WorkoutModel> history,
  }) {
    if (history.length < 3) return [];

    final recentWorkouts = history.take(10).toList();
    final startHours = <int>[];
    for (final w in recentWorkouts) {
      if (w.startedAt != null) {
        startHours.add(w.startedAt!.hour);
      }
    }

    if (startHours.isEmpty) return [];
    startHours.sort();
    final medianHour = startHours[startHours.length ~/ 2];
    final period = medianHour >= 12 ? 'PM' : 'AM';
    final displayHour = medianHour > 12 ? medianHour - 12 : (medianHour == 0 ? 12 : medianHour);

    return [
      Suggestion(
        id: 'reminder_cadence',
        type: SuggestionType.progress,
        title: 'Usual Training Window: $displayHour:00 $period',
        body: 'Based on your last ${recentWorkouts.length} sessions, your peak consistency occurs around $displayHour:00 $period.',
        reasonCode: 'HABIT_MEDIAN_HOUR_DETECTED',
        confidence: 0.80,
        ruleName: ruleName,
        explanation: '''
### Habit Cadence Analysis
- Analyzed ${recentWorkouts.length} sessions.
- Median workout start time is $displayHour:00 $period.
''',
        payload: {'medianHour': medianHour},
      ),
    ];
  }
}

/// SuggestionEngine orchestrator that runs all registered rules
class SuggestionEngine {
  final List<SuggestionRule> rules;

  SuggestionEngine({List<SuggestionRule>? customRules})
      : rules = customRules ??
            [
              ProgressHoldRule(),
              StallRule(),
              FatigueRule(),
              ComebackRule(),
              BalanceRule(),
              NextWorkoutRule(),
              ReminderRule(),
            ];

  List<Suggestion> evaluateAll({
    required WorkoutModel currentWorkout,
    required List<WorkoutModel> history,
  }) {
    final allSuggestions = <Suggestion>[];
    for (final rule in rules) {
      try {
        final results = rule.evaluate(
          currentWorkout: currentWorkout,
          history: history,
        );
        allSuggestions.addAll(results);
      } catch (_) {
        // Individual rule failure should not crash the engine
      }
    }
    return allSuggestions;
  }
}
