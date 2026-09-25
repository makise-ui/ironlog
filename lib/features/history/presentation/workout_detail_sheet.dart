import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../domain/models/workout_model.dart';
import '../../../domain/models/exercise_model.dart';
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.title,
                        style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${AppDateUtils.formatFullDate(workout.date)} • ${UnitConverter.formatWeight(workout.totalVolume, unit: unit)} • ${workout.totalSetsCount} sets',
                        style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.cardBorder),

          // Exercises & sets breakdown
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                          Expanded(
                            child: Text(
                              exItem.exercise.name,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${activeSets.length} sets',
                            style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
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
                          TableRow(
                            children: [
                              Text('SET', style: AppTypography.labelSmall.copyWith(color: context.textTertiary)),
                              Text(exItem.exercise.isHoldDuration || exItem.exercise.isBodyweight ? '+LOAD' : 'WEIGHT', style: AppTypography.labelSmall.copyWith(color: context.textTertiary)),
                              Text(exItem.exercise.isHoldDuration ? 'TIME' : (exItem.exercise.isCardioTime ? 'MINUTES' : 'REPS'), style: AppTypography.labelSmall.copyWith(color: context.textTertiary)),
                              Text(exItem.exercise.isStandardWeightAndReps ? 'e1RM' : '', style: AppTypography.labelSmall.copyWith(color: context.textTertiary)),
                            ],
                          ),
                          ...activeSets.map((s) {
                            final tracking = exItem.exercise.trackingType;
                            String weightStr;
                            if (tracking == ExerciseTrackingType.duration) {
                              weightStr = s.weight > 0 ? '+${UnitConverter.formatWeight(s.weight, unit: unit)}' : '—';
                            } else if (tracking == ExerciseTrackingType.cardioTime) {
                              weightStr = '—';
                            } else if (tracking == ExerciseTrackingType.bodyweightReps) {
                              weightStr = s.weight > 0 ? '+${UnitConverter.formatWeight(s.weight, unit: unit)}' : 'BW';
                            } else {
                              weightStr = UnitConverter.formatWeight(s.weight, unit: unit);
                            }

                            String repsStr;
                            if (tracking == ExerciseTrackingType.duration) {
                              repsStr = SetModel.formatDuration(s.reps);
                            } else if (tracking == ExerciseTrackingType.cardioTime) {
                              repsStr = '${s.reps}m';
                            } else {
                              repsStr = '${s.reps}';
                            }

                            String e1rmStr;
                            if (tracking == ExerciseTrackingType.weightAndReps) {
                              e1rmStr = UnitConverter.formatWeight(s.e1rm, unit: unit);
                            } else {
                              e1rmStr = '—';
                            }

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
                                          : context.textSecondary,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    weightStr,
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      color: context.textPrimary,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    repsStr,
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      color: context.textPrimary,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    e1rmStr,
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      color: context.accent,
                                      fontFeatures: const [FontFeature.tabularFigures()],
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

          // Actions: Edit / Log Sets & Delete
          Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GlassButton(
                    text: 'Edit / Log Sets',
                    icon: Icons.edit_note_rounded,
                    style: GlassButtonStyle.primary,
                    onPressed: () {
                      AppHaptics.tap();
                      ref.read(selectedWorkoutDateProvider.notifier).state =
                          AppDateUtils.normalizeDate(workout.date);
                      Navigator.of(context).pop();
                      context.go('/today');
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: GlassButton(
                    text: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    style: GlassButtonStyle.danger,
                    onPressed: () async {
                      AppHaptics.warning();
                      final repo = ref.read(workoutRepositoryProvider);
                      await repo.deleteWorkout(workout.id);
                      onWorkoutModified();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
