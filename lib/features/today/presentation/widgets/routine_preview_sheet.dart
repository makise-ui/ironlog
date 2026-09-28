import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/glass_tile.dart';
import '../../../../data/providers.dart';
import '../../../../domain/models/routine_model.dart';
import '../../../../domain/services/exercise_auto_image_service.dart';
import '../../../../domain/services/plan_share_service.dart';
import 'exercise_visual_thumbnail.dart';
import 'routine_qr_share_dialog.dart';

class RoutinePreviewSheet extends ConsumerStatefulWidget {
  final RoutineModel? routine;
  final RoutinePreviewModel? previewData;
  final bool hasActiveExercises;
  final Function(String action)? onApplyAction; // 'replace', 'append', 'load'
  final Function(RoutineModel imported)? onImportConfirmed;

  const RoutinePreviewSheet({
    super.key,
    this.routine,
    this.previewData,
    this.hasActiveExercises = false,
    this.onApplyAction,
    this.onImportConfirmed,
  }) : assert(routine != null || previewData != null);

  static Future<void> showForRoutine(
    BuildContext context, {
    required RoutineModel routine,
    required bool hasActiveExercises,
    required Function(String action) onApplyAction,
  }) {
    AppHaptics.tap();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutinePreviewSheet(
        routine: routine,
        hasActiveExercises: hasActiveExercises,
        onApplyAction: onApplyAction,
      ),
    );
  }

  static Future<void> showForScannedPreview(
    BuildContext context, {
    required RoutinePreviewModel previewData,
    required bool hasActiveExercises,
    required Function(RoutineModel imported) onImportConfirmed,
    Function(String action)? onApplyAction,
  }) {
    AppHaptics.success();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutinePreviewSheet(
        previewData: previewData,
        hasActiveExercises: hasActiveExercises,
        onImportConfirmed: onImportConfirmed,
        onApplyAction: onApplyAction,
      ),
    );
  }

  @override
  ConsumerState<RoutinePreviewSheet> createState() => _RoutinePreviewSheetState();
}

