import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/utils/haptics.dart';

class WorkoutNotesDialog extends StatefulWidget {
  final String currentTitle;
  final String? currentNote;
  final int? currentFeel;
  final Function(String title, String? note, int? feel) onSave;

  const WorkoutNotesDialog({
    super.key,
    required this.currentTitle,
    this.currentNote,
    this.currentFeel,
    required this.onSave,
  });

  @override
  State<WorkoutNotesDialog> createState() => _WorkoutNotesDialogState();
}

class _WorkoutNotesDialogState extends State<WorkoutNotesDialog> {
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  int? _selectedFeel;

  final List<String> _feelEmojis = ['😫', '😕', '😐', '🙂', '🔥'];
  final List<String> _feelLabels = ['Exhausted', 'Tough', 'Decent', 'Strong', 'Unstoppable'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);
    _noteController = TextEditingController(text: widget.currentNote ?? '');
    _selectedFeel = widget.currentFeel;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xF0121626),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(color: AppColors.glassBorderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Workout Details & Feel', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.md),

            // Title
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Session Title',
                labelStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.glassFillActive,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.glassBorderDim),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Note
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Notes (energy, injuries, form notes)',
                labelStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.glassFillActive,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.glassBorderDim),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Feel selector (1 to 5)
            const Text('How did this session feel?', style: AppTypography.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                final feelValue = index + 1;
                final isSelected = _selectedFeel == feelValue;
                return GestureDetector(
                  onTap: () {
                    AppHaptics.step();
                    setState(() => _selectedFeel = feelValue);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentCyan.withValues(alpha: 0.2)
                          : AppColors.glassTileFill,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: isSelected ? AppColors.accentCyan : AppColors.glassBorderDim,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _feelEmojis[index],
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _feelLabels[index],
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected ? AppColors.accentCyan : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Save Button
            GlassButton(
              text: 'Save Details',
              onPressed: () {
                AppHaptics.save();
                final title = _titleController.text.trim();
                final note = _noteController.text.trim();
                widget.onSave(
                  title.isEmpty ? widget.currentTitle : title,
                  note.isEmpty ? null : note,
                  _selectedFeel,
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
