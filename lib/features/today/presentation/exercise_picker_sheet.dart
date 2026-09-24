import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/fuzzy_matcher.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../domain/models/exercise_model.dart';
import '../../../domain/services/weight_step_learner.dart';
import '../../../data/providers.dart';
import 'custom_exercise_dialog.dart';
import 'rename_exercise_dialog.dart';
import 'widgets/exercise_visual_thumbnail.dart';
import 'widgets/exercise_guide_sheet.dart';

class ExercisePickerSheet extends ConsumerStatefulWidget {
  final String workoutId;
  final String? initialMuscleGroupId;
  final Function(ExerciseModel exercise) onExerciseSelected;

  const ExercisePickerSheet({
    super.key,
    required this.workoutId,
    this.initialMuscleGroupId,
    required this.onExerciseSelected,
  });

  @override
  ConsumerState<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedMuscleGroupId;
  List<ExerciseModel> _allExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedMuscleGroupId = widget.initialMuscleGroupId;
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final repo = ref.read(exerciseRepositoryProvider);
    final exercises = await repo.getExercises();
    if (mounted) {
      setState(() {
        _allExercises = exercises;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExerciseModel> _getFilteredExercises() {
    final query = _searchController.text.trim();

    List<ExerciseModel> pool = _allExercises;
    if (_selectedMuscleGroupId != null && _selectedMuscleGroupId!.isNotEmpty) {
      pool = pool.where((e) => e.muscleGroupId == _selectedMuscleGroupId).toList();
    }

    if (query.isEmpty) {
      return pool;
    }

    final results = FuzzyMatcher.search<ExerciseModel>(
      query: query,
      items: pool,
      textExtractor: (e) => e.name,
      threshold: 0.30,
    );

    return results.map((r) => r.item).toList();
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

  Future<void> _createCustomExercise(String name) async {
    AppHaptics.save();
    final newId = const Uuid().v4();
    final resolvedMuscleGroup = _selectedMuscleGroupId ?? _inferMuscleGroup(name);
    final resolvedEquipment = _inferEquipment(name);
    final isBw = resolvedEquipment == EquipmentType.bodyweight;
    final newExercise = ExerciseModel(
      id: newId,
      name: name,
      muscleGroupId: resolvedMuscleGroup,
      equipment: resolvedEquipment,
      loadMode: isBw ? LoadMode.bodyweight : LoadMode.total,
      weightStep: isBw ? 0.0 : 2.5,
      isCustom: true,
    );

    await ref.read(exerciseRepositoryProvider).createExercise(newExercise);
    widget.onExerciseSelected(newExercise);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);
    final query = _searchController.text.trim();
    final filtered = _getFilteredExercises();
    final hasExactMatch = filtered.any((e) => e.name.toLowerCase() == query.toLowerCase());

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(
          top: BorderSide(color: context.sheetBorder, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.handleBar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select Exercise',
                    style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        AppHaptics.tap();
                        showDialog(
                          context: context,
                          builder: (ctx) => CustomExerciseDialog(
                            initialMuscleGroupId: _selectedMuscleGroupId,
                            onCreated: (newEx) {
                              widget.onExerciseSelected(newEx);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                      icon: Icon(Icons.add_rounded, size: 18, color: context.accent),
                      label: Text(
                        'Custom',
                        style: TextStyle(
                          color: context.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: context.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Container(
              decoration: BoxDecoration(
                color: context.inputBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: context.inputBorder),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: context.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search or type new exercise...',
                  hintStyle: TextStyle(color: context.textTertiary, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: context.accent),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 18, color: context.textTertiary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // Muscle Group Filter Chips
          muscleGroupsAsync.when(
            data: (groups) {
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  children: [
                    _buildFilterChip('All', null),
                    ...groups.map((g) => _buildFilterChip(g.name, g.id)),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 44),
            error: (_, _) => const SizedBox(height: 44),
          ),

          Divider(height: 1, color: context.cardBorder),

          // Exercise List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: context.accent))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length + (query.isNotEmpty && !hasExactMatch ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Inline custom creation item
                      if (query.isNotEmpty && !hasExactMatch && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GlassButton(
                                text: 'Create custom exercise / game "$query"',
                                icon: Icons.add_circle_outline_rounded,
                                style: GlassButtonStyle.primary,
                                onPressed: () => _createCustomExercise(query),
                              ),
                              if (filtered.isEmpty) ...[
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'No catalog exercise found matching "$query".\nTap above to add it as a custom exercise or game!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: context.textTertiary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      final itemIndex = query.isNotEmpty && !hasExactMatch ? index - 1 : index;
                      final ex = filtered[itemIndex];

                      return GlassTile(
                        onTap: () {
                          AppHaptics.tap();
                          ExerciseGuideSheet.show(
                            context,
                            ex,
                            () {
                              widget.onExerciseSelected(ex);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                        child: Row(
                          children: [
                            ExerciseVisualThumbnail(
                              exerciseName: ex.name,
                              muscleGroupId: ex.muscleGroupId,
                              equipment: ex.equipment.name,
                              size: 46,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          ex.name,
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: context.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${ex.equipment.name.toUpperCase()} • ${ex.repMin}-${ex.repMax} reps • ${ex.restSeconds}s rest',
                                    style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            // Quick Add button for experienced users
                            IconButton(
                              icon: Icon(Icons.add_circle_outline_rounded, size: 22, color: context.accent),
                              tooltip: 'Quick Add to Session',
                              onPressed: () {
                                AppHaptics.tap();
                                widget.onExerciseSelected(ex);
                                Navigator.of(context).pop();
                              },
                            ),
                            // Rename button
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 16, color: context.textTertiary),
                              tooltip: 'Rename / Custom Name',
                              onPressed: () {
                                AppHaptics.tap();
                                showDialog(
                                  context: context,
                                  builder: (ctx) => RenameExerciseDialog(
                                    exercise: ex,
                                    onRenamed: _loadExercises,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? id) {
    final isSelected = _selectedMuscleGroupId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: GestureDetector(
        onTap: () {
          AppHaptics.step();
          setState(() => _selectedMuscleGroupId = id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accent.withValues(alpha: context.isDark ? 0.20 : 0.12)
                : context.chipBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? context.accent : context.chipBorder,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? context.accent : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
