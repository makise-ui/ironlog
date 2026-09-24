import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../domain/models/workout_model.dart';
import '../../../data/providers.dart';

class CopySessionSheet extends ConsumerStatefulWidget {
  final String targetWorkoutId;
  final VoidCallback onCopied;

  const CopySessionSheet({
    super.key,
    required this.targetWorkoutId,
    required this.onCopied,
  });

  @override
  ConsumerState<CopySessionSheet> createState() => _CopySessionSheetState();
}

class _CopySessionSheetState extends ConsumerState<CopySessionSheet> {
  List<WorkoutModel> _pastWorkouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPastWorkouts();
  }

  Future<void> _loadPastWorkouts() async {
    final repo = ref.read(workoutRepositoryProvider);
    final list = await repo.getHistoryWorkouts(limit: 15);
    // Exclude the current target workout
    final filtered = list.where((w) => w.id != widget.targetWorkoutId).toList();
    if (mounted) {
      setState(() {
        _pastWorkouts = filtered;
        _isLoading = false;
      });
    }
  }

  Future<void> _copySession(String previousId) async {
    AppHaptics.save();
    final repo = ref.read(workoutRepositoryProvider);
    await repo.copyLastSession(widget.targetWorkoutId, previousId);
    widget.onCopied();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Copy Previous Session',
                  style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.cardBorder),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: context.accent))
                : _pastWorkouts.isEmpty
                    ? Center(
                        child: Text(
                          'No previous workouts found to copy.',
                          style: TextStyle(color: context.textTertiary),
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        cacheExtent: 600,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _pastWorkouts.length,
                        itemBuilder: (context, index) {
                          final w = _pastWorkouts[index];
                          final exNames = w.exercises.map((e) => e.exercise.name).take(3).join(', ');

                          return GlassTile(
                            onTap: () => _copySession(w.id),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentViolet.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  ),
                                  child: const Icon(Icons.copy_rounded, color: AppColors.accentViolet, size: 20),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        w.title,
                                        style: TextStyle(
                                          fontFamily: AppTypography.fontFamily,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${AppDateUtils.formatFullDate(w.date)} • ${w.exercises.length} exercises • ${w.totalSetsCount} sets',
                                        style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                                      ),
                                      if (exNames.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          exNames + (w.exercises.length > 3 ? '...' : ''),
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontSize: 11,
                                            color: context.textTertiary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textTertiary),
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
