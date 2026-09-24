import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../domain/models/active_workout_input.dart';
import '../../../../domain/services/weight_step_learner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../../data/providers.dart';
import '../../../../domain/models/set_model.dart';
import '../../../../domain/models/workout_model.dart';
import '../../../../domain/models/suggestion_model.dart';
import '../../../../domain/services/pr_detector.dart';
import '../rename_exercise_dialog.dart';
import '../warmup_calculator_sheet.dart';
import '../suggestion_explain_sheet.dart';
import '../set_entry_sheet.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import 'exercise_visual_thumbnail.dart';
import 'exercise_guide_sheet.dart';
import 'plate_calculator_sheet.dart';
import '../../../../domain/services/e1rm_calculator.dart';

class ExerciseTableCard extends ConsumerStatefulWidget {
  final WorkoutExerciseItem item;
  final WeightUnit unit;
  final Suggestion? suggestion;
  final VoidCallback onRefresh;
  final Function(PrResult pr) onPrAchieved;
  final VoidCallback onRemoveExercise;

  const ExerciseTableCard({
    super.key,
    required this.item,
    required this.unit,
    this.suggestion,
    required this.onRefresh,
    required this.onPrAchieved,
    required this.onRemoveExercise,
  });

  static void setExerciseExpanded(String id, bool expanded) {
    _ExerciseTableCardState.setExerciseExpanded(id, expanded);
  }

  @override
  ConsumerState<ExerciseTableCard> createState() => _ExerciseTableCardState();
}

class _ExerciseTableCardState extends ConsumerState<ExerciseTableCard> {
  static final Map<String, bool> _expandedCache = <String, bool>{};

  List<SetModel> _prevSets = [];
  double? _customNextWeight;
  int? _customNextReps;

  int? _customPlannedCount;
  final Map<int, double> _customGhostWeights = {};
  final Map<int, int> _customGhostReps = {};
  final Map<int, SetType> _customGhostTypes = {};

  final Set<String> _locallyDeletedCompletedSetIds = <String>{};
  final List<String> _plannedSetKeys = [];
  int _plannedKeySeq = 0;

  List<SetModel> get _currentActiveSets {
    return widget.item.sets
        .where((s) => !s.archived && !_locallyDeletedCompletedSetIds.contains(s.id))
        .toList();
  }

  int get _effectivePlannedCount {
    final activeSets = _currentActiveSets;
    final loggedCount = activeSets.length;
    if (_customPlannedCount != null) {
      return math.max(loggedCount, _customPlannedCount!);
    }
    final baseline = _prevSets.isNotEmpty ? _prevSets.length : 3;
    return math.max(loggedCount + 1, baseline);
  }

  double _getTargetWeightForSet(int setIndex, double fallback) {
    if (_customGhostWeights.containsKey(setIndex)) {
      return _customGhostWeights[setIndex]!;
    }
    if ((setIndex - 1) < _prevSets.length) {
      return _prevSets[setIndex - 1].weight;
    }
    final activeSets = _currentActiveSets;
    if (activeSets.isNotEmpty) {
      return activeSets.last.weight;
    }
    if (widget.suggestion != null) {
      final sw = widget.suggestion!.payload['suggestedWeight'] as num?;
      if (sw != null && sw > 0) return sw.toDouble();
    }
    return fallback > 0 ? fallback : (widget.item.exercise.equipment == EquipmentType.barbell ? 20.0 : 0.0);
  }

  int _getTargetRepsForSet(int setIndex, int fallback) {
    if (_customGhostReps.containsKey(setIndex)) {
      return _customGhostReps[setIndex]!;
    }
    if ((setIndex - 1) < _prevSets.length) {
      return _prevSets[setIndex - 1].reps;
    }
    final activeSets = _currentActiveSets;
    if (activeSets.isNotEmpty) {
      return activeSets.last.reps;
    }
    if (widget.suggestion != null) {
      final sr = widget.suggestion!.payload['suggestedReps'] as num?;
      if (sr != null && sr > 0) return sr.toInt();
    }
    return fallback > 0 ? fallback : widget.item.exercise.repMin;
  }

