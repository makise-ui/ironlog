import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../domain/models/routine_model.dart';
import '../../../data/providers.dart';

class RoutinesSheet extends ConsumerStatefulWidget {
  final String workoutId;
  final VoidCallback onRoutineApplied;

  const RoutinesSheet({
    super.key,
    required this.workoutId,
    required this.onRoutineApplied,
  });

  @override
  ConsumerState<RoutinesSheet> createState() => _RoutinesSheetState();
}

class _RoutinesSheetState extends ConsumerState<RoutinesSheet> {
  List<RoutineModel> _routines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final repo = ref.read(routineRepositoryProvider);
    final list = await repo.getRoutines();
    if (mounted) {
      setState(() {
        _routines = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _applyRoutine(RoutineModel routine) async {
    AppHaptics.save();
    final workoutRepo = ref.read(workoutRepositoryProvider);

    // Update workout title with routine name
    await workoutRepo.updateWorkoutMeta(
      workoutId: widget.workoutId,
      title: routine.name,
    );

    // Add each exercise in routine to workout
    for (final item in routine.items) {
      await workoutRepo.addExerciseToWorkout(
        workoutId: widget.workoutId,
        exerciseId: item.exercise.id,
      );
    }

    widget.onRoutineApplied();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Workout Routines', style: AppTypography.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.glassBorderDim),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _routines.length,
                    itemBuilder: (context, index) {
                      final r = _routines[index];
                      final exNames = r.items.map((i) => i.exercise.name).join(', ');

                      return GlassTile(
                        onTap: () => _applyRoutine(r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${r.items.length} Exercises',
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentCyan,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              r.name,
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (r.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                r.description,
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              exNames,
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
}
