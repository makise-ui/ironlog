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

  final List<IconData> _feelIcons = [
    Icons.sentiment_very_dissatisfied_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.local_fire_department_rounded,
  ];
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
      backgroundColor: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: context.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Workout Details & Feel',
              style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            TextField(
              controller: _titleController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'Session Title',
                labelStyle: TextStyle(color: context.textTertiary),
                filled: true,
                fillColor: context.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: context.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: context.inputBorder),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Note
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'Notes (energy, injuries, form notes)',
                labelStyle: TextStyle(color: context.textTertiary),
                filled: true,
                fillColor: context.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: context.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: context.inputBorder),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Feel selector (1 to 5)
            Text(
              'How did this session feel?',
              style: AppTypography.labelMedium.copyWith(color: context.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: List.generate(5, (index) {
                final feelValue = index + 1;
                final isSelected = _selectedFeel == feelValue;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 3,
                      right: index == 4 ? 0 : 3,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        AppHaptics.step();
                        setState(() => _selectedFeel = feelValue);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.accent.withValues(alpha: context.isDark ? 0.20 : 0.12)
                              : context.chipBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? context.accent : context.chipBorder,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _feelIcons[index],
                              size: 20,
                              color: isSelected ? context.accent : context.textSecondary,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _feelLabels[index],
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 8.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                color: isSelected ? context.textPrimary : context.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
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
