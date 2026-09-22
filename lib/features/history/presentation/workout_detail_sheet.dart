import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../domain/models/workout_model.dart';
import '../../../domain/models/set_model.dart';
import '../../../data/providers.dart';

class WorkoutDetailSheet extends ConsumerWidget {
  final WorkoutModel workout;
  final VoidCallback onWorkoutModified;

  const WorkoutDetailSheet({
    super.key,
    required this.workout,
    required this.onWorkoutModified,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitNotifierProvider);
    final activeExercises = workout.exercises.where((e) => !e.archived).toList();

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workout.title, style: AppTypography.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        '${AppDateUtils.formatFullDate(workout.date)} • ${UnitConverter.formatWeight(workout.totalVolume, unit: unit)} • ${workout.totalSetsCount} sets',
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.glassBorderDim),

          // Exercises & sets breakdown
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: activeExercises.length,
              itemBuilder: (context, index) {
                final exItem = activeExercises[index];
                final activeSets = exItem.sets.where((s) => !s.archived).toList();

                return GlassTile(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            exItem.exercise.name,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${activeSets.length} sets',
                            style: AppTypography.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Table(
                        columnWidths: const {
                          0: FixedColumnWidth(40),
                          1: FlexColumnWidth(),
                          2: FlexColumnWidth(),
                          3: FlexColumnWidth(),
                        },
                        children: [
                          const TableRow(
                            children: [
                              Text('SET', style: AppTypography.labelSmall),
                              Text('WEIGHT', style: AppTypography.labelSmall),
                              Text('REPS', style: AppTypography.labelSmall),
                              Text('e1RM', style: AppTypography.labelSmall),
                            ],
                          ),
                          ...activeSets.map((s) {
                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    s.setType == SetType.working ? '${s.setIndex}' : s.setType.shortCode,
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontWeight: FontWeight.w700,
                                      color: s.setType == SetType.warmup
                                          ? AppColors.warmupSet
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    UnitConverter.formatWeight(s.weight, unit: unit),
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      color: AppColors.textPrimary,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    '${s.reps}',
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      color: AppColors.textPrimary,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    UnitConverter.formatWeight(s.e1rm, unit: unit),
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      color: AppColors.accentCyan,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Delete session button
          Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            child: GlassButton(
              text: 'Delete Workout',
              icon: Icons.delete_outline_rounded,
              style: GlassButtonStyle.danger,
              onPressed: () async {
                AppHaptics.warning();
                final repo = ref.read(workoutRepositoryProvider);
                await repo.updateWorkoutMeta(workoutId: workout.id, title: workout.title);
                // Soft delete by setting archived = true
                await ref.read(databaseProvider).customStatement(
                  'UPDATE workouts SET archived = 1 WHERE id = ?;',
                  [workout.id],
                );
                onWorkoutModified();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
