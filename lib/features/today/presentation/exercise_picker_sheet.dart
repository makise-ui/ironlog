import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/fuzzy_matcher.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../domain/models/exercise_model.dart';
import '../../../domain/services/weight_step_learner.dart';
import '../../../data/providers.dart';
import 'custom_exercise_dialog.dart';
import 'edit_exercise_dialog.dart';
import 'widgets/exercise_visual_thumbnail.dart';
import 'widgets/exercise_guide_sheet.dart';
import 'widgets/exercise_image_picker_sheet.dart';

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
  EquipmentType? _selectedEquipment;
  List<ExerciseModel> _allExercises = [];
  List<ExerciseModel> _recentExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedMuscleGroupId = widget.initialMuscleGroupId;
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final repo = ref.read(exerciseRepositoryProvider);
    var exercises = await repo.getExercises();

    // Auto-seed openGym catalog if needed (< 500 exercises currently loaded)
    if (exercises.length < 500) {
      await repo.seedOpenGymCatalog();
      exercises = await repo.getExercises();
    }

    // Find recently trained exercises
    try {
      final recentWorkouts = await ref.read(workoutRepositoryProvider).getRecentWorkouts(limit: 8);
      final Set<String> recentIds = {};
      for (final w in recentWorkouts) {
        for (final we in w.exercises) {
          recentIds.add(we.exercise.id);
        }
      }
      _recentExercises = exercises.where((e) => recentIds.contains(e.id)).take(6).toList();
    } catch (_) {
      _recentExercises = [];
    }

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

    if (_selectedEquipment != null) {
      pool = pool.where((e) => e.equipment == _selectedEquipment).toList();
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

  Future<void> _openCustomExerciseDialog([String? prefillName]) async {
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
  }

  Future<void> _openImagePickerForExercise(ExerciseModel ex) async {
    final newPath = await ExerciseImagePickerSheet.show(
      context,
      exercise: ex,
    );
    if (newPath != null) {
      await _loadExercises();
    }
  }

  String _formatTrackingBadge(ExerciseModel ex) {
    switch (ex.trackingType) {
      case ExerciseTrackingType.duration:
        return 'HOLD (SEC)';
      case ExerciseTrackingType.bodyweightReps:
        return 'BODYWEIGHT';
      case ExerciseTrackingType.cardioTime:
        return 'CARDIO (MIN)';
      case ExerciseTrackingType.weightAndReps:
        return ex.equipment.name.toUpperCase();
    }
  }

  Color _getTrackingBadgeColor(ExerciseModel ex, BuildContext context) {
    switch (ex.trackingType) {
      case ExerciseTrackingType.duration:
        return const Color(0xFFF59E0B);
      case ExerciseTrackingType.bodyweightReps:
        return const Color(0xFF10B981);
      case ExerciseTrackingType.cardioTime:
        return const Color(0xFF0EA5E9);
      case ExerciseTrackingType.weightAndReps:
        return context.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(exerciseImageRevisionProvider, (previous, next) {
      _loadExercises();
    });
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);
    final query = _searchController.text.trim();
    final filtered = _getFilteredExercises();
    final hasExactMatch = filtered.any((e) => e.name.toLowerCase() == query.toLowerCase());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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
          const SizedBox(height: AppSpacing.xs),

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
                    ScaleTap(
                      onPressed: () => _openCustomExerciseDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: context.accent),
                            const SizedBox(width: 4),
                            Text(
                              'Custom',
                              style: TextStyle(
                                color: context.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
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
                  fontSize: 14.5,
                ),
                decoration: InputDecoration(
                  hintText: _allExercises.isNotEmpty ? 'Search ${_allExercises.length}+ exercises...' : 'Search exercises...',
                  hintStyle: TextStyle(color: context.textTertiary, fontSize: 13.5),
                  prefixIcon: Icon(Icons.search_rounded, color: context.accent, size: 20),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // 1. Frequently Trained Quick Strip (only when not searching)
          if (query.isEmpty && _recentExercises.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 14, color: context.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    'RECENTLY LOGGED',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recentExercises.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final ex = _recentExercises[index];
                  return ScaleTap(
                    onPressed: () {
                      AppHaptics.tap();
                      widget.onExerciseSelected(ex);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2232) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF282D42) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 14, color: context.accent),
                          const SizedBox(width: 4),
                          Text(
                            ex.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
          ],

          // 2. Muscle Group Filter Chips
          muscleGroupsAsync.when(
            data: (groups) {
              return SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  children: [
                    _buildFilterChip('All (${_allExercises.length})', null),
                    ...groups.map((g) {
                      final count = _allExercises.where((e) => e.muscleGroupId == g.id).length;
                      return _buildFilterChip('${g.name} ($count)', g.id);
                    }),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 36),
            error: (_, _) => const SizedBox(height: 36),
          ),

          const SizedBox(height: 6),

          // 3. Equipment Filter Chips
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                _buildEquipmentChip('All Equipment', null),
                _buildEquipmentChip('Barbell', EquipmentType.barbell),
                _buildEquipmentChip('Dumbbell', EquipmentType.dumbbell),
                _buildEquipmentChip('Cable', EquipmentType.cable),
                _buildEquipmentChip('Machine', EquipmentType.machine),
                _buildEquipmentChip('Bodyweight', EquipmentType.bodyweight),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Divider(height: 1, color: context.cardBorder),

          // 4. Exercise Cards List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: context.accent))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length + (query.isNotEmpty && !hasExactMatch ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Inline custom creation item when searching
                      if (query.isNotEmpty && !hasExactMatch && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassButton(
                            text: 'Create custom exercise "$query"',
                            icon: Icons.add_circle_outline_rounded,
                            style: GlassButtonStyle.primary,
                            onPressed: () => _openCustomExerciseDialog(query),
                          ),
                        );
                      }

                      final itemIndex = query.isNotEmpty && !hasExactMatch ? index - 1 : index;
                      final ex = filtered[itemIndex];
                      final badgeColor = _getTrackingBadgeColor(ex, context);
                      final trackingBadge = _formatTrackingBadge(ex);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161822) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF262B3D) : const Color(0xFFE2E4EE),
                            width: 1.0,
                          ),
                        ),
                        child: InkWell(
                          onTap: () async {
                            AppHaptics.tap();
                            await ExerciseGuideSheet.show(
                              context,
                              ex,
                              () {
                                widget.onExerciseSelected(ex);
                                Navigator.of(context).pop();
                              },
                            );
                            if (mounted) {
                              await _loadExercises();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                // Thumbnail with tap to change image
                                Stack(
                                  children: [
                                    ExerciseVisualThumbnail(
                                      exerciseId: ex.id,
                                      exerciseName: ex.name,
                                      imagePath: ex.imagePath,
                                      muscleGroupId: ex.muscleGroupId,
                                      equipment: ex.equipment.name,
                                      size: 54,
                                      onTap: () => _openImagePickerForExercise(ex),
                                    ),
                                    // Camera mini edit badge
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      child: GestureDetector(
                                        onTap: () => _openImagePickerForExercise(ex),
                                        child: Container(
                                          padding: const EdgeInsets.all(2.5),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.75),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              bottomRight: Radius.circular(6),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.edit_outlined,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // Title and Badges
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex.name,
                                        style: TextStyle(
                                          fontFamily: AppTypography.fontFamily,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              trackingBadge,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: badgeColor,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            ex.muscleGroupId.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: context.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 4),

                                // Customize Specs / Tracking Button
                                IconButton(
                                  icon: Icon(Icons.tune_rounded, size: 19, color: context.textTertiary),
                                  tooltip: 'Customize Tracking & Specs',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    AppHaptics.tap();
                                    final updated = await EditExerciseDialog.show(
                                      context,
                                      exercise: ex,
                                    );
                                    if (updated != null && mounted) {
                                      await _loadExercises();
                                    }
                                  },
                                ),

                                // Info Button
                                IconButton(
                                  icon: Icon(Icons.info_outline_rounded, size: 20, color: context.textTertiary),
                                  tooltip: 'Form Guide',
                                  onPressed: () async {
                                    AppHaptics.tap();
                                    await ExerciseGuideSheet.show(
                                      context,
                                      ex,
                                      () {
                                        widget.onExerciseSelected(ex);
                                        Navigator.of(context).pop();
                                      },
                                    );
                                    if (mounted) {
                                      await _loadExercises();
                                    }
                                  },
                                ),

                                // Direct 1-Tap [+ Add] Primary Button
                                ScaleTap(
                                  onPressed: () {
                                    AppHaptics.tap();
                                    widget.onExerciseSelected(ex);
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                                    decoration: BoxDecoration(
                                      color: context.accent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.accent.withValues(alpha: 0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_rounded, size: 15, color: context.onAccent),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Add',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: context.onAccent,
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
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accent.withValues(alpha: context.isDark ? 0.20 : 0.12)
                : context.chipBg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isSelected ? context.accent : context.chipBorder,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? context.accent : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentChip(String label, EquipmentType? type) {
    final isSelected = _selectedEquipment == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: GestureDetector(
        onTap: () {
          AppHaptics.step();
          setState(() => _selectedEquipment = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? context.chipSelectedBg : context.chipBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? context.accent : context.chipBorder,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? (context.isDark ? Colors.white : context.accent) : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
