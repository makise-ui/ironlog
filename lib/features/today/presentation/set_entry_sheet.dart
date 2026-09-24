import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/custom_number_pad.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../domain/models/exercise_model.dart';
import '../../../domain/models/set_model.dart';
import '../../../data/providers.dart';

enum ActiveInputMode { weight, reps }

class SetEntrySheet extends ConsumerStatefulWidget {
  final ExerciseModel exercise;
  final String workoutExerciseId;
  final double learnedWeightStep;
  final SetModel? previousSessionSet;
  final SetModel? existingSetToEdit;
  final int nextSetIndex;
  final double sessionMaxWeight;

  const SetEntrySheet({
    super.key,
    required this.exercise,
    required this.workoutExerciseId,
    required this.learnedWeightStep,
    this.previousSessionSet,
    this.existingSetToEdit,
    required this.nextSetIndex,
    this.sessionMaxWeight = 0.0,
  });

  @override
  ConsumerState<SetEntrySheet> createState() => _SetEntrySheetState();
}

class _SetEntrySheetState extends ConsumerState<SetEntrySheet> {
  ActiveInputMode _activeMode = ActiveInputMode.weight;

  String _weightInput = '';
  String _repsInput = '';

  late SetType _setType;
  double? _rpe;

  late double _weightStep;

  @override
  void initState() {
    super.initState();
    _weightStep = widget.learnedWeightStep > 0
        ? widget.learnedWeightStep
        : widget.exercise.weightStep;

    if (widget.existingSetToEdit != null) {
      final s = widget.existingSetToEdit!;
      _weightInput = UnitConverter.formatWeight(s.weight, includeUnit: false);
      _repsInput = s.reps.toString();
      _setType = s.setType;
      _rpe = s.rpe;
    } else {
      // Auto-suggest warmup for set 1 if significantly below session max
      if (widget.nextSetIndex == 1 && widget.sessionMaxWeight > 0) {
        final ghostW = widget.previousSessionSet?.weight ?? 0.0;
        if (ghostW > 0 && ghostW <= widget.sessionMaxWeight * 0.8) {
          _setType = SetType.warmup;
        } else {
          _setType = SetType.working;
        }
      } else {
        _setType = SetType.working;
      }
    }
  }

  double get _effectiveWeight {
    if (_weightInput.isNotEmpty) {
      return double.tryParse(_weightInput) ?? 0.0;
    }
    return widget.previousSessionSet?.weight ?? 0.0;
  }

  int get _effectiveReps {
    if (_repsInput.isNotEmpty) {
      return int.tryParse(_repsInput) ?? 0;
    }
    return widget.previousSessionSet?.reps ?? widget.exercise.repMin;
  }

  void _onDigitPressed(String digit) {
    AppHaptics.step();
    setState(() {
      if (_activeMode == ActiveInputMode.weight) {
        if (digit == '.' && _weightInput.contains('.')) return;
        if (_weightInput.length < 6) {
          _weightInput += digit;
        }
      } else {
        if (digit == '.') return; // Reps cannot have decimals
        if (_repsInput.length < 3) {
          _repsInput += digit;
        }
      }
    });
  }

  void _onBackspace() {
    AppHaptics.tap();
    setState(() {
      if (_activeMode == ActiveInputMode.weight) {
        if (_weightInput.isNotEmpty) {
          _weightInput = _weightInput.substring(0, _weightInput.length - 1);
        }
      } else {
        if (_repsInput.isNotEmpty) {
          _repsInput = _repsInput.substring(0, _repsInput.length - 1);
        }
      }
    });
  }

  void _onClear() {
    AppHaptics.tap();
    setState(() {
      if (_activeMode == ActiveInputMode.weight) {
        _weightInput = '';
      } else {
        _repsInput = '';
      }
    });
  }

  void _stepWeight(double delta) {
    AppHaptics.step();
    setState(() {
      final current = _effectiveWeight;
      final next = (current + delta).clamp(0.0, 999.0);
      _weightInput = UnitConverter.formatWeight(next, includeUnit: false);
    });
  }

  void _stepReps(int delta) {
    AppHaptics.step();
    setState(() {
      final current = _effectiveReps;
      final next = (current + delta).clamp(1, 999);
      _repsInput = next.toString();
    });
  }

