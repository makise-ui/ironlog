import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../data/providers.dart';
import '../../../domain/models/exercise_model.dart';
import '../../../domain/services/weight_step_learner.dart';
import 'widgets/exercise_image_picker_sheet.dart';

class EditExerciseDialog extends ConsumerStatefulWidget {
  final ExerciseModel exercise;
  final Function(ExerciseModel updatedExercise)? onUpdated;

  const EditExerciseDialog({
    super.key,
    required this.exercise,
    this.onUpdated,
  });

  static Future<ExerciseModel?> show(
    BuildContext context, {
    required ExerciseModel exercise,
    Function(ExerciseModel updated)? onUpdated,
  }) {
    AppHaptics.tap();
    return showDialog<ExerciseModel>(
      context: context,
      builder: (ctx) => EditExerciseDialog(
        exercise: exercise,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  ConsumerState<EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends ConsumerState<EditExerciseDialog> {
  late final TextEditingController _nameController;
  late String _selectedMuscleGroupId;
  late EquipmentType _selectedEquipment;
  late LoadMode _selectedLoadMode;
  late ExerciseTrackingType _selectedTrackingType;
  late int _repMin;
  late int _repMax;
  late int _restSeconds;
  late double _weightStep;
  String? _selectedImagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise;
    _nameController = TextEditingController(text: ex.name);
    _selectedMuscleGroupId = ex.muscleGroupId;
    _selectedEquipment = ex.equipment;
    _selectedLoadMode = ex.loadMode;
    _selectedTrackingType = ex.trackingType;
    _repMin = ex.repMin;
    _repMax = ex.repMax;
    _restSeconds = ex.restSeconds;
    _weightStep = ex.weightStep;
    _selectedImagePath = ex.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openImagePicker() async {
    final name = _nameController.text.trim();
    final tempExercise = widget.exercise.copyWith(
      name: name.isNotEmpty ? name : widget.exercise.name,
      muscleGroupId: _selectedMuscleGroupId,
      equipment: _selectedEquipment,
      loadMode: _selectedLoadMode,
      customTrackingType: _selectedTrackingType,
      imagePath: _selectedImagePath,
    );

    final result = await ExerciseImagePickerSheet.show(
      context,
      exercise: tempExercise,
    );

    if (result != null && mounted) {
      setState(() {
        _selectedImagePath = result;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);
    AppHaptics.save();

    final updated = widget.exercise.copyWith(
      name: name,
      muscleGroupId: _selectedMuscleGroupId,
      equipment: _selectedEquipment,
      loadMode: _selectedLoadMode,
      customTrackingType: _selectedTrackingType,
      repMin: _repMin,
      repMax: _repMax,
      restSeconds: _restSeconds,
      weightStep: _weightStep,
      imagePath: _selectedImagePath,
    );

    try {
      final repo = ref.read(exerciseRepositoryProvider);
      await repo.updateExercise(updated);
      widget.onUpdated?.call(updated);
      if (mounted) {
        Navigator.of(context).pop(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated "${updated.name}" tracking and specs!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating exercise: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: context.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.tune_rounded, color: context.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customize Exercise',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamilyDisplay,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Adjust tracking mode, equipment & defaults',
                          style: TextStyle(fontSize: 12, color: context.textSecondary),
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
              const SizedBox(height: 16),

              // 1. Exercise Name
              Text(
                'EXERCISE NAME',
                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: context.inputBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.inputBorder),
                ),
                child: TextField(
                  controller: _nameController,
                  autofocus: false,
                  style: TextStyle(color: context.textPrimary, fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'e.g. Barbell Bench Press',
                    hintStyle: TextStyle(color: context.textTertiary, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Tracking Mode (Weight & Reps, Bodyweight, Timed Hold, Cardio)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRACKING MODE',
                    style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                  ),
                  Text(
                    _selectedTrackingType == ExerciseTrackingType.duration
                        ? 'Stopwatch / Hold (Seconds)'
                        : (_selectedTrackingType == ExerciseTrackingType.bodyweightReps
                            ? 'Bodyweight Reps (+BW)'
                            : (_selectedTrackingType == ExerciseTrackingType.cardioTime
                                ? 'Duration (Minutes)'
                                : 'Weight & Reps')),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.accent),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildTrackingChip(
                    type: ExerciseTrackingType.weightAndReps,
                    label: 'Weight & Reps',
                    subtitle: 'Standard Lift',
                    icon: Icons.fitness_center_rounded,
                  ),
                  _buildTrackingChip(
                    type: ExerciseTrackingType.bodyweightReps,
                    label: 'Bodyweight',
                    subtitle: 'Push-up / Pull-up',
                    icon: Icons.accessibility_new_rounded,
                  ),
                  _buildTrackingChip(
                    type: ExerciseTrackingType.duration,
                    label: 'Timed Hold',
                    subtitle: 'Plank / Hold (Sec)',
                    icon: Icons.timer_outlined,
                  ),
                  _buildTrackingChip(
                    type: ExerciseTrackingType.cardioTime,
                    label: 'Cardio / Sport',
                    subtitle: 'Game / Run (Min)',
                    icon: Icons.directions_run_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Equipment Type
              Text(
                'EQUIPMENT',
                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: EquipmentType.values.map((eq) {
                  final isSel = _selectedEquipment == eq;
                  return ScaleTap(
                    onPressed: () {
                      AppHaptics.selection();
                      setState(() {
                        _selectedEquipment = eq;
                        if (eq == EquipmentType.bodyweight &&
                            _selectedTrackingType == ExerciseTrackingType.weightAndReps) {
                          _selectedTrackingType = ExerciseTrackingType.bodyweightReps;
                          _selectedLoadMode = LoadMode.bodyweight;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? context.accent.withValues(alpha: 0.18) : context.chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? context.accent : context.chipBorder,
                          width: isSel ? 1.4 : 1.0,
                        ),
                      ),
                      child: Text(
                        eq.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? context.accent : context.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 4. Load Mode
              Text(
                'LOAD MODE',
                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: LoadMode.values.map((lm) {
                  final isSel = _selectedLoadMode == lm;
                  final label = switch (lm) {
                    LoadMode.total => 'Total Load',
                    LoadMode.perHand => 'Per Hand / Dumbbell',
                    LoadMode.bodyweight => 'Bodyweight (+BW)',
                    LoadMode.assisted => 'Assisted (-BW)',
                  };
                  return ScaleTap(
                    onPressed: () {
                      AppHaptics.selection();
                      setState(() => _selectedLoadMode = lm);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? context.accent.withValues(alpha: 0.18) : context.chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? context.accent : context.chipBorder,
                          width: isSel ? 1.4 : 1.0,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? context.accent : context.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 5. Target Rep Range & Rest Seconds
              Row(
                children: [
                  // Rep Range
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedTrackingType == ExerciseTrackingType.duration
                              ? 'HOLD TIME (SEC)'
                              : (_selectedTrackingType == ExerciseTrackingType.cardioTime
                                  ? 'TARGET MINS'
                                  : 'TARGET REPS'),
                          style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.inputBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  if (_repMin > 1) {
                                    setState(() {
                                      _repMin--;
                                      if (_repMax < _repMin) _repMax = _repMin;
                                    });
                                  }
                                },
                              ),
                              Text(
                                '$_repMin - $_repMax',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: context.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _repMax++;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Rest Timer
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REST TIMER',
                          style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.inputBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  if (_restSeconds >= 15) {
                                    setState(() => _restSeconds -= 15);
                                  }
                                },
                              ),
                              Text(
                                '${_restSeconds}s',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: context.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() => _restSeconds += 15);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 6. Muscle Group Selector
              Text(
                'PRIMARY MUSCLE GROUP',
                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 6),
              muscleGroupsAsync.when(
                data: (groups) => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: groups.map((g) {
                    final isSel = _selectedMuscleGroupId == g.id;
                    return ScaleTap(
                      onPressed: () {
                        AppHaptics.selection();
                        setState(() => _selectedMuscleGroupId = g.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? context.accent.withValues(alpha: 0.18) : context.chipBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? context.accent : context.chipBorder,
                            width: isSel ? 1.4 : 1.0,
                          ),
                        ),
                        child: Text(
                          g.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? context.accent : context.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const SizedBox(height: 36),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // 7. Exercise Image Preview & Picker
              Text(
                'EXERCISE VISUAL / PHOTO',
                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.inputBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2232) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.cardBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: _selectedImagePath != null
                            ? (_selectedImagePath!.startsWith('http')
                                ? Image.network(
                                    _selectedImagePath!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const ShimmerLoading(width: 50, height: 50);
                                    },
                                  )
                                : Image.file(File(_selectedImagePath!), fit: BoxFit.cover))
                            : Icon(
                                _selectedTrackingType == ExerciseTrackingType.duration
                                    ? Icons.timer_outlined
                                    : Icons.image_search_rounded,
                                size: 24,
                                color: context.textSecondary,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedImagePath != null ? 'Image Attached' : 'Default Visual',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to search or update exercise photo',
                            style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_photo_alternate_rounded, color: context.accent),
                      onPressed: _openImagePicker,
                      tooltip: 'Change Visual',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(color: context.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GlassButton(
                      text: _isSaving ? 'Saving...' : 'Save Changes',
                      icon: Icons.check_circle_rounded,
                      style: GlassButtonStyle.primary,
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingChip({
    required ExerciseTrackingType type,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final isSel = _selectedTrackingType == type;
    final context = this.context;

    return ScaleTap(
      onPressed: () {
        AppHaptics.selection();
        setState(() {
          _selectedTrackingType = type;
          if (type == ExerciseTrackingType.bodyweightReps) {
            _selectedEquipment = EquipmentType.bodyweight;
            _selectedLoadMode = LoadMode.bodyweight;
          } else if (type == ExerciseTrackingType.cardioTime) {
            _selectedEquipment = EquipmentType.other;
          }
        });
      },
      child: Container(
        width: (MediaQuery.of(context).size.width - 92) / 2,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? context.accent.withValues(alpha: 0.16) : context.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? context.accent : context.chipBorder,
            width: isSel ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSel ? context.accent : context.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? context.accent : context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: context.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
