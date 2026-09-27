import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../../../../domain/services/plate_calculator.dart';

class PlateCalculatorSheet extends StatefulWidget {
  final double initialWeight;
  final bool isLb;
  final String? exerciseName;
  final ValueChanged<double>? onApplyWeight;

  const PlateCalculatorSheet({
    super.key,
    required this.initialWeight,
    this.isLb = false,
    this.exerciseName,
    this.onApplyWeight,
  });

  static Future<double?> show({
    required BuildContext context,
    required double initialWeight,
    bool isLb = false,
    dynamic unit,
    String? exerciseName,
    ValueChanged<double>? onWeightSelected,
  }) {
    AppHaptics.tap();
    final bool calculatedIsLb = isLb || (unit != null && unit.toString().toLowerCase().contains('lb'));
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlateCalculatorSheet(
        initialWeight: initialWeight,
        isLb: calculatedIsLb,
        exerciseName: exerciseName,
        onApplyWeight: onWeightSelected,
      ),
    );
  }

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late double _weight;
  late BarType _barType;

  @override
  void initState() {
    super.initState();
    _weight = widget.initialWeight > 0 ? widget.initialWeight : 60.0;
    _barType = BarType.olympicMen;
  }

  void _adjustWeight(double delta) {
    AppHaptics.tap();
    setState(() {
      _weight = (_weight + delta).clamp(0.0, 500.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final barWeight = _barType.getWeight(widget.isLb);
    final result = PlateCalculator.calculate(
      targetWeight: _weight,
      barWeight: barWeight,
      isLb: widget.isLb,
    );
    final unit = widget.isLb ? 'lb' : 'kg';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.sheetBorder),
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
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Barbell Plate Calculator',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Optimal plate setup per side',
                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                  ),
                ],
              ),
              // Target Weight Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_weight.toStringAsFixed(1)} $unit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Barbell Visualizer
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cardBorder),
            ),
            child: Row(
              children: [
                // Bar Shaft & Collar
                Container(
                  width: 30,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                  ),
                ),
                Container(
                  width: 14,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 2),

                // Sleeve with stacked plates
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Sleeve line
                      Container(
                        height: 14,
                        color: Colors.grey.shade700,
                      ),
                      // Plates
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: result.individualPlatesPerSide.map((spec) {
                            final plateHeight = 28.0 + (spec.heightRatio * 64.0);
                            return Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Container(
                                width: spec.thickness + 2,
                                height: plateHeight,
                                decoration: BoxDecoration(
                                  color: spec.color,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 3,
                                      offset: const Offset(1, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Text(
                                      spec.weight >= 1
                                          ? spec.weight.toStringAsFixed(0)
                                          : spec.weight.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: spec.textColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Per-Side Plate Breakdown Chips
          if (result.platesPerSide.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Empty bar (${barWeight.toStringAsFixed(1)} $unit) — No plates needed',
                  style: TextStyle(fontSize: 13, color: context.textTertiary),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.platesPerSide.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.spec.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.spec.color.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: p.spec.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${p.count}x ${p.spec.weight % 1 == 0 ? p.spec.weight.toInt() : p.spec.weight} $unit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          if (!result.isExact)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Closest achievable: ${result.totalLoadedWeight} $unit (Remainder: ${result.remainder} $unit)',
                style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 16),

          // Bar Selection Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BarType>(
                value: _barType,
                dropdownColor: context.sheetBg,
                icon: Icon(Icons.arrow_drop_down, color: context.textSecondary),
                isExpanded: true,
                items: BarType.values.map((bar) {
                  return DropdownMenuItem(
                    value: bar,
                    child: Text(
                      bar.name,
                      style: TextStyle(fontSize: 13, color: context.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _barType = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Quick Weight Steppers
          Row(
            children: [
              _buildStepperBtn('-10', -10),
              const SizedBox(width: 6),
              _buildStepperBtn('-2.5', -2.5),
              const SizedBox(width: 6),
              _buildStepperBtn('+2.5', 2.5),
              const SizedBox(width: 6),
              _buildStepperBtn('+10', 10),
            ],
          ),
          const SizedBox(height: 14),

          // Action Button
          BouncyPressable(
            onTap: () {
              AppHaptics.success();
              Navigator.pop(context, _weight);
              widget.onApplyWeight?.call(_weight);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: context.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'Set Weight to ${_weight.toStringAsFixed(1)} $unit',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperBtn(String label, double delta) {
    return Expanded(
      child: BouncyPressable(
        onTap: () => _adjustWeight(delta),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.cardBorder),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
