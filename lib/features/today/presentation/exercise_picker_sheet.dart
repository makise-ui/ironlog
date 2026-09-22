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

  Future<void> _createCustomExercise(String name) async {
    AppHaptics.save();
    final newId = const Uuid().v4();
    final newExercise = ExerciseModel(
      id: newId,
      name: name,
      muscleGroupId: _selectedMuscleGroupId ?? 'chest',
      equipment: EquipmentType.other,
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
      decoration: const BoxDecoration(
        color: Color(0xF00D0F18),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(
          top: BorderSide(color: AppColors.glassBorderLight, width: 1.5),
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
                color: Colors.white.withValues(alpha: 0.2),
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
                const Text('Select Exercise', style: AppTypography.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassFillActive,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.glassBorderLight),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search or type new exercise...',
                  hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentCyan),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textTertiary),
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

          const Divider(height: 1, color: AppColors.glassBorderDim),

          // Exercise List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length + (query.isNotEmpty && !hasExactMatch ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Inline custom creation item
                      if (query.isNotEmpty && !hasExactMatch && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: GlassButton(
                            text: 'Create custom exercise "$query"',
                            icon: Icons.add_circle_outline_rounded,
                            style: GlassButtonStyle.secondary,
                            onPressed: () => _createCustomExercise(query),
                          ),
                        );
                      }

                      final itemIndex = query.isNotEmpty && !hasExactMatch ? index - 1 : index;
                      final ex = filtered[itemIndex];

                      return GlassTile(
                        onTap: () {
                          AppHaptics.tap();
                          widget.onExerciseSelected(ex);
                          Navigator.of(context).pop();
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: const Icon(
                                Icons.fitness_center_rounded,
                                size: 20,
                                color: AppColors.accentCyan,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ex.name,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${ex.equipment.name.toUpperCase()} • ${ex.repMin}-${ex.repMax} reps • ${ex.restSeconds}s rest',
                                    style: AppTypography.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.textTertiary,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.2) : AppColors.glassTileFill,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(
              color: isSelected ? AppColors.accentCyan : AppColors.glassBorderDim,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
