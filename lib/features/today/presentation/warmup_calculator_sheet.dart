import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../domain/models/exercise_model.dart';
import '../../../domain/services/weight_step_learner.dart';

class WarmupRampSet {
  final double percentage;
  final double weight;
  final int reps;
  final String label;

  WarmupRampSet({
    required this.percentage,
    required this.weight,
    required this.reps,
    required this.label,
  });
}

class WarmupCalculatorSheet extends StatefulWidget {
  final ExerciseModel exercise;
  final double targetWorkingWeight;
  final WeightUnit unit;
  final Function(List<WarmupRampSet> setsToAdd) onAddWarmupSets;

  const WarmupCalculatorSheet({
    super.key,
    required this.exercise,
    required this.targetWorkingWeight,
    required this.unit,
    required this.onAddWarmupSets,
  });

  @override
  State<WarmupCalculatorSheet> createState() => _WarmupCalculatorSheetState();
}

class _WarmupCalculatorSheetState extends State<WarmupCalculatorSheet> {
  late double _targetWeight;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _targetWeight = widget.targetWorkingWeight > 0 ? widget.targetWorkingWeight : 80.0;
    _weightController = TextEditingController(
      text: UnitConverter.formatWeight(_targetWeight, unit: widget.unit, includeUnit: false),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  List<WarmupRampSet> _calculateRamp() {
    final barWeight = widget.exercise.equipment == EquipmentType.barbell ? 20.0 : 10.0;
    final step = widget.exercise.weightStep > 0 ? widget.exercise.weightStep : 2.5;

    double roundToStep(double val) {
      if (val <= barWeight) return barWeight;
      return (val / step).round() * step;
    }

    final sets = <WarmupRampSet>[];

    // Ramp 1: Empty Bar / Light (40%)
    sets.add(WarmupRampSet(
      percentage: 0.2,
      weight: barWeight,
      reps: 10,
      label: 'Bar Primer',
    ));

    // Ramp 2: 50%
    if (_targetWeight > barWeight * 1.5) {
      final w50 = roundToStep(_targetWeight * 0.50);
      if (w50 > barWeight) {
        sets.add(WarmupRampSet(
          percentage: 0.50,
          weight: w50,
          reps: 5,
          label: 'Moderate Potentiation',
        ));
      }
    }

    // Ramp 3: 75%
    if (_targetWeight > barWeight * 1.8) {
      final w75 = roundToStep(_targetWeight * 0.75);
      sets.add(WarmupRampSet(
        percentage: 0.75,
        weight: w75,
        reps: 3,
        label: 'Heavy Acclimation',
      ));
    }

    // Ramp 4: 90%
    if (_targetWeight > barWeight * 2.2) {
      final w90 = roundToStep(_targetWeight * 0.90);
      sets.add(WarmupRampSet(
        percentage: 0.90,
        weight: w90,
        reps: 1,
        label: 'Neural Activation',
      ));
    }

    return sets;
  }

  @override
  Widget build(BuildContext context) {
    final rampSets = _calculateRamp();

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(
          top: BorderSide(color: context.sheetBorder, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warmupSet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: AppColors.warmupSet, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Warmup Ramp: ${widget.exercise.name}',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Non-fatiguing neural preparation ramp',
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.textTertiary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Target Weight Row
          Row(
            children: [
              Text('Target Working Weight:', style: TextStyle(fontSize: 13, color: context.textSecondary)),
              const Spacer(),
              Container(
                width: 90,
                height: 38,
                decoration: BoxDecoration(
                  color: context.inputBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: context.inputBorder),
                ),
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    suffixText: widget.unit.label,
                    suffixStyle: TextStyle(fontSize: 11, color: context.textTertiary),
                    contentPadding: const EdgeInsets.only(bottom: 4),
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val);
                    if (d != null && d > 0) {
                      setState(() => _targetWeight = d);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Ramp sets list
          ...rampSets.map((rs) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: context.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.warmupSet.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text(
                        'W',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warmupSet,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rs.label,
                          style: TextStyle(fontSize: 12, color: context.textTertiary),
                        ),
                        Text(
                          '${UnitConverter.formatWeight(rs.weight, unit: widget.unit)} × ${rs.reps} reps',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(rs.percentage * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: AppSpacing.lg),

          // Add Button
          GlassButton(
            text: 'Add ${rampSets.length} Warmup Sets',
            icon: Icons.add_circle_outline_rounded,
            style: GlassButtonStyle.primary,
            onPressed: () {
              AppHaptics.save();
              Navigator.of(context).pop();
              widget.onAddWarmupSets(rampSets);
            },
          ),
        ],
      ),
    );
  }
}
