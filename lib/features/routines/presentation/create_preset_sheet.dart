import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../data/providers.dart';
import '../../../domain/models/exercise_model.dart';
import '../../today/presentation/exercise_picker_sheet.dart';
import '../../today/presentation/widgets/ai_assistant_sheet.dart';

class CreatePresetSheet extends ConsumerStatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final List<ExerciseModel>? initialExercises;

  const CreatePresetSheet({
    super.key,
    this.initialName,
    this.initialDescription,
    this.initialExercises,
  });

  static Future<String?> show(
    BuildContext context, {
    String? initialName,
    String? initialDescription,
    List<ExerciseModel>? initialExercises,
  }) {
    AppHaptics.tap();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePresetSheet(
        initialName: initialName,
        initialDescription: initialDescription,
        initialExercises: initialExercises,
      ),
    );
  }

  @override
  ConsumerState<CreatePresetSheet> createState() => _CreatePresetSheetState();
}

class _CreatePresetSheetState extends ConsumerState<CreatePresetSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final List<ExerciseModel> _selectedExercises = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descController = TextEditingController(text: widget.initialDescription ?? '');
    if (widget.initialExercises != null) {
      _selectedExercises.addAll(widget.initialExercises!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _openExercisePicker() {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExercisePickerSheet(
        workoutId: 'preset_temp',
        onExerciseSelected: (ex) {
          if (!_selectedExercises.any((e) => e.id == ex.id)) {
            setState(() {
              _selectedExercises.add(ex);
            });
          }
        },
      ),
    );
  }

  Future<void> _savePreset() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a preset name')),
      );
      return;
    }

    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise to the preset')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(routineRepositoryProvider);
      final id = await repo.createRoutine(
        name: name,
        description: _descController.text.trim(),
        exerciseIds: _selectedExercises.map((e) => e.id).toList(),
      );

      AppHaptics.success();
      if (mounted) {
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preset: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(top: BorderSide(color: context.sheetBorder, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Create Custom Preset',
                style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                // AI Routine Builder Banner
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentViolet.withValues(alpha: 0.16),
                        context.accent.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.35), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.accentViolet.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accentViolet, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Let AI Build Your Routine',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Don\'t know which exercises to pick? The AI Coach can formulate an evidence-based workout split based on your target muscle focus and equipment.',
                        style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentViolet,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            AppHaptics.tap();
                            Navigator.pop(context);
                            AiAssistantSheet.show(
                              context,
                              initialPrompt:
                                  'Can you design a balanced, evidence-based workout routine for me? Ask me any questions you need about my weekly frequency, training experience, and available gym equipment.',
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                          label: const Text(
                            'Ask AI Coach',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Preset Name
                Text(
                  'PRESET NAME',
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
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Upper Body Hypertrophy',
                      hintStyle: TextStyle(color: context.textTertiary, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Description
                Text(
                  'DESCRIPTION (OPTIONAL)',
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
                    controller: _descController,
                    maxLines: 2,
                    style: TextStyle(color: context.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Chest, Back and Shoulders focus',
                      hintStyle: TextStyle(color: context.textTertiary, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Exercises Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EXERCISES (${_selectedExercises.length})',
                      style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                    ),
                    TextButton.icon(
                      onPressed: _openExercisePicker,
                      icon: Icon(Icons.add_rounded, size: 16, color: context.accent),
                      label: Text(
                        'Add Exercise',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (_selectedExercises.isEmpty)
                  GestureDetector(
                    onTap: _openExercisePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: context.isDark ? const Color(0x0CFFFFFF) : Colors.white,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: context.cardBorder, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 28, color: context.textTertiary),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add exercises to this preset',
                            style: TextStyle(fontSize: 13, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._selectedExercises.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ex = entry.value;
                    final mgColor = AppColors.muscleGroupColors[ex.muscleGroupId] ?? context.accent;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: context.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: context.isDark ? const Color(0x18FFFFFF) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: mgColor),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${ex.muscleGroupId} • ${ex.equipment.name}',
                                      style: TextStyle(fontSize: 11, color: context.textTertiary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppColors.error),
                            onPressed: () {
                              setState(() {
                                _selectedExercises.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GlassButton(
            text: _isSaving ? 'Saving Preset...' : 'Save & Create Preset',
            icon: Icons.check_circle_outline_rounded,
            style: GlassButtonStyle.primary,
            onPressed: _isSaving ? () {} : _savePreset,
          ),
        ],
      ),
    );
  }
}
