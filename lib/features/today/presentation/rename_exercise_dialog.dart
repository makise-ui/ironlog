import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../data/providers.dart';
import '../../../domain/models/exercise_model.dart';

class RenameExerciseDialog extends ConsumerStatefulWidget {
  final ExerciseModel exercise;
  final VoidCallback onRenamed;

  const RenameExerciseDialog({
    super.key,
    required this.exercise,
    required this.onRenamed,
  });

  @override
  ConsumerState<RenameExerciseDialog> createState() => _RenameExerciseDialogState();
}

class _RenameExerciseDialogState extends ConsumerState<RenameExerciseDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.exercise.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty || newName == widget.exercise.name) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    AppHaptics.save();

    final repo = ref.read(exerciseRepositoryProvider);
    await repo.renameExercise(widget.exercise.id, newName);

    widget.onRenamed();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
                  child: Icon(Icons.edit_rounded, color: context.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rename Exercise',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamilyDisplay,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Set a custom name or nickname for "${widget.exercise.name}":',
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: context.inputBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: context.inputBorder),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Incline DB Press (30° Paused)',
                  hintStyle: TextStyle(color: context.textTertiary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: context.textTertiary, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                GlassButton(
                  text: _isSaving ? 'Saving...' : 'Save Name',
                  onPressed: _isSaving ? () {} : _save,
                  style: GlassButtonStyle.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
