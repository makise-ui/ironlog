import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../../../../core/widgets/glass_button.dart';

enum BarType {
  olympicMen('Olympic Bar', 20.0, 45.0),
  olympicWomen('Women\'s Bar', 15.0, 35.0),
  trapBar('Trap / Hex Bar', 25.0, 55.0),
  ezCurl('EZ Curl Bar', 10.0, 25.0),
  custom('Custom / Smith', 0.0, 0.0);

  final String label;
  final double kgWeight;
  final double lbWeight;

  const BarType(this.label, this.kgWeight, this.lbWeight);

  double weight(WeightUnit unit) => unit == WeightUnit.kg ? kgWeight : lbWeight;
}

class PlateInfo {
  final double weight;
  final Color color;
  final Color textColor;
  final double heightRatio; // For visual plate diameter

  const PlateInfo({
    required this.weight,
    required this.color,
    required this.textColor,
    required this.heightRatio,
  });
}

class PlateCalculatorSheet extends StatefulWidget {
  final double initialWeight;
  final WeightUnit unit;
  final String? exerciseName;
  final ValueChanged<double>? onWeightSelected;

  const PlateCalculatorSheet({
    super.key,
    required this.initialWeight,
    required this.unit,
    this.exerciseName,
    this.onWeightSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required double initialWeight,
    required WeightUnit unit,
    String? exerciseName,
    ValueChanged<double>? onWeightSelected,
  }) {
    AppHaptics.tap();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlateCalculatorSheet(
        initialWeight: initialWeight,
        unit: unit,
        exerciseName: exerciseName,
        onWeightSelected: onWeightSelected,
      ),
    );
  }

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late double _targetWeight;
  BarType _selectedBar = BarType.olympicMen;
  final bool _includeCollars = false; // 2x 2.5kg or 2x 5lb

  // Standard Olympic Plates (KG)
  static const List<PlateInfo> _kgPlates = [
    PlateInfo(weight: 25.0, color: Color(0xFFEF4444), textColor: Colors.white, heightRatio: 1.0),
    PlateInfo(weight: 20.0, color: Color(0xFF2563EB), textColor: Colors.white, heightRatio: 1.0),
    PlateInfo(weight: 15.0, color: Color(0xFFEAB308), textColor: Colors.black, heightRatio: 0.88),
    PlateInfo(weight: 10.0, color: Color(0xFF16A34A), textColor: Colors.white, heightRatio: 0.78),
    PlateInfo(weight: 5.0, color: Color(0xFFF8FAFC), textColor: Colors.black, heightRatio: 0.65),
    PlateInfo(weight: 2.5, color: Color(0xFF334155), textColor: Colors.white, heightRatio: 0.55),
    PlateInfo(weight: 1.25, color: Color(0xFF94A3B8), textColor: Colors.black, heightRatio: 0.45),
  ];

  // Standard Olympic Plates (LB)
  static const List<PlateInfo> _lbPlates = [
    PlateInfo(weight: 45.0, color: Color(0xFF2563EB), textColor: Colors.white, heightRatio: 1.0),
    PlateInfo(weight: 35.0, color: Color(0xFFEAB308), textColor: Colors.black, heightRatio: 0.88),
    PlateInfo(weight: 25.0, color: Color(0xFF16A34A), textColor: Colors.white, heightRatio: 0.78),
    PlateInfo(weight: 10.0, color: Color(0xFFF8FAFC), textColor: Colors.black, heightRatio: 0.65),
    PlateInfo(weight: 5.0, color: Color(0xFF334155), textColor: Colors.white, heightRatio: 0.55),
    PlateInfo(weight: 2.5, color: Color(0xFF94A3B8), textColor: Colors.black, heightRatio: 0.45),
  ];

  @override
  void initState() {
    super.initState();
    _targetWeight = widget.initialWeight > 0 ? widget.initialWeight : (_selectedBar.weight(widget.unit) + 20.0);
  }

  void _adjustWeight(double delta) {
    AppHaptics.step();
    setState(() {
      _targetWeight = math.max(0.0, _targetWeight + delta);
    });
  }

  double get _collarWeight => _includeCollars ? (widget.unit == WeightUnit.kg ? 5.0 : 10.0) : 0.0;

  Map<PlateInfo, int> _calculatePlatesPerSide() {
    final barWeight = _selectedBar.weight(widget.unit) + _collarWeight;
    final remainingPerSide = math.max(0.0, (_targetWeight - barWeight) / 2.0);

    final availablePlates = widget.unit == WeightUnit.kg ? _kgPlates : _lbPlates;
    final result = <PlateInfo, int>{};

    double currentRemaining = remainingPerSide;
    const epsilon = 0.001;

    for (final plate in availablePlates) {
      if (currentRemaining + epsilon >= plate.weight) {
        final count = (currentRemaining / plate.weight).floor();
        if (count > 0) {
          result[plate] = count;
          currentRemaining -= count * plate.weight;
        }
      }
    }

    return result;
  }

  double get _remainderPerSide {
    final barWeight = _selectedBar.weight(widget.unit) + _collarWeight;
    final remainingPerSide = math.max(0.0, (_targetWeight - barWeight) / 2.0);
    final plates = _calculatePlatesPerSide();
    double loaded = 0;
    plates.forEach((plate, count) {
      loaded += plate.weight * count;
    });
    return (remainingPerSide - loaded).clamp(0.0, 999.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final platesPerSide = _calculatePlatesPerSide();
    final remainder = _remainderPerSide;
    final unitLabel = widget.unit.label.toUpperCase();
    final barWeight = _selectedBar.weight(widget.unit) + _collarWeight;
    final perSideTotal = math.max(0.0, (_targetWeight - barWeight) / 2.0);

    return Container(
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.sheetBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handlebar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.handleBar,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.fitness_center_rounded, color: context.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plate Calculator',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamilyDisplay,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            widget.exerciseName != null
                                ? 'Loading for ${widget.exerciseName}'
                                : 'Exact plates per barbell sleeve',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    BouncyPressable(
                      onTap: () => Navigator.pop(context),
                      scaleDown: 0.90,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.chipBg,
                          border: Border.all(color: context.chipBorder),
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: context.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Target Weight Display & Quick Steppers
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.cardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          UnitConverter.formatWeight(_targetWeight, unit: widget.unit, includeUnit: false),
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamilyDisplay,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: context.textPrimary,
                            letterSpacing: -1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          unitLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Steppers
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildStepperPill('-10', () => _adjustWeight(-10)),
                        _buildStepperPill('-2.5', () => _adjustWeight(-2.5)),
                        _buildStepperPill('-1.25', () => _adjustWeight(-1.25)),
                        _buildStepperPill('+1.25', () => _adjustWeight(1.25)),
                        _buildStepperPill('+2.5', () => _adjustWeight(2.5)),
                        _buildStepperPill('+10', () => _adjustWeight(10)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Barbell Graphic
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1118) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.cardBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CustomPaint(
                    painter: _BarbellSleevePainter(
                      plates: platesPerSide,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Bar Type Selector & Collars Toggle
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    ...BarType.values.map((bar) {
                      final isSelected = _selectedBar == bar;
                      final barW = bar.weight(widget.unit);
                      final label = barW > 0 ? '${bar.label} (${barW.toStringAsFixed(barW.truncateToDouble() == barW ? 0 : 1)}$unitLabel)' : bar.label;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: BouncyPressable(
                          onTap: () {
                            AppHaptics.step();
                            setState(() => _selectedBar = bar);
                          },
                          scaleDown: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? context.accent.withValues(alpha: 0.16) : context.chipBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? context.accent : context.chipBorder,
                                width: isSelected ? 1.2 : 0.8,
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? (isDark ? context.accent : context.textPrimary) : context.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Per Side Breakdown Details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.layers_rounded, size: 16, color: AppColors.workingSet),
                              const SizedBox(width: 6),
                              Text(
                                'Per Side: ${perSideTotal.toStringAsFixed(perSideTotal.truncateToDouble() == perSideTotal ? 0 : 2)} $unitLabel',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Bar: ${barWeight.toStringAsFixed(0)} $unitLabel',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (platesPerSide.isEmpty)
                        Text(
                          'No plates needed (lift empty bar)',
                          style: TextStyle(fontSize: 12, color: context.textTertiary, fontStyle: FontStyle.italic),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: platesPerSide.entries.map((entry) {
                            final plate = entry.key;
                            final count = entry.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: plate.color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: plate.color.withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: plate.color,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$count × ${plate.weight.toStringAsFixed(plate.weight.truncateToDouble() == plate.weight ? 0 : 2)} $unitLabel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      if (remainder > 0.01) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Text(
                              'Remainder per side: ${remainder.toStringAsFixed(2)} $unitLabel',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: GlassButton(
                  text: widget.onWeightSelected != null ? 'Apply Weight (${_targetWeight.toStringAsFixed(_targetWeight.truncateToDouble() == _targetWeight ? 0 : 1)} $unitLabel)' : 'Done',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    AppHaptics.success();
                    widget.onWeightSelected?.call(_targetWeight);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperPill(String label, VoidCallback onTap) {
    return BouncyPressable(
      onTap: onTap,
      scaleDown: 0.90,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.chipBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Custom painter that renders a realistic Olympic barbell sleeve and stacked plates
class _BarbellSleevePainter extends CustomPainter {
  final Map<PlateInfo, int> plates;
  final bool isDark;

  _BarbellSleevePainter({required this.plates, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final shaftPaint = Paint()
      ..color = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;

    // Barbell Shaft (left side)
    canvas.drawRect(
      Rect.fromLTWH(0, centerY - 5, size.width * 0.22, 10),
      shaftPaint,
    );

    // Inner Collar Stop
    final collarPaint = Paint()
      ..color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.22, centerY - 24, 12, 48),
        const Radius.circular(2),
      ),
      collarPaint,
    );

    // Barbell Sleeve (silver cylinder)
    final sleevePaint = Paint()
      ..shader = LinearGradient(
        colors: isDark
            ? [const Color(0xFF475569), const Color(0xFF94A3B8), const Color(0xFF334155)]
            : [const Color(0xFFCBD5E1), const Color(0xFFF1F5F9), const Color(0xFF94A3B8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(size.width * 0.22 + 12, centerY - 10, size.width * 0.70, 20));

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.22 + 12, centerY - 10, size.width * 0.70, 20),
      sleevePaint,
    );

    // Draw Stacked Plates from collar outwards
    double currentX = size.width * 0.22 + 15;
    const maxPlateHeight = 78.0;

    for (final entry in plates.entries) {
      final plate = entry.key;
      final count = entry.value;
      final plateHeight = maxPlateHeight * plate.heightRatio;
      final plateWidth = math.max(10.0, 16.0 * (plate.weight >= 20 ? 1.0 : (plate.weight / 20.0)));

      for (int i = 0; i < count; i++) {
        if (currentX + plateWidth > size.width - 20) break;

        final plateRect = Rect.fromLTWH(
          currentX,
          centerY - (plateHeight / 2),
          plateWidth,
          plateHeight,
        );

        // Plate disc
        final discPaint = Paint()..color = plate.color;
        canvas.drawRRect(
          RRect.fromRectAndRadius(plateRect, const Radius.circular(3)),
          discPaint,
        );

        // Subtle dark rim
        final borderPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(plateRect, const Radius.circular(3)),
          borderPaint,
        );

        // Text label on plate
        if (plateWidth >= 12 && plateHeight >= 30) {
          final tp = TextPainter(
            text: TextSpan(
              text: plate.weight.toStringAsFixed(plate.weight.truncateToDouble() == plate.weight ? 0 : 1),
              style: TextStyle(
                color: plate.textColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          canvas.save();
          canvas.translate(currentX + plateWidth / 2, centerY);
          canvas.rotate(-math.pi / 2);
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
        }

        currentX += plateWidth + 3.0;
      }
    }

    // Outer Sleeve Cap
    final capPaint = Paint()..color = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.22 + 12 + size.width * 0.70 - 4, centerY - 11, 6, 22),
        const Radius.circular(2),
      ),
      capPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BarbellSleevePainter oldDelegate) => true;
}
