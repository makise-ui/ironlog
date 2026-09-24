import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../domain/models/routine_model.dart';
import '../../../data/providers.dart';
import 'create_preset_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInitialRoutines();
  }

  Future<void> _loadInitialRoutines() async {
    final repo = ref.read(routineRepositoryProvider);
    final list = await repo.getRoutines();
    if (mounted) {
      setState(() {
        _routines = list;
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

    // Note: Do NOT startWorkout here!
    // The timer starts ONLY when the user taps "Start Workout" or logs a set.

    widget.onRoutineApplied();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmApplyRoutine(RoutineModel routine) async {
    AppHaptics.tap();
    final workoutRepo = ref.read(workoutRepositoryProvider);
    final currentWorkout = await workoutRepo.getWorkoutById(widget.workoutId);
    final activeExercises = currentWorkout.exercises.where((e) => !e.archived).toList();

    if (!mounted) return;

    if (activeExercises.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.cardBorder),
          ),
          title: Text(
            'Load "${routine.name}"?',
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Text(
            'Your today session already has ${activeExercises.length} exercise(s). Would you like to add these ${routine.items.length} exercises or replace existing ones?',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('Replace Existing', style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: context.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, 'append'),
              child: const Text('Add to Workout'),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel' || !mounted) return;

      if (choice == 'replace') {
        for (final ex in activeExercises) {
          await workoutRepo.removeExerciseFromWorkout(ex.id);
        }
      }
      await _applyRoutine(routine);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.cardBorder),
          ),
          title: Text(
            'Load "${routine.name}"?',
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Text(
            'Load ${routine.items.length} exercise(s) into today\'s session:\n• ${routine.items.map((i) => i.exercise.name).join('\n• ')}\n\nThe timer will only start when you tap Start or log a set.',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: context.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Load Routine'),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await _applyRoutine(routine);
      }
    }
  }

  void _openCreatePreset() async {
    AppHaptics.tap();
    final newId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreatePresetSheet(),
    );

    if (newId != null) {
      final repo = ref.read(routineRepositoryProvider);
      final routines = await repo.getRoutines();
      final newRoutine = routines.where((r) => r.id == newId).firstOrNull;
      if (newRoutine != null && mounted) {
        _confirmApplyRoutine(newRoutine);
      }
    }
  }

  void _confirmDeleteRoutine(RoutineModel routine) {
    AppHaptics.warning();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.cardBorder),
        ),
        title: Text('Delete Preset?', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to remove "${routine.name}"?',
          style: TextStyle(color: context.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(routineRepositoryProvider);
              await repo.deleteRoutine(routine.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  bool _isCustom(RoutineModel routine) {
    // Custom presets have UUID IDs (> 20 characters)
    return routine.id.length > 20;
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(routinesProvider);
    final allRoutines = routinesAsync.valueOrNull ?? _routines;
    final customRoutines = allRoutines.where(_isCustom).toList();
    final defaultRoutines = allRoutines.where((r) => !_isCustom(r)).toList();
    final isLoading = routinesAsync.isLoading && allRoutines.isEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
                  'Workout Presets',
                  style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _openCreatePreset,
                      icon: Icon(Icons.add_rounded, size: 16, color: context.accent),
                      label: Text(
                        'New Preset',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.accent,
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
          Divider(height: 1, color: context.cardBorder),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: context.accent))
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    cacheExtent: 600,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      // Custom Presets Section
                      if (customRoutines.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'MY CUSTOM PRESETS',
                              style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${customRoutines.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...customRoutines.map((r) => _buildRoutineTile(r, isCustom: true)),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Built-in Routines Section
                      Row(
                        children: [
                          Text(
                            'BUILT-IN TEMPLATES',
                            style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${defaultRoutines.length}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              AppHaptics.tap();
                              final repo = ref.read(routineRepositoryProvider);
                              await repo.restoreDefaultRoutines();
                              await _loadInitialRoutines();
                            },
                            child: Text(
                              'Restore Defaults',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.accent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (defaultRoutines.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'All built-in templates have been removed.\nTap "Restore Defaults" above to bring them back.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.textTertiary, fontSize: 12),
                            ),
                          ),
                        )
                      else
                        ...defaultRoutines.map((r) => _buildRoutineTile(r, isCustom: false)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String? _resolvePresetImage(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('push')) {
      return 'assets/images/push_preset.jpg';
    } else if (lower.contains('pull')) {
      return 'assets/images/pull_preset.jpg';
    } else if (lower.contains('leg') || lower.contains('lower') || lower.contains('squat')) {
      return 'assets/images/legs_preset.jpg';
    } else if (lower.contains('upper')) {
      return 'assets/images/push_preset.jpg';
    }
    return null;
  }

  Widget _buildRoutineTile(RoutineModel r, {required bool isCustom}) {
    final exNames = r.items.map((i) => i.exercise.name).join(', ');
    final imageAsset = _resolvePresetImage(r.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Stack(
          children: [
            GlassTile(
              onTap: () => _confirmApplyRoutine(r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${r.items.length} Exercises',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.accent,
                          ),
                        ),
                      ),
                if (isCustom) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0x20FFFFFF) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      'CUSTOM',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                  onPressed: () => _confirmDeleteRoutine(r),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete preset',
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.play_circle_fill_rounded, size: 22, color: context.accent),
                  onPressed: () => _confirmApplyRoutine(r),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Load routine',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              r.name,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            if (r.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                r.description,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              exNames.isNotEmpty ? exNames : 'No movements added',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                color: context.textTertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      if (imageAsset != null)
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 200,
          child: IgnorePointer(
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.white.withValues(alpha: context.isDark ? 0.92 : 0.82),
                    Colors.white.withValues(alpha: context.isDark ? 0.60 : 0.45),
                    Colors.white.withValues(alpha: context.isDark ? 0.20 : 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 0.85, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Opacity(
                opacity: context.isDark ? 0.90 : 0.70,
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.0, 0.0),
                  errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
    ],
  ),
),
);
  }
}
