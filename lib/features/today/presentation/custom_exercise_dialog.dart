import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../data/providers.dart';
import '../../../domain/models/exercise_model.dart';
import '../../../domain/services/weight_step_learner.dart';
import '../../../core/widgets/shimmer_loading.dart';
import 'widgets/exercise_image_picker_sheet.dart';

class CustomExerciseDialog extends ConsumerStatefulWidget {
  final String? initialMuscleGroupId;
  final Function(ExerciseModel createdExercise) onCreated;

  const CustomExerciseDialog({
    super.key,
    this.initialMuscleGroupId,
    required this.onCreated,
  });

  @override
  ConsumerState<CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends ConsumerState<CustomExerciseDialog> {
  final TextEditingController _nameController = TextEditingController();
  late String _selectedMuscleGroupId;
  EquipmentType _selectedEquipment = EquipmentType.barbell;
  ExerciseTrackingType _selectedTrackingType = ExerciseTrackingType.weightAndReps;
  String? _selectedImagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMuscleGroupId = widget.initialMuscleGroupId ?? 'chest';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openImagePicker() async {
    final name = _nameController.text.trim();
    final tempExercise = ExerciseModel(
      id: 'custom_temp_${DateTime.now().millisecondsSinceEpoch}',
      name: name.isNotEmpty ? name : 'Custom Exercise',
      muscleGroupId: _selectedMuscleGroupId,
      equipment: _selectedEquipment,
      imagePath: _selectedImagePath,
      customTrackingType: _selectedTrackingType,
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
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    AppHaptics.save();

    final repo = ref.read(exerciseRepositoryProvider);
    final newExercise = await repo.createCustomExercise(
      name: name,
      muscleGroupId: _selectedMuscleGroupId,
      equipment: _selectedEquipment,
      trackingType: _selectedTrackingType,
      imagePath: _selectedImagePath,
    );

    widget.onCreated(newExercise);
    if (mounted) {
      Navigator.of(context).pop();
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
        constraints: const BoxConstraints(maxHeight: 640),
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
                    child: Icon(Icons.add_box_rounded, color: context.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Create Custom Exercise',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    hintText: 'e.g. Incline Smith Press, Ring Push-Up',
                    hintStyle: TextStyle(color: context.textTertiary, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (val) {
                    // Auto-suggest tracking type from name if user hasn't explicitly changed it
                    final lower = val.toLowerCase();
                    if (lower.contains('plank') || lower.contains('hold') || lower.contains('sit') || lower.contains('hang')) {
                      if (_selectedTrackingType != ExerciseTrackingType.duration) {
                        setState(() => _selectedTrackingType = ExerciseTrackingType.duration);
                      }
                    } else if (lower.contains('push-up') || lower.contains('pull-up') || lower.contains('dip') || lower.contains('crunch')) {
                      if (_selectedTrackingType != ExerciseTrackingType.bodyweightReps) {
                        setState(() {
                          _selectedTrackingType = ExerciseTrackingType.bodyweightReps;
                          _selectedEquipment = EquipmentType.bodyweight;
                        });
                      }
                    } else if (lower.contains('run') || lower.contains('cardio') || lower.contains('box') || lower.contains('football')) {
                      if (_selectedTrackingType != ExerciseTrackingType.cardioTime) {
                        setState(() => _selectedTrackingType = ExerciseTrackingType.cardioTime);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 2. Tracking Mode (Standard, Bodyweight, Timed Hold, Cardio)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRACKING MODE',
                    style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                  ),
                  Text(
                    _selectedTrackingType == ExerciseTrackingType.duration
                        ? 'Stopwatch / Hold'
                        : (_selectedTrackingType == ExerciseTrackingType.bodyweightReps
                            ? 'Bodyweight Reps'
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

              // 3. Exercise Image Preview & Picker
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
                                      return const ShimmerLoading(
                                        width: 50,
                                        height: 50,
                                      );
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
                            _selectedImagePath != null ? 'Custom Image Attached' : 'No Image Selected',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedImagePath != null
                                ? 'Tap to change or search image'
                                : 'Search Wikimedia or upload from phone',
                            style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ScaleTap(
                      onPressed: _openImagePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _selectedImagePath != null ? 'Change' : 'Search',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Primary Muscle Group
              Text(
                'PRIMARY MUSCLE GROUP',
                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 6),
              muscleGroupsAsync.when(
                data: (groups) {
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: groups.map((g) {
                      final isSelected = g.id == _selectedMuscleGroupId;
                      final col = AppColors.muscleGroupColors[g.name] ?? context.accent;
                      return GestureDetector(
                        onTap: () {
                          AppHaptics.step();
                          setState(() => _selectedMuscleGroupId = g.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? col.withValues(alpha: 0.25) : context.chipBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? col : context.chipBorder,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            g.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? col : context.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const SizedBox(height: 32),
                error: (err, stack) => const SizedBox(),
              ),
              const SizedBox(height: 16),

              // 5. Equipment Type
              Text(
                'EQUIPMENT TYPE',
                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: EquipmentType.values.map((eq) {
                  final isSelected = eq == _selectedEquipment;
                  return GestureDetector(
                    onTap: () {
                      AppHaptics.step();
                      setState(() => _selectedEquipment = eq);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? context.chipSelectedBg : context.chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? context.accent : context.chipBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        eq.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? (context.isDark ? Colors.white : context.accent) : context.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    text: _isSaving ? 'Creating...' : 'Create Exercise',
                    onPressed: _isSaving ? () {} : _submit,
                    style: GlassButtonStyle.primary,
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
    final isSelected = _selectedTrackingType == type;

    return ScaleTap(
      onPressed: () {
        AppHaptics.step();
        setState(() {
          _selectedTrackingType = type;
          if (type == ExerciseTrackingType.bodyweightReps) {
            _selectedEquipment = EquipmentType.bodyweight;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accent.withValues(alpha: context.isDark ? 0.20 : 0.12)
              : context.chipBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected ? context.accent : context.chipBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? context.accent : context.textSecondary),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? context.accent : context.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