  SetType _getTargetTypeForSet(int setIndex) {
    if (_customGhostTypes.containsKey(setIndex)) {
      return _customGhostTypes[setIndex]!;
    }
    if (setIndex == 1 && widget.item.maxWeight > 0) {
      final w = _getTargetWeightForSet(1, 0.0);
      if (w > 0 && w <= widget.item.maxWeight * 0.8) {
        return SetType.warmup;
      }
    }
    return SetType.working;
  }

  Future<void> _cycleCompletedSetType(SetModel s) async {
    AppHaptics.selection();
    final nextType = switch (s.setType) {
      SetType.working => SetType.warmup,
      SetType.warmup => SetType.drop,
      SetType.drop => SetType.failure,
      SetType.failure => SetType.working,
    };
    final repo = ref.read(workoutRepositoryProvider);
    await repo.updateSet(
      setId: s.id,
      weight: s.weight,
      reps: s.reps,
      setType: nextType,
      rpe: s.rpe,
    );
    widget.onRefresh();
  }

  void _cyclePlannedSetType(int setIndex) {
    AppHaptics.selection();
    final current = _getTargetTypeForSet(setIndex);
    final nextType = switch (current) {
      SetType.working => SetType.warmup,
      SetType.warmup => SetType.drop,
      SetType.drop => SetType.failure,
      SetType.failure => SetType.working,
    };
    setState(() {
      _customGhostTypes[setIndex] = nextType;
    });
  }

  String get _cacheKey => widget.item.id.isNotEmpty ? widget.item.id : widget.item.exercise.id;

  bool get _isExpanded => _expandedCache[_cacheKey] ?? false;

  void _setExpanded(bool expanded) {
    setState(() {
      _expandedCache[_cacheKey] = expanded;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('ex_expanded_$_cacheKey', expanded);
    }).catchError((_) {});
  }

  Future<void> _loadExpandedState() async {
    if (_expandedCache.containsKey(_cacheKey)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('ex_expanded_$_cacheKey');
      if (saved != null) {
        if (mounted) {
          setState(() {
            _expandedCache[_cacheKey] = saved;
          });
        } else {
          _expandedCache[_cacheKey] = saved;
        }
      }
    } catch (_) {}
  }

