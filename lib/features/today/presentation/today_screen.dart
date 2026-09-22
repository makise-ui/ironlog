import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../domain/models/set_model.dart';
import '../../../domain/models/workout_model.dart';
import '../../../domain/services/weight_step_learner.dart';
import '../../../data/providers.dart';
import 'exercise_picker_sheet.dart';
import 'set_entry_sheet.dart';
import 'workout_notes_dialog.dart';
import 'copy_session_sheet.dart';
import '../../routines/presentation/routines_sheet.dart';
import '../../paste_importer/presentation/paste_importer_sheet.dart';
import 'rest_timer_overlay.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  WorkoutModel? _workout;
  bool _isLoading = true;
  final Set<String> _selectedMuscleGroupIds = {};

  @override
  void initState() {
    super.initState();
    _loadTodayWorkout();
  }

  Future<void> _loadTodayWorkout() async {
    final repo = ref.read(workoutRepositoryProvider);
    final w = await repo.getOrCreateTodayWorkout();
    if (mounted) {
      setState(() {
        _workout = w;
        _isLoading = false;
        // Auto-select muscle groups present in the workout
        for (final item in w.exercises) {
          if (!item.archived) {
            _selectedMuscleGroupIds.add(item.exercise.muscleGroupId);
          }
        }
      });
    }
  }

  Future<void> _refreshWorkout() async {
    if (_workout == null) return;
    final repo = ref.read(workoutRepositoryProvider);
    final w = await repo.getWorkoutById(_workout!.id);
    if (mounted) {
      setState(() {
        _workout = w;
      });
    }
  }

  void _openExercisePicker() {
    if (_workout == null) return;
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExercisePickerSheet(
        workoutId: _workout!.id,
        initialMuscleGroupId: _selectedMuscleGroupIds.isNotEmpty ? _selectedMuscleGroupIds.first : null,
        onExerciseSelected: (ex) async {
          final repo = ref.read(workoutRepositoryProvider);
          await repo.addExerciseToWorkout(
            workoutId: _workout!.id,
            exerciseId: ex.id,
          );
          _selectedMuscleGroupIds.add(ex.muscleGroupId);
          _refreshWorkout();
        },
      ),
    );
  }

  void _openSetEntry({
    required WorkoutExerciseItem item,
    SetModel? setToEdit,
  }) async {
    AppHaptics.tap();
    final exRepo = ref.read(exerciseRepositoryProvider);
    final weightHistory = await exRepo.getWeightHistory(item.exercise.id);
    final learnedStep = WeightStepLearner.learnStep(
      historicalWeights: weightHistory,
      equipment: item.exercise.equipment,
      existingStep: item.exercise.weightStep,
    );

    final activeSets = item.sets.where((s) => !s.archived).toList();
    final prevSessionSet = activeSets.isNotEmpty ? activeSets.last : null;
    final sessionMax = item.maxWeight;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SetEntrySheet(
        exercise: item.exercise,
        workoutExerciseId: item.id,
        learnedWeightStep: learnedStep,
        previousSessionSet: prevSessionSet,
        existingSetToEdit: setToEdit,
        nextSetIndex: activeSets.length + 1,
        sessionMaxWeight: sessionMax,
      ),
    ).then((_) => _refreshWorkout());
  }

  void _openRoutines() {
    if (_workout == null) return;
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutinesSheet(
        workoutId: _workout!.id,
        onRoutineApplied: _refreshWorkout,
      ),
    );
  }

  void _openCopySession() {
    if (_workout == null) return;
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CopySessionSheet(
        targetWorkoutId: _workout!.id,
        onCopied: _refreshWorkout,
      ),
    );
  }

  void _openPasteImporter() {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PasteImporterSheet(
        onImportCompleted: _loadTodayWorkout,
      ),
    );
  }

  void _openNotesDialog() {
    if (_workout == null) return;
    AppHaptics.tap();
    showDialog(
      context: context,
      builder: (ctx) => WorkoutNotesDialog(
        currentTitle: _workout!.title,
        currentNote: _workout!.note,
        currentFeel: _workout!.feel,
        onSave: (title, note, feel) async {
          final repo = ref.read(workoutRepositoryProvider);
          await repo.updateWorkoutMeta(
            workoutId: _workout!.id,
            title: title,
            note: note,
            feel: feel,
          );
          _refreshWorkout();
        },
      ),
    );
  }

  void _removeExercise(WorkoutExerciseItem item) async {
    final repo = ref.read(workoutRepositoryProvider);
    await repo.removeExerciseFromWorkout(item.id);
    _refreshWorkout();

    if (mounted) {
      UndoSnackbar.show(
        context,
        message: '${item.exercise.name} removed',
        onUndo: () async {
          await repo.restoreWorkoutExercise(item.id);
          _refreshWorkout();
        },
      );
    }
  }

  void _deleteSet(SetModel s) async {
    final repo = ref.read(workoutRepositoryProvider);
    await repo.deleteSet(s.id);
    _refreshWorkout();

    if (mounted) {
      UndoSnackbar.show(
        context,
        message: 'Set deleted',
        onUndo: () async {
          await repo.restoreSet(s.id);
          _refreshWorkout();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);
    final unit = ref.watch(weightUnitNotifierProvider);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
    }

    final activeExercises = _workout?.exercises.where((e) => !e.archived).toList() ?? [];

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.md),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _workout?.title ?? 'IronLog Today',
                                style: AppTypography.displayMedium,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              if (_workout?.feel != null)
                                Text(
                                  ['😫', '😕', '😐', '🙂', '🔥'][(_workout!.feel! - 1).clamp(0, 4)],
                                  style: const TextStyle(fontSize: 20),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${activeExercises.length} exercises • ${_workout?.totalSetsCount ?? 0} sets • ${UnitConverter.formatWeight(_workout?.totalVolume ?? 0, unit: unit)}',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Edit details / feel button
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: AppColors.accentCyan, size: 28),
                        tooltip: 'Workout Notes & Feel',
                        onPressed: _openNotesDialog,
                      ),
                    ],
                  ),
                ),
              ),

              // Muscle Group Selector Row
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.md, bottom: AppSpacing.xs),
                      child: Text('TARGET MUSCLE GROUPS', style: AppTypography.labelSmall),
                    ),
                    muscleGroupsAsync.when(
                      data: (groups) {
                        return SizedBox(
                          height: 42,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final mg = groups[index];
                              final isSelected = _selectedMuscleGroupIds.contains(mg.id);
                              final color = AppColors.muscleGroupColors[mg.name] ?? AppColors.accentCyan;

                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: GestureDetector(
                                  onTap: () {
                                    AppHaptics.step();
                                    setState(() {
                                      if (isSelected) {
                                        _selectedMuscleGroupIds.remove(mg.id);
                                      } else {
                                        _selectedMuscleGroupIds.add(mg.id);
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? color.withValues(alpha: 0.22) : AppColors.glassTileFill,
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                                      border: Border.all(
                                        color: isSelected ? color : AppColors.glassBorderDim,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          mg.name,
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? Colors.white : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const SizedBox(height: 42),
                      error: (_, _) => const SizedBox(height: 42),
                    ),
                  ],
                ),
              ),

              // Action Buttons Row (Routines, Copy Last, Paste Importer)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      _buildQuickAction(
                        icon: Icons.list_alt_rounded,
                        label: 'Routines',
                        onTap: _openRoutines,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _buildQuickAction(
                        icon: Icons.copy_rounded,
                        label: 'Copy Last',
                        onTap: _openCopySession,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _buildQuickAction(
                        icon: Icons.paste_rounded,
                        label: 'Paste-to-Log',
                        onTap: _openPasteImporter,
                      ),
                    ],
                  ),
                ),
              ),

              // Exercise List or Empty State
              if (activeExercises.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentCyan.withValues(alpha: 0.15),
                              border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(
                              Icons.fitness_center_rounded,
                              size: 32,
                              color: AppColors.accentCyan,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Ready to Lift?',
                            style: AppTypography.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Select your target muscle groups above, load a Push/Pull/Legs routine, or tap below to add your first movement.',
                            style: AppTypography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          GestureDetector(
                            onTap: _openExercisePicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: AppColors.accentGradientHorizontal,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: AppSpacing.xs),
                                  Text(
                                    'Add Exercise',
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = activeExercises[index];
                        return _buildExerciseCard(item, unit);
                      },
                      childCount: activeExercises.length,
                    ),
                  ),
                ),

              // Bottom "+ Add Exercise" Button
              if (activeExercises.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: GlassTile(
                      onTap: _openExercisePicker,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: AppColors.accentCyan, size: 20),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            'Add Exercise',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom spacing for floating nav bar and timer
              const SliverToBoxAdapter(
                child: SizedBox(height: 140),
              ),
            ],
          ),
        ),

        // Floating Rest Timer Bar
        const Positioned(
          left: 0,
          right: 0,
          bottom: 84, // right above glass nav bar
          child: RestTimerOverlay(),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.glassTileFill,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.glassBorderDim),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.accentCyan),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(WorkoutExerciseItem item, WeightUnit unit) {
    final activeSets = item.sets.where((s) => !s.archived).toList();

    return GlassTile(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name, equipment badge, menu
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.exercise.name,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.exercise.equipment.name.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${item.exercise.restSeconds}s rest',
                          style: AppTypography.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Exercise Options Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 20),
                color: const Color(0xF01A1E2C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  side: const BorderSide(color: AppColors.glassBorderLight),
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    _removeExercise(item);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                        SizedBox(width: AppSpacing.xs),
                        Text('Remove Exercise', style: TextStyle(color: AppColors.error, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Sets row: Chips "weight x reps"
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...activeSets.map((s) {
                Color chipColor;
                switch (s.setType) {
                  case SetType.warmup:
                    chipColor = AppColors.warmupSet;
                    break;
                  case SetType.working:
                    chipColor = AppColors.workingSet;
                    break;
                  case SetType.drop:
                    chipColor = AppColors.dropSet;
                    break;
                  case SetType.failure:
                    chipColor = AppColors.failureSet;
                    break;
                }

                return GestureDetector(
                  onTap: () => _openSetEntry(item: item, setToEdit: s),
                  onLongPress: () {
                    AppHaptics.warning();
                    _deleteSet(s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: chipColor.withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s.setType != SetType.working) ...[
                          Text(
                            s.setType.shortCode,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: chipColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '${UnitConverter.formatWeight(s.weight, unit: unit, includeUnit: false)} × ${s.reps}',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // "+ Set" chip
              GestureDetector(
                onTap: () => _openSetEntry(item: item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: AppColors.glassBorderDim,
                      width: 1.0,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: AppColors.accentCyan),
                      SizedBox(width: 3),
                      Text(
                        'Set',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