  Future<void> _saveSet() async {
    final weight = _effectiveWeight;
    final reps = _effectiveReps;

    if (reps <= 0) return;

    AppHaptics.save();
    final repo = ref.read(workoutRepositoryProvider);

    if (widget.existingSetToEdit != null) {
      await repo.updateSet(
        setId: widget.existingSetToEdit!.id,
        weight: weight,
        reps: reps,
        setType: _setType,
        rpe: _rpe,
      );
    } else {
      await repo.logSet(
        workoutExerciseId: widget.workoutExerciseId,
        exerciseId: widget.exercise.id,
        muscleGroupId: widget.exercise.muscleGroupId,
        date: DateTime.now(),
        weight: weight,
        reps: reps,
        setType: _setType,
        rpe: _rpe,
      );

      // Start rest timer automatically
      ref.read(restTimerProvider).start(
        seconds: widget.exercise.restSeconds,
        exerciseName: widget.exercise.name,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteExistingSet() async {
    if (widget.existingSetToEdit == null) return;
    AppHaptics.warning();
    final repo = ref.read(workoutRepositoryProvider);
    await repo.deleteSet(widget.existingSetToEdit!.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitNotifierProvider);

    final ghostWeight = widget.previousSessionSet != null
        ? UnitConverter.formatWeight(widget.previousSessionSet!.weight, unit: unit, includeUnit: false)
        : '0';
    final ghostReps = widget.previousSessionSet != null
        ? widget.previousSessionSet!.reps.toString()
        : widget.exercise.repMin.toString();

    final isWeightGhost = _weightInput.isEmpty;
    final isRepsGhost = _repsInput.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(
          top: BorderSide(color: context.sheetBorder, width: 1.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.exercise.name,
                      style: AppTypography.titleMedium.copyWith(color: context.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Set ${widget.existingSetToEdit?.setIndex ?? widget.nextSetIndex} • Step ${_weightStep.toStringAsFixed(1)} ${unit.name}',
                      style: AppTypography.labelSmall.copyWith(color: context.textTertiary),
                    ),
                  ],
                ),
              ),
              // Set type selector
              _buildSetTypeChip(SetType.warmup, 'Warmup', AppColors.warmupSet),
              const SizedBox(width: 4),
              _buildSetTypeChip(SetType.working, 'Working', AppColors.workingSet),
              const SizedBox(width: 4),
              _buildSetTypeChip(SetType.drop, 'Drop', AppColors.dropSet),
              const SizedBox(width: 4),
              _buildSetTypeChip(SetType.failure, 'Fail', AppColors.failureSet),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Dual Input Cards (Weight & Reps)
          Row(
            children: [
              // Weight Box
              Expanded(
                child: _buildInputBox(
                  title: 'WEIGHT (${unit.name})',
                  displayValue: isWeightGhost ? ghostWeight : _weightInput,
                  isGhost: isWeightGhost,
                  isActive: _activeMode == ActiveInputMode.weight,
                  onTap: () {
                    AppHaptics.tap();
                    setState(() => _activeMode = ActiveInputMode.weight);
                  },
                  onMinus: () => _stepWeight(-_weightStep),
                  onPlus: () => _stepWeight(_weightStep),
                  stepLabel: _weightStep.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Reps Box
              Expanded(
                child: _buildInputBox(
                  title: 'REPS',
                  displayValue: isRepsGhost ? ghostReps : _repsInput,
                  isGhost: isRepsGhost,
                  isActive: _activeMode == ActiveInputMode.reps,
                  onTap: () {
                    AppHaptics.tap();
                    setState(() => _activeMode = ActiveInputMode.reps);
                  },
                  onMinus: () => _stepReps(-1),
                  onPlus: () => _stepReps(1),
                  stepLabel: '1',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Custom Numeric Keypad
          CustomNumberPad(
            showDecimal: _activeMode == ActiveInputMode.weight,
            onDigitPressed: _onDigitPressed,
            onBackspace: _onBackspace,
            onClear: _onClear,
          ),
          const SizedBox(height: AppSpacing.md),

          // Action Save / Delete Buttons
          if (widget.existingSetToEdit != null)
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    text: 'Delete Set',
                    icon: Icons.delete_outline_rounded,
                    style: GlassButtonStyle.danger,
                    height: 52,
                    onPressed: _deleteExistingSet,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: GlassButton(
                    text: 'Update Set',
                    icon: Icons.check_circle_outline_rounded,
                    height: 52,
                    onPressed: _saveSet,
                  ),
                ),
              ],
            )
          else
            GlassButton(
              text: 'Log Set (Save)',
              icon: Icons.check_circle_outline_rounded,
              height: 52,
              onPressed: _saveSet,
            ),
        ],
      ),
    );
  }

  Widget _buildSetTypeChip(SetType type, String label, Color color) {
    final isSelected = _setType == type;
    return GestureDetector(
      onTap: () {
        AppHaptics.step();
        setState(() => _setType = type);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected ? color : AppColors.glassBorderDim,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : context.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox({
    required String title,
    required String displayValue,
    required bool isGhost,
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required String stepLabel,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isActive
              ? (context.isDark ? AppColors.glassFillActive : const Color(0xFFF1F5F9))
              : context.inputBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            width: 1.5,
            color: isActive ? context.accent : context.inputBorder,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? context.accent : context.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              displayValue.isEmpty ? '0' : displayValue,
              style: AppTypography.numberDisplay.copyWith(
                color: isGhost ? context.textTertiary : context.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStepButton(
                  icon: Icons.remove,
                  label: '-$stepLabel',
                  onTap: onMinus,
                ),
                _buildStepButton(
                  icon: Icons.add,
                  label: '+$stepLabel',
                  onTap: onPlus,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: context.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: context.textPrimary),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
