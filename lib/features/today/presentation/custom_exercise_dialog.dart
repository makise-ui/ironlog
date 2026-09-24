import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../data/providers.dart';
import '../../../domain/models/exercise_model.dart';
import '../../../domain/services/weight_step_learner.dart';

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
    );

    widget.onCreated(newExercise);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: context.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.6 : 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  autofocus: true,
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'e.g. Incline Smith Machine Press',
                    hintStyle: TextStyle(color: context.textTertiary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
}