class _RoutinePreviewSheetState extends ConsumerState<RoutinePreviewSheet> {
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _prefetchExerciseVisuals();
  }

  void _prefetchExerciseVisuals() {
    final db = ref.read(databaseProvider);
    final List<({String name, String? id})> items = [];

    if (widget.routine != null) {
      for (final item in widget.routine!.items) {
        items.add((name: item.exercise.name, id: item.exercise.id));
      }
    } else if (widget.previewData != null) {
      for (final item in widget.previewData!.exercises) {
        items.add((name: item.name, id: null));
      }
    }

    ExerciseAutoImageService.prefetchBatch(items, db);
  }

  String get _title => widget.routine?.name ?? widget.previewData?.title ?? 'Workout Routine';
  String get _description => widget.routine?.description ?? widget.previewData?.description ?? '';
  int get _exerciseCount => widget.routine?.items.length ?? widget.previewData?.exercises.length ?? 0;
  int get _estimatedMinutes => (_exerciseCount * 9).clamp(20, 85);

  Set<String> get _muscleGroups {
    final Set<String> groups = {};
    if (widget.routine != null) {
      for (final i in widget.routine!.items) {
        groups.add(i.exercise.muscleGroupId.toUpperCase());
      }
    } else if (widget.previewData != null) {
      for (final i in widget.previewData!.exercises) {
        groups.add(i.muscle.toUpperCase());
      }
    }
    return groups;
  }

  void _shareRoutineQr() {
    AppHaptics.tap();
    final db = ref.read(databaseProvider);
    RoutineQrShareDialog.show(
      context,
      routineToShare: widget.routine,
      db: db,
    );
  }

  Future<void> _handleConfirmImport({bool loadAfterSave = false}) async {
    if (widget.previewData == null) return;
    setState(() => _isImporting = true);
    try {
      final db = ref.read(databaseProvider);
      final imported = await PlanShareService.importRoutineFromPayload(
        widget.previewData!.rawPayload,
        db,
      );
      AppHaptics.success();
      if (!mounted) return;
      Navigator.pop(context);
      widget.onImportConfirmed?.call(imported);

      if (loadAfterSave && widget.onApplyAction != null) {
        widget.onApplyAction!('load');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import routine: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(top: BorderSide(color: context.sheetBorder, width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag Handle
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.previewData != null ? 'SCANNED PREVIEW' : 'ROUTINE PREVIEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: context.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_exerciseCount exercises · ~${_estimatedMinutes}m',
                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _title,
                        style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.routine != null)
                  IconButton(
                    icon: Icon(Icons.qr_code_2_rounded, color: context.accent, size: 24),
                    tooltip: 'Share QR Code',
                    onPressed: _shareRoutineQr,
                  ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          if (_description.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _description,
                  style: TextStyle(fontSize: 12.5, color: context.textSecondary, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],

          // Muscle Chips
          if (_muscleGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: SizedBox(
                height: 26,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _muscleGroups.map((group) {
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        group,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          const SizedBox(height: 8),
          Divider(height: 1, color: context.cardBorder),

          // Exercise List with Live Auto-Fetched Thumbnails
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _exerciseCount,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (widget.routine != null) {
                  final item = widget.routine!.items[index];
                  return _buildExerciseRow(
                    index: index,
                    name: item.exercise.name,
                    exerciseId: item.exercise.id,
                    imagePath: item.exercise.imagePath,
                    muscleGroupId: item.exercise.muscleGroupId,
                    equipment: item.exercise.equipment.name,
                    targetSets: item.targetSets,
                    repMin: item.repMin,
                    repMax: item.repMax,
                    restSeconds: item.restSeconds,
                  );
                } else {
                  final item = widget.previewData!.exercises[index];
                  return _buildExerciseRow(
                    index: index,
                    name: item.name,
                    exerciseId: null,
                    imagePath: null,
                    muscleGroupId: item.muscle,
                    equipment: item.equipment,
                    targetSets: item.sets,
                    repMin: item.repMin,
                    repMax: item.repMax,
                    restSeconds: item.rest,
                  );
                }
              },
            ),
          ),

          // Sticky Bottom Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              MediaQuery.of(context).padding.bottom + AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: context.sheetBg,
              border: Border(top: BorderSide(color: context.cardBorder)),
            ),
            child: _buildBottomActions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow({
    required int index,
    required String name,
    required String? exerciseId,
    required String? imagePath,
    required String muscleGroupId,
    required String equipment,
    required int targetSets,
    required int repMin,
    required int repMax,
    required int restSeconds,
  }) {
    return GlassTile(
      child: Row(
        children: [
          // Index Pill
          Container(
            width: 22,
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Exercise Visual Avatar with background auto-fetching
          ExerciseVisualThumbnail(
            exerciseId: exerciseId,
            exerciseName: name,
            imagePath: imagePath,
            muscleGroupId: muscleGroupId,
            equipment: equipment,
            size: 44,
          ),
          const SizedBox(width: 12),

          // Title & Sets/Reps specs
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.workingSet.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$targetSets sets · $repMin–$repMax reps',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.workingSet,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${restSeconds}s rest',
                      style: TextStyle(fontSize: 11, color: context.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    // If previewing a scanned QR code
    if (widget.previewData != null) {
      if (_isImporting) {
        return Center(child: CircularProgressIndicator(color: context.accent));
      }
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: context.accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _handleConfirmImport(loadAfterSave: false),
              child: Text(
                'Save to Presets',
                style: TextStyle(color: context.accent, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: context.isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _handleConfirmImport(loadAfterSave: true),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, size: 18),
                  SizedBox(width: 4),
                  Text('Import & Load', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // If previewing an existing routine to load into today's workout
    if (widget.hasActiveExercises) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                AppHaptics.warning();
                Navigator.pop(context);
                widget.onApplyAction?.call('replace');
              },
              child: const Text(
                'Replace Session',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: context.isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                AppHaptics.success();
                Navigator.pop(context);
                widget.onApplyAction?.call('append');
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 18),
                  SizedBox(width: 4),
                  Text('Add to Workout', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accent,
          foregroundColor: context.isDark ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          AppHaptics.success();
          Navigator.pop(context);
          widget.onApplyAction?.call('load');
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, size: 18),
            SizedBox(width: 6),
            Text('Load into Today\'s Workout', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