  static void setExerciseExpanded(String id, bool expanded) {
    _expandedCache[id] = expanded;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('ex_expanded_$id', expanded);
    }).catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    _loadPreviousPerformance();
    _loadExpandedState();
  }

  Future<void> _loadPreviousPerformance() async {
    final repo = ref.read(workoutRepositoryProvider);
    final prev = await repo.getPreviousSetsForExercise(widget.item.exercise.id);
    if (mounted) {
      setState(() {
        _prevSets = prev;
      });
    }
  }

  // 1-Tap Log a new set using ghost/target values
  Future<void> _quickLogSet({
    required double weight,
    required int reps,
    required SetType setType,
  }) async {
    AppHaptics.tap();
    final repo = ref.read(workoutRepositoryProvider);

    final newSetId = await repo.logSet(
      workoutExerciseId: widget.item.id,
      exerciseId: widget.item.exercise.id,
      muscleGroupId: widget.item.exercise.muscleGroupId,
      date: DateTime.now(),
      weight: weight,
      reps: reps,
      setType: setType,
    );

    // Trigger Rest Timer
    ref.read(restTimerProvider).start(
      seconds: widget.item.exercise.restSeconds,
      exerciseName: widget.item.exercise.name,
    );

    // Check for PR
    final allHistory = await repo.getAllHistoricalSetsForExercise(widget.item.exercise.id);
    final newlyCreatedSet = SetModel(
      id: newSetId,
      workoutExerciseId: widget.item.id,
      exerciseId: widget.item.exercise.id,
      muscleGroupId: widget.item.exercise.muscleGroupId,
      date: DateTime.now(),
      setIndex: widget.item.sets.length + 1,
      weight: weight,
      reps: reps,
      setType: setType,
      completedAt: DateTime.now(),
    );

    final prCheck = PrDetector.checkSetPr(
      newSet: newlyCreatedSet,
      historicalSets: allHistory,
      weightUnit: widget.unit.label,
    );

    if (prCheck.isPr) {
      AppHaptics.pr();
      widget.onPrAchieved(prCheck);
    } else {
      AppHaptics.success();
    }

    setState(() {
      _customNextWeight = null;
      _customNextReps = null;
    });

    widget.onRefresh();
  }

  Future<void> _deleteSet(SetModel set) async {
    AppHaptics.warning();
    final repo = ref.read(workoutRepositoryProvider);
    await repo.deleteSet(set.id);
    if (mounted) {
      setState(() {
        _locallyDeletedCompletedSetIds.remove(set.id);
      });
      widget.onRefresh();
    }
  }

  void _openSetEditor(SetModel? existingSet, int targetIndex) {
    AppHaptics.tap();
    final prevSet = targetIndex <= _prevSets.length ? _prevSets[targetIndex - 1] : (_prevSets.isNotEmpty ? _prevSets.last : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SetEntrySheet(
        exercise: widget.item.exercise,
        workoutExerciseId: widget.item.id,
        learnedWeightStep: widget.item.exercise.weightStep,
        previousSessionSet: prevSet,
        existingSetToEdit: existingSet,
        nextSetIndex: targetIndex,
        sessionMaxWeight: widget.item.maxWeight,
      ),
    ).then((_) => widget.onRefresh());
  }

  void _showSetTypePicker(SetModel s) {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SetType.values.map((t) {
              final isCurrent = s.setType == t;
              return ListTile(
                leading: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _getSetTypeColor(t).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      t.shortCode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _getSetTypeColor(t),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  t.label,
                  style: TextStyle(
                    color: isCurrent ? context.accent : context.textPrimary,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: isCurrent ? Icon(Icons.check_rounded, color: context.accent) : null,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final repo = ref.read(workoutRepositoryProvider);
                  await repo.updateSet(
                    setId: s.id,
                    weight: s.weight,
                    reps: s.reps,
                    setType: t,
                    rpe: s.rpe,
                  );
                  widget.onRefresh();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Color _getSetTypeColor(SetType type) {
    switch (type) {
      case SetType.warmup:
        return AppColors.warmupSet;
      case SetType.working:
        return AppColors.workingSet;
      case SetType.drop:
        return AppColors.dropSet;
      case SetType.failure:
        return AppColors.failureSet;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSets = _currentActiveSets;
    final ex = widget.item.exercise;

    // Determine target/ghost values for the next prospective set
    double nextGhostWeight = 80.0;
    int nextGhostReps = ex.repMin > 0 ? ex.repMin : 10;

    if (activeSets.isNotEmpty) {
      nextGhostWeight = activeSets.last.weight;
      nextGhostReps = activeSets.last.reps;
    } else if (_prevSets.isNotEmpty) {
      nextGhostWeight = _prevSets.first.weight;
      nextGhostReps = _prevSets.first.reps;
    }

    final effectiveTargetWeight = _customNextWeight ?? nextGhostWeight;
    final effectiveTargetReps = _customNextReps ?? nextGhostReps;

    final bestSet = activeSets.isNotEmpty
        ? (List.of(activeSets)..sort((a, b) => E1rmCalculator.calculateEpley(b.weight, b.reps).compareTo(E1rmCalculator.calculateEpley(a.weight, a.reps)))).first
        : null;
    final bestE1rm = bestSet != null ? E1rmCalculator.calculateEpley(bestSet.weight, bestSet.reps) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.cardBorder,
          width: 1.0,
        ),
        boxShadow: context.isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Muscle dot, Title, Equipment, e1RM, Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExerciseVisualThumbnail(
                  exerciseName: ex.name,
                  muscleGroupId: ex.muscleGroupId,
                  equipment: ex.equipment.name,
                  size: 38,
                  onTap: () {
                    AppHaptics.tap();
                    ExerciseGuideSheet.show(context, ex, () {});
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          AppHaptics.tap();
                          ExerciseGuideSheet.show(context, ex, () {});
                        },
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                ex.name,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamilyDisplay,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(Icons.info_outline_rounded, size: 14, color: context.textTertiary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? const Color(0xFF1E212D)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: context.cardBorder, width: 0.8),
                            ),
                            child: Text(
                              ex.equipment.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: context.textTertiary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: context.cardBorder, width: 0.8),
                            ),
                            child: Text(
                              '${ex.restSeconds}s rest',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: context.textTertiary),
                            ),
                          ),
                          if (bestE1rm > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.workingSet.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.workingSet.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'e1RM ${UnitConverter.formatWeight(bestE1rm, unit: widget.unit, includeUnit: false)} ${widget.unit.label}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.workingSet,
                                ),
                              ),
                            ),
                          ],
                          if (widget.item.supersetGroup != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentViolet.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                'LINK',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: context.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // 1-Tap Plate Calculator button
                BouncyPressable(
                  onTap: () {
                    PlateCalculatorSheet.show(
                      context: context,
                      initialWeight: effectiveTargetWeight,
                      unit: widget.unit,
                      exerciseName: ex.name,
                      onWeightSelected: (w) => setState(() => _customNextWeight = w),
                    );
                  },
                  scaleDown: 0.88,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: context.chipBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.chipBorder),
                    ),
                    child: Icon(Icons.calculate_outlined, color: context.accent, size: 18),
                  ),
                ),
                // Expand / Collapse Toggle button
                BouncyPressable(
                  onTap: () {
                    AppHaptics.tap();
                    _setExpanded(!_isExpanded);
                  },
                  scaleDown: 0.88,
                  child: AnimatedRotation(
                    turns: _isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: context.chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.chipBorder),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _isExpanded ? context.textPrimary : context.accent,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                // Options Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz_rounded, color: context.textTertiary, size: 22),
                  color: context.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: context.cardBorder),
                  ),
                  onSelected: (val) {
                    if (val == 'rename') {
                      showDialog(
                        context: context,
                        builder: (ctx) => RenameExerciseDialog(
                          exercise: ex,
                          onRenamed: widget.onRefresh,
                        ),
                      );
                    } else if (val == 'plate_calc') {
                      PlateCalculatorSheet.show(
                        context: context,
                        initialWeight: effectiveTargetWeight,
                        unit: widget.unit,
                        exerciseName: ex.name,
                        onWeightSelected: (w) => setState(() => _customNextWeight = w),
                      );
                    } else if (val == 'warmup') {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => WarmupCalculatorSheet(
                          exercise: ex,
                          targetWorkingWeight: effectiveTargetWeight,
                          unit: widget.unit,
                          onAddWarmupSets: (rampSets) async {
                            final repo = ref.read(workoutRepositoryProvider);
                            for (final rs in rampSets) {
                              await repo.logSet(
                                workoutExerciseId: widget.item.id,
                                exerciseId: ex.id,
                                muscleGroupId: ex.muscleGroupId,
                                date: DateTime.now(),
                                weight: rs.weight,
                                reps: rs.reps,
                                setType: SetType.warmup,
                              );
                            }
                            widget.onRefresh();
                          },
                        ),
                      );
                    } else if (val == 'delete') {
                      widget.onRemoveExercise();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'plate_calc',
                      child: Row(
                        children: [
                          Icon(Icons.calculate_outlined, color: context.accent, size: 16),
                          const SizedBox(width: 10),
                          Text('Plate Calculator', style: TextStyle(color: context.textPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: context.accent, size: 16),
                          const SizedBox(width: 10),
                          Text('Rename / Custom Name', style: TextStyle(color: context.textPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'warmup',
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center_rounded, color: AppColors.warmupSet, size: 16),
                          const SizedBox(width: 10),
                          Text('Auto Warmup Sets', style: TextStyle(color: context.textPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                          SizedBox(width: 10),
                          Text('Remove Movement', style: TextStyle(color: AppColors.error, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!_isExpanded)
            InkWell(
              onTap: () {
                AppHaptics.tap();
                _setExpanded(true);
              },
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: context.chipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.chipBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        activeSets.isNotEmpty ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 15,
                        color: activeSets.isNotEmpty ? AppColors.workingSet : context.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activeSets.isEmpty
                              ? 'No sets logged yet • Tap to expand'
                              : '${activeSets.length} set${activeSets.length == 1 ? '' : 's'} logged'
                                  '${bestSet != null ? ' • Best: ${UnitConverter.formatWeight(bestSet.weight, unit: widget.unit)} × ${bestSet.reps}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Expand',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.accent),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.expand_more_rounded, size: 14, color: context.accent),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Suggestion Target Banner (if rule fired)
            if (widget.suggestion != null)
            GestureDetector(
              onTap: () {
                AppHaptics.tap();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => SuggestionExplainSheet(
                    suggestion: widget.suggestion!,
                    onApply: () {
                      final pWeight = widget.suggestion!.payload['suggestedWeight'] as num?;
                      final pReps = widget.suggestion!.payload['suggestedReps'] as num?;
                      if (pWeight != null && pReps != null) {
                        _quickLogSet(
                          weight: pWeight.toDouble(),
                          reps: pReps.toInt(),
                          setType: SetType.working,
                        );
                      }
                    },
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: context.accent, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.suggestion!.title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: context.accent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Why?',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 6),

          // Set Table Column Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('SET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.textTertiary)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('PREVIOUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.textTertiary)),
                ),
                SizedBox(
                  width: 72,
                  child: Text(widget.unit.label.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.textTertiary)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 54,
                  child: Text('REPS', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.textTertiary)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Center(
                    child: Icon(Icons.check_rounded, size: 14, color: context.textTertiary),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: context.cardBorder),

          // All Completed & Planned Sets Rows
          ...() {
            final plannedCount = math.max(0, _effectivePlannedCount - activeSets.length);

            while (_plannedSetKeys.length < plannedCount) {
              _plannedSetKeys.add('planned_${widget.item.id}_${DateTime.now().microsecondsSinceEpoch}_${_plannedKeySeq++}');
            }
            while (_plannedSetKeys.length > plannedCount) {
              _plannedSetKeys.removeLast();
            }

            return List.generate(_effectivePlannedCount, (indexZeroBased) {
              final setNum = indexZeroBased + 1;
              final isCompleted = indexZeroBased < activeSets.length;
              final prevSet = indexZeroBased < _prevSets.length
                  ? _prevSets[indexZeroBased]
                  : (_prevSets.isNotEmpty
                      ? _prevSets.last
                      : (indexZeroBased > 0 && activeSets.isNotEmpty ? activeSets.last : null));

              if (isCompleted) {
                final s = activeSets[indexZeroBased];
                return Dismissible(
                  key: Key('completed_${s.id}'),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    color: AppColors.workingSet.withValues(alpha: 0.2),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: const Row(
                      children: [
                        Icon(Icons.copy_rounded, color: AppColors.workingSet, size: 18),
                        SizedBox(width: 4),
                        Text('Duplicate', style: TextStyle(color: AppColors.workingSet, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  secondaryBackground: Container(
                    color: AppColors.error.withValues(alpha: 0.2),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      await _quickLogSet(
                        weight: s.weight,
                        reps: s.reps,
                        setType: s.setType,
                      );
                      return false;
                    }
                    return true;
                  },
                  onDismissed: (_) {
                    setState(() {
                      _locallyDeletedCompletedSetIds.add(s.id);
                    });
                    _deleteSet(s);
                  },
                  child: _buildCompletedSetRow(
                    set: s,
                    index: setNum,
                    previousSet: prevSet,
                  ),
                );
              } else {
                // Planned / Ghost Set Row
                final plannedIndex = indexZeroBased - activeSets.length;
                final plannedKey = _plannedSetKeys[plannedIndex];
                final targetW = _getTargetWeightForSet(setNum, effectiveTargetWeight);
                final targetR = _getTargetRepsForSet(setNum, effectiveTargetReps);
                final targetT = _getTargetTypeForSet(setNum);

                return Dismissible(
                  key: ValueKey(plannedKey),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.error.withValues(alpha: 0.18),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Remove Set', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
                        SizedBox(width: 4),
                        Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      ],
                    ),
                  ),
                  onDismissed: (_) {
                    AppHaptics.tap();
                    setState(() {
                      _plannedSetKeys.remove(plannedKey);
                      final currentTotal = _customPlannedCount ?? (_prevSets.isNotEmpty ? _prevSets.length : 3);
                      _customPlannedCount = math.max(activeSets.length, currentTotal - 1);
                    });
                  },
                  child: _buildPlannedSetRow(
                    setIndex: setNum,
                    previousSet: prevSet,
                    targetWeight: targetW,
                    targetReps: targetR,
                    targetType: targetT,
                  ),
                );
              }
            });
          }(),

          Divider(height: 1, color: context.cardBorder),

          // Card Footer: + Add Set, Match Last Session, Warmup Ramp
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                BouncyPressable(
                  onTap: () {
                    AppHaptics.tap();
                    setState(() {
                      _customPlannedCount = _effectivePlannedCount + 1;
                    });
                  },
                  scaleDown: 0.94,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: context.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Add Set',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_prevSets.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  BouncyPressable(
                    onTap: () {
                      AppHaptics.selection();
                      setState(() {
                        _customPlannedCount = _prevSets.length;
                        for (int i = 0; i < _prevSets.length; i++) {
                          _customGhostWeights[i + 1] = _prevSets[i].weight;
                          _customGhostReps[i + 1] = _prevSets[i].reps;
                          _customGhostTypes[i + 1] = _prevSets[i].setType;
                        }
                      });
                    },
                    scaleDown: 0.94,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 14, color: context.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Match Previous',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                BouncyPressable(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => WarmupCalculatorSheet(
                        exercise: ex,
                        targetWorkingWeight: nextGhostWeight,
                        unit: widget.unit,
                        onAddWarmupSets: (rampSets) async {
                          final repo = ref.read(workoutRepositoryProvider);
                          for (final rs in rampSets) {
                            await repo.logSet(
                              workoutExerciseId: widget.item.id,
                              exerciseId: ex.id,
                              muscleGroupId: ex.muscleGroupId,
                              date: DateTime.now(),
                              weight: rs.weight,
                              reps: rs.reps,
                              setType: SetType.warmup,
                            );
                          }
                          widget.onRefresh();
                        },
                      ),
                    );
                  },
                  scaleDown: 0.94,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center_rounded, size: 14, color: AppColors.warmupSet),
                        SizedBox(width: 4),
                        Text(
                          'Warmup Ramp',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warmupSet,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
  }

  // Row for an already logged set
  Widget _buildCompletedSetRow({
    required SetModel set,
    required int index,
    required SetModel? previousSet,
  }) {
    final typeColor = _getSetTypeColor(set.setType);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeInput = ref.watch(activeWorkoutInputProvider);
    final isRowActive = activeInput?.workoutExerciseId == widget.item.id &&
        activeInput?.setIndex == index &&
        activeInput?.existingSetId == set.id;
    final isWeightActive = isRowActive && activeInput?.activeField == WorkoutInputField.weight;
    final isRepsActive = isRowActive && activeInput?.activeField == WorkoutInputField.reps;

    final displayedWeight = isWeightActive
        ? activeInput!.weightInput
        : UnitConverter.formatWeight(set.weight, unit: widget.unit, includeUnit: false);
    final displayedReps = isRepsActive ? activeInput!.repsInput : '${set.reps}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isRowActive ? context.accent.withValues(alpha: isDark ? 0.08 : 0.04) : null,
        border: Border(
          bottom: BorderSide(
            color: context.cardBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Set Badge (Tap to cycle: 1 -> W -> D -> F, Long press for full picker)
          BouncyPressable(
            onTap: () => _cycleCompletedSetType(set),
            onLongPress: () => _showSetTypePicker(set),
            scaleDown: 0.90,
            child: Container(
              width: 32,
              height: 26,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: isDark ? 0.20 : 0.14),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: typeColor.withValues(alpha: 0.45),
                  width: 0.9,
                ),
              ),
              child: Center(
                child: Text(
                  set.setType == SetType.working ? '$index' : set.setType.shortCode,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: typeColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Previous performance
          Expanded(
            child: Text(
              previousSet != null
                  ? '${UnitConverter.formatWeight(previousSet.weight, unit: widget.unit, includeUnit: false)} × ${previousSet.reps}'
                  : '—',
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          // Weight Box
          BouncyPressable(
            onTap: () {
              AppHaptics.tap();
              ref.read(activeWorkoutInputProvider.notifier).startEditing(
                workoutExerciseId: widget.item.id,
                exerciseId: widget.item.exercise.id,
                exerciseName: widget.item.exercise.name,
                equipment: widget.item.exercise.equipment,
                setIndex: index,
                existingSetId: set.id,
                setType: set.setType,
                field: WorkoutInputField.weight,
                initialWeight: set.weight,
                initialReps: set.reps,
                unit: widget.unit,
                isCompleted: true,
              );
            },
            scaleDown: 0.96,
            child: Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: isWeightActive
                    ? context.accent.withValues(alpha: isDark ? 0.22 : 0.12)
                    : (isDark ? const Color(0xFF191C28) : const Color(0xFFF4F4F5)),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isWeightActive
                      ? context.accent
                      : (isDark ? const Color(0xFF262B3B) : const Color(0xFFE5E5E5)),
                  width: isWeightActive ? 1.5 : 1.0,
                ),
              ),
              child: Text(
                displayedWeight.isEmpty ? '0' : displayedWeight,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isWeightActive ? context.accent : context.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Reps Box
          BouncyPressable(
            onTap: () {
              AppHaptics.tap();
              ref.read(activeWorkoutInputProvider.notifier).startEditing(
                workoutExerciseId: widget.item.id,
                exerciseId: widget.item.exercise.id,
                exerciseName: widget.item.exercise.name,
                equipment: widget.item.exercise.equipment,
                setIndex: index,
                existingSetId: set.id,
                setType: set.setType,
                field: WorkoutInputField.reps,
                initialWeight: set.weight,
                initialReps: set.reps,
                unit: widget.unit,
                isCompleted: true,
              );
            },
            scaleDown: 0.96,
            child: Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: isRepsActive
                    ? context.accent.withValues(alpha: isDark ? 0.22 : 0.12)
                    : (isDark ? const Color(0xFF191C28) : const Color(0xFFF4F4F5)),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isRepsActive
                      ? context.accent
                      : (isDark ? const Color(0xFF262B3B) : const Color(0xFFE5E5E5)),
                  width: isRepsActive ? 1.5 : 1.0,
                ),
              ),
              child: Text(
                displayedReps.isEmpty ? '0' : displayedReps,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isRepsActive ? context.accent : context.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Completed Checkmark Button
          BouncyPressable(
            onTap: () => _openSetEditor(set, index),
            scaleDown: 0.88,
            child: Container(
              width: 36,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: isDark ? 0.22 : 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.75), width: 1.2),
              ),
              child: const Center(
                child: Icon(Icons.check_rounded, color: AppColors.success, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Row for planned / ghost set (1-Tap Checkmark logs it!)
  Widget _buildPlannedSetRow({
    required int setIndex,
    required SetModel? previousSet,
    required double targetWeight,
    required int targetReps,
    required SetType targetType,
  }) {
    final typeColor = _getSetTypeColor(targetType);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeInput = ref.watch(activeWorkoutInputProvider);
    final isRowActive = activeInput?.workoutExerciseId == widget.item.id &&
        activeInput?.setIndex == setIndex &&
        activeInput?.existingSetId == null;
    final isWeightActive = isRowActive && activeInput?.activeField == WorkoutInputField.weight;
    final isRepsActive = isRowActive && activeInput?.activeField == WorkoutInputField.reps;

    final effectiveW = isRowActive ? activeInput!.effectiveWeight : targetWeight;
    final effectiveR = isRowActive ? activeInput!.effectiveReps : targetReps;
    final effectiveT = isRowActive ? activeInput!.setType : targetType;

    final displayedWeight = isWeightActive
        ? activeInput!.weightInput
        : UnitConverter.formatWeight(targetWeight, unit: widget.unit, includeUnit: false);
    final displayedReps = isRepsActive ? activeInput!.repsInput : '$targetReps';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isRowActive ? context.accent.withValues(alpha: isDark ? 0.08 : 0.04) : null,
        border: Border(
          bottom: BorderSide(
            color: context.cardBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Set Badge (Tap to cycle planned type: 1 -> W -> D -> F)
          BouncyPressable(
            onTap: () => _cyclePlannedSetType(setIndex),
            scaleDown: 0.90,
            child: Container(
              width: 32,
              height: 26,
              decoration: BoxDecoration(
                color: targetType != SetType.working
                    ? typeColor.withValues(alpha: isDark ? 0.18 : 0.12)
                    : (isDark ? const Color(0xFF191C28) : const Color(0xFFF4F4F5)),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: targetType != SetType.working
                      ? typeColor.withValues(alpha: 0.45)
                      : (isDark ? const Color(0xFF262B3B) : const Color(0xFFE5E5E5)),
                ),
              ),
              child: Center(
                child: Text(
                  targetType == SetType.working ? '$setIndex' : targetType.shortCode,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: targetType != SetType.working ? typeColor : context.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Previous performance
          Expanded(
            child: Text(
              previousSet != null
                  ? '${UnitConverter.formatWeight(previousSet.weight, unit: widget.unit, includeUnit: false)} × ${previousSet.reps}'
                  : 'Target',
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          // Weight (Ghost / editable)
          BouncyPressable(
            onTap: () {
              AppHaptics.tap();
              ref.read(activeWorkoutInputProvider.notifier).startEditing(
                workoutExerciseId: widget.item.id,
                exerciseId: widget.item.exercise.id,
                exerciseName: widget.item.exercise.name,
                equipment: widget.item.exercise.equipment,
                setIndex: setIndex,
                existingSetId: null,
                setType: effectiveT,
                field: WorkoutInputField.weight,
                initialWeight: effectiveW,
                initialReps: effectiveR,
                unit: widget.unit,
                isCompleted: false,
              );
            },
            scaleDown: 0.96,
            child: Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: isWeightActive
                    ? context.accent.withValues(alpha: isDark ? 0.22 : 0.12)
                    : (isDark ? const Color(0xFF161822) : const Color(0xFFF9FAFB)),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isWeightActive
                      ? context.accent
                      : (isDark ? const Color(0xFF262B3B) : const Color(0xFFE5E5E5)),
                  width: isWeightActive ? 1.5 : 1.0,
                ),
              ),
              child: Text(
                displayedWeight.isEmpty ? '0' : displayedWeight,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isWeightActive ? FontWeight.w700 : FontWeight.w500,
                  color: isWeightActive
                      ? context.accent
                      : context.textSecondary.withValues(alpha: 0.65),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Reps (Ghost / editable)
          BouncyPressable(
            onTap: () {
              AppHaptics.tap();
              ref.read(activeWorkoutInputProvider.notifier).startEditing(
                workoutExerciseId: widget.item.id,
                exerciseId: widget.item.exercise.id,
                exerciseName: widget.item.exercise.name,
                equipment: widget.item.exercise.equipment,
                setIndex: setIndex,
                existingSetId: null,
                setType: effectiveT,
                field: WorkoutInputField.reps,
                initialWeight: effectiveW,
                initialReps: effectiveR,
                unit: widget.unit,
                isCompleted: false,
              );
            },
            scaleDown: 0.96,
            child: Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: isRepsActive
                    ? context.accent.withValues(alpha: isDark ? 0.22 : 0.12)
                    : (isDark ? const Color(0xFF161822) : const Color(0xFFF9FAFB)),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isRepsActive
                      ? context.accent
                      : (isDark ? const Color(0xFF262B3B) : const Color(0xFFE5E5E5)),
                  width: isRepsActive ? 1.5 : 1.0,
                ),
              ),
              child: Text(
                displayedReps.isEmpty ? '0' : displayedReps,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isRepsActive ? FontWeight.w700 : FontWeight.w500,
                  color: isRepsActive
                      ? context.accent
                      : context.textSecondary.withValues(alpha: 0.65),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 1-TAP COMPLETE CHECKMARK BUTTON
          BouncyPressable(
            onTap: () async {
              await _quickLogSet(
                weight: effectiveW,
                reps: effectiveR,
                setType: effectiveT,
              );
            },
            scaleDown: 0.84,
            child: Container(
              width: 36,
              height: 30,
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.accent.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.check_rounded,
                  color: context.accent.withValues(alpha: 0.75),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
