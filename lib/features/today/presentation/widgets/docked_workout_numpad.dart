import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../../../../domain/models/active_workout_input.dart';
import '../../../../domain/models/set_model.dart';
import 'plate_calculator_sheet.dart';

class DockedWorkoutNumpad extends ConsumerWidget {
  final Future<void> Function(ActiveWorkoutInput input) onLogSet;
  final Future<void> Function(ActiveWorkoutInput input) onUpdateSet;
  final VoidCallback? onAdvanceToNextSet;

  const DockedWorkoutNumpad({
    super.key,
    required this.onLogSet,
    required this.onUpdateSet,
    this.onAdvanceToNextSet,
  });

  Color _getSetTypeColor(SetType type) {
    switch (type) {
      case SetType.warmup:
        return AppColors.warmupSet;
      case SetType.drop:
        return AppColors.dropSet;
      case SetType.failure:
        return AppColors.failureSet;
      case SetType.working:
        return AppColors.workingSet;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputState = ref.watch(activeWorkoutInputProvider);
    if (inputState == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKg = inputState.unit == WeightUnit.kg;
    final typeColor = _getSetTypeColor(inputState.setType);
    final isEditingWeight = inputState.activeField == WorkoutInputField.weight;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF8121520) : Colors.white.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF262B3D) : const Color(0xFFE2E4EE),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Top Context Toolbar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
                child: Row(
                  children: [
                    // Set Type Badge (Tap to cycle: 1 -> W -> D -> F)
                    BouncyPressable(
                      onTap: () {
                        AppHaptics.selection();
                        ref.read(activeWorkoutInputProvider.notifier).cycleSetType();
                      },
                      scaleDown: 0.90,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: isDark ? 0.22 : 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: typeColor.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              inputState.setType == SetType.working
                                  ? 'SET ${inputState.setIndex}'
                                  : inputState.setType.label.toUpperCase(),
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: typeColor,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.swap_horiz_rounded, size: 12, color: typeColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Exercise Title & Plate Breakdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inputState.exerciseName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (inputState.plateBreakdownSummary != null)
                            GestureDetector(
                              onTap: () {
                                PlateCalculatorSheet.show(
                                  context: context,
                                  initialWeight: inputState.effectiveWeight,
                                  unit: inputState.unit,
                                  exerciseName: inputState.exerciseName,
                                  onWeightSelected: (w) {
                                    ref.read(activeWorkoutInputProvider.notifier).startEditing(
                                      workoutExerciseId: inputState.workoutExerciseId,
                                      exerciseId: inputState.exerciseId,
                                      exerciseName: inputState.exerciseName,
                                      equipment: inputState.equipment,
                                      setIndex: inputState.setIndex,
                                      existingSetId: inputState.existingSetId,
                                      setType: inputState.setType,
                                      field: WorkoutInputField.weight,
                                      initialWeight: w,
                                      initialReps: inputState.effectiveReps,
                                      unit: inputState.unit,
                                      isCompleted: inputState.isCompleted,
                                    );
                                  },
                                );
                              },
                              child: Text(
                                'Plates/side: ${inputState.plateBreakdownSummary!}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.accent,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Active Value Display Tabs
                    Row(
                      children: [
                        // Weight Pill
                        BouncyPressable(
                          onTap: () {
                            AppHaptics.tap();
                            ref.read(activeWorkoutInputProvider.notifier).switchField(WorkoutInputField.weight);
                          },
                          scaleDown: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isEditingWeight
                                  ? context.accent.withValues(alpha: 0.18)
                                  : (isDark ? const Color(0xFF1B1E2B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isEditingWeight
                                    ? context.accent
                                    : (isDark ? const Color(0xFF2B3045) : const Color(0xFFE2E8F0)),
                                width: isEditingWeight ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              '${inputState.weightInput.isEmpty ? '0' : inputState.weightInput} ${inputState.unit.label}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isEditingWeight ? context.accent : context.textPrimary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Reps Pill
                        BouncyPressable(
                          onTap: () {
                            AppHaptics.tap();
                            ref.read(activeWorkoutInputProvider.notifier).switchField(WorkoutInputField.reps);
                          },
                          scaleDown: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: !isEditingWeight
                                  ? context.accent.withValues(alpha: 0.18)
                                  : (isDark ? const Color(0xFF1B1E2B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: !isEditingWeight
                                    ? context.accent
                                    : (isDark ? const Color(0xFF2B3045) : const Color(0xFFE2E8F0)),
                                width: !isEditingWeight ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              '${inputState.repsInput.isEmpty ? '0' : inputState.repsInput} reps',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: !isEditingWeight ? context.accent : context.textPrimary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Dismiss button
                        BouncyPressable(
                          onTap: () {
                            AppHaptics.tap();
                            ref.read(activeWorkoutInputProvider.notifier).close();
                          },
                          scaleDown: 0.88,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2232) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 16, color: context.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: isDark ? const Color(0xFF23283A) : const Color(0xFFE8EAF2)),

              // 2. Quick Increment Steppers Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                color: isDark ? const Color(0xFF10131D) : const Color(0xFFF8FAFC),
                child: Row(
                  children: isEditingWeight
                      ? [
                          _buildStepPill(context, ref, isKg ? -5.0 : -10.0, isKg ? '-5' : '-10', true),
                          const SizedBox(width: 8),
                          _buildStepPill(context, ref, isKg ? -2.5 : -5.0, isKg ? '-2.5' : '-5', true),
                          const SizedBox(width: 8),
                          _buildStepPill(context, ref, isKg ? 2.5 : 5.0, isKg ? '+2.5' : '+5', true),
                          const SizedBox(width: 8),
                          _buildStepPill(context, ref, isKg ? 5.0 : 10.0, isKg ? '+5' : '+10', true),
                        ]
                      : [
                          _buildRepStepPill(context, ref, -2, '-2'),
                          const SizedBox(width: 8),
                          _buildRepStepPill(context, ref, -1, '-1'),
                          const SizedBox(width: 8),
                          _buildRepStepPill(context, ref, 1, '+1'),
                          const SizedBox(width: 8),
                          _buildRepStepPill(context, ref, 2, '+2'),
                        ],
                ),
              ),

              Divider(height: 1, color: isDark ? const Color(0xFF23283A) : const Color(0xFFE8EAF2)),

              // 3. Keypad & Actions Layout
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Numeric Grid (3 columns)
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _buildKey(context, ref, '1'),
                              _buildKey(context, ref, '2'),
                              _buildKey(context, ref, '3'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildKey(context, ref, '4'),
                              _buildKey(context, ref, '5'),
                              _buildKey(context, ref, '6'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildKey(context, ref, '7'),
                              _buildKey(context, ref, '8'),
                              _buildKey(context, ref, '9'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildKey(context, ref, isEditingWeight ? '.' : '00'),
                              _buildKey(context, ref, '0'),
                              _buildBackspaceKey(context, ref),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right Side Action Column (NEXT & COMPLETE/LOG)
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // NEXT / TAB Key
                          BouncyPressable(
                            onTap: () {
                              AppHaptics.step();
                              ref.read(activeWorkoutInputProvider.notifier).toggleField();
                            },
                            scaleDown: 0.93,
                            child: Container(
                              height: 94,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1B2030) : const Color(0xFFEEF2F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2B3248) : const Color(0xFFD6DBE5),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_forward_rounded, size: 20, color: context.accent),
                                  const SizedBox(height: 4),
                                  Text(
                                    isEditingWeight ? 'REPS' : 'WEIGHT',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // LOG SET / DONE Button
                          BouncyPressable(
                            onTap: () async {
                              AppHaptics.success();
                              final state = ref.read(activeWorkoutInputProvider);
                              if (state == null) return;

                              if (state.existingSetId != null) {
                                await onUpdateSet(state);
                              } else {
                                await onLogSet(state);
                              }
                            },
                            scaleDown: 0.93,
                            child: Container(
                              height: 94,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.success,
                                    const Color(0xFF059669),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_rounded, color: Colors.white, size: 24),
                                  const SizedBox(height: 2),
                                  Text(
                                    inputState.existingSetId != null ? 'SAVE' : 'LOG SET',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepPill(
    BuildContext context,
    WidgetRef ref,
    double delta,
    String label,
    bool isWeight,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: BouncyPressable(
        onTap: () {
          AppHaptics.step();
          ref.read(activeWorkoutInputProvider.notifier).stepWeight(delta);
        },
        scaleDown: 0.92,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF191D2C) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF282E44) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRepStepPill(
    BuildContext context,
    WidgetRef ref,
    int delta,
    String label,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: BouncyPressable(
        onTap: () {
          AppHaptics.step();
          ref.read(activeWorkoutInputProvider.notifier).stepReps(delta);
        },
        scaleDown: 0.92,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF191D2C) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF282E44) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKey(BuildContext context, WidgetRef ref, String char) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: BouncyPressable(
          onTap: () {
            AppHaptics.tap();
            ref.read(activeWorkoutInputProvider.notifier).onDigit(char);
          },
          scaleDown: 0.92,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF191E2C) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF262C40) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                char,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: BouncyPressable(
          onTap: () {
            AppHaptics.tap();
            ref.read(activeWorkoutInputProvider.notifier).onBackspace();
          },
          onLongPress: () {
            AppHaptics.warning();
            ref.read(activeWorkoutInputProvider.notifier).onClear();
          },
          scaleDown: 0.92,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF191E2C) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF262C40) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Center(
              child: Icon(Icons.backspace_outlined, size: 18, color: context.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
