import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ironlog/core/theme/app_colors.dart';
import 'package:ironlog/core/utils/haptics.dart';
import 'package:ironlog/core/widgets/bouncy_pressable.dart';
import 'package:ironlog/core/widgets/scale_tap.dart';
import 'package:ironlog/domain/models/chibi_avatar_model.dart';

// ── Gold Sparkles Custom Painter for PR Celebrations ────────────────────────
class GoldSparklesPainter extends CustomPainter {
  final Animation<double> animation;
  GoldSparklesPainter({required this.animation}) : super(repaint: animation);

  static final List<math.Point<double>> _points = [
    const math.Point(0.12, 0.28),
    const math.Point(0.88, 0.22),
    const math.Point(0.94, 0.76),
    const math.Point(0.06, 0.78),
    const math.Point(0.50, 0.05),
    const math.Point(0.52, 0.95),
    const math.Point(0.26, 0.88),
    const math.Point(0.74, 0.45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    for (int i = 0; i < _points.length; i++) {
      final p = _points[i];
      final phase = (t + (i / _points.length)) % 1.0;
      final opacity = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final radius = 1.2 + math.sin(phase * math.pi) * 1.8;
      final center = Offset(p.x * size.width, p.y * size.height);

      final paint = Paint()
        ..color = (i % 2 == 0 ? const Color(0xFFFFD700) : const Color(0xFFFFF7C2))
            .withValues(alpha: opacity * 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, paint);

      if (i % 3 == 0 && opacity > 0.35) {
        final crossPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.85)
          ..strokeWidth = 0.8;
        final arm = radius * 1.6;
        canvas.drawLine(Offset(center.dx - arm, center.dy), Offset(center.dx + arm, center.dy), crossPaint);
        canvas.drawLine(Offset(center.dx, center.dy - arm), Offset(center.dx, center.dy + arm), crossPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GoldSparklesPainter oldDelegate) => true;
}

// ── Personal Record & Strength Milestone Showcase (Interactive In-Chat UI) ───
class PrHistoryMilestoneCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(String prompt)? onAskBreakPr;
  final ChibiAvatar? companion;

  const PrHistoryMilestoneCard({
    super.key,
    required this.data,
    this.onAskBreakPr,
    this.companion,
  });

  @override
  State<PrHistoryMilestoneCard> createState() => PrHistoryMilestoneCardState();
}

class PrHistoryMilestoneCardState extends State<PrHistoryMilestoneCard> with SingleTickerProviderStateMixin {
  late final AnimationController _sparkleController;
  double? _target1rmGoal;
  ChibiAvatar _companion = ChibiAvatar.aiko;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _initCompanion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppHaptics.success();
    });
  }

  Future<void> _initCompanion() async {
    if (widget.companion != null) {
      if (mounted) setState(() => _companion = widget.companion!);
      return;
    }
    final c = await ChibiAvatar.loadCurrent();
    if (mounted) setState(() => _companion = c);
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  String _getCompanionCelebrationQuote(ChibiAvatar companion, String? exerciseName) {
    final ex = exerciseName ?? 'this lift';
    switch (companion.id) {
      case 'shiba':
        return 'WOOF! MUCH STRENGTH! VERY GAINZ! Beast mode on $ex! 🐕🔥';
      case 'ken':
        return 'Flawless execution. Consistency and calculated overload triumph again.';
      case 'roxy':
        return 'Max wattage detected! Neurological power surge on $ex! ⚡';
      case 'bao':
        return 'Tremendous power and solid bracing! Time for a hearty protein feast! 🐼🍚';
      case 'kuro':
        return 'Precision in stillness, explosive in execution. True mastery of the iron.';
      case 'ren':
        return 'THAT is the fighting spirit! Break your limits and set the gym ablaze! 🔥';
      case 'aiko':
      default:
        return 'Amazing milestone! Your hard work on $ex is truly paying off. Proud of you! ✨';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSingle = widget.data['isSingleExercise'] == true;
    final unit = widget.data['unit']?.toString() ?? 'kg';
    final exName = widget.data['exerciseName']?.toString() ?? 'Exercise';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF161720) : const Color(0xFFFBFBFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: context.isDark ? 0.09 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Gold Sparkles
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: GoldSparklesPainter(animation: _sparkleController),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSingle ? 'PERSONAL RECORD MILESTONE' : 'RECENT PERSONAL RECORDS',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ),
                  if (isSingle && widget.data['percentageGain'] != null && widget.data['percentageGain'] != '0')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${widget.data['percentageGain']}%',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (isSingle) ...[
            const SizedBox(height: 10),
            // Exercise Title & Muscle
            Row(
              children: [
                Expanded(
                  child: Text(
                    exName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                if (widget.data['muscleGroup'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      widget.data['muscleGroup'].toString().toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: context.accent,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Milestone Stat Grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF1E202B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🥇 Max Weight',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.data['maxWeight'] ?? 0} $unit',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          'for ${widget.data['maxWeightReps'] ?? 1} reps',
                          style: TextStyle(fontSize: 10, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF1E202B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚡ Est. 1RM',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${((widget.data['peakE1rm'] as num?) ?? 0).toStringAsFixed(1)} $unit',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        const Text(
                          'Epley Formula',
                          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Chibi Companion Reaction Card
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFF1A1F2C) : const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    _companion.assetPath,
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_companion.name} celebrating your lift:',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.accent),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _getCompanionCelebrationQuote(_companion, exName),
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Rep Ladder
            if (widget.data['repLadder'] != null && widget.data['repLadder'] is Map) ...[
              const SizedBox(height: 10),
              const Text(
                'REP MAX LADDER',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  for (final entry in (widget.data['repLadder'] as Map).entries)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.isDark ? const Color(0xFF1E202B) : Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        '${entry.key}RM: ${entry.value} $unit',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ],

            // Mini Progression Timeline Curve
            if (widget.data['timeline'] != null && (widget.data['timeline'] as List).length >= 2) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: Builder(
                  builder: (context) {
                    final points = (widget.data['timeline'] as List).whereType<Map>().toList();
                    final values = points.map((p) => (p['weight'] as num).toDouble()).toList();
                    final minVal = values.reduce((a, b) => a < b ? a : b);
                    final maxVal = values.reduce((a, b) => a > b ? a : b);
                    final double minY = (minVal * 0.9).clamp(0.0, double.infinity);
                    final double maxY = maxVal > minY ? maxVal * 1.12 : minY + 10;

                    return LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 18,
                              interval: 1,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < points.length) {
                                  return Text(
                                    points[idx]['label']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: points.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble());
                            }).toList(),
                            isCurved: true,
                            color: const Color(0xFFFFD700),
                            barWidth: 2.4,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFFFFD700).withValues(alpha: 0.25),
                                  const Color(0xFFFFD700).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Interactive 1RM Goal Slider & Periodization Ramp ───────────────
            Builder(
              builder: (context) {
                final current1rm = ((widget.data['peakE1rm'] as num?) ?? (widget.data['maxWeight'] as num?) ?? 50.0).toDouble();
                final minGoal = current1rm;
                final maxGoal = math.max(minGoal + 10.0, ((current1rm * 1.35) / 2.5).ceil() * 2.5);
                _target1rmGoal ??= (((current1rm * 1.05) / 2.5).round() * 2.5).clamp(minGoal, maxGoal);
                final goalDelta = _target1rmGoal! - current1rm;
                final pctDelta = current1rm > 0 ? (goalDelta / current1rm * 100) : 0.0;

                final rep3Needed = (_target1rmGoal! * 0.93 / 2.5).round() * 2.5;
                final rep5Needed = (_target1rmGoal! * 0.86 / 2.5).round() * 2.5;
                final rep8Needed = (_target1rmGoal! * 0.79 / 2.5).round() * 2.5;

                final w1 = (_target1rmGoal! * 0.75 / 2.5).round() * 2.5;
                final w2 = (_target1rmGoal! * 0.80 / 2.5).round() * 2.5;
                final w3 = (_target1rmGoal! * 0.875 / 2.5).round() * 2.5;
                final w4 = (_target1rmGoal! / 2.5).round() * 2.5;

                final divisions = ((maxGoal - minGoal) / 2.5).round().clamp(1, 40);

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF191B24) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.track_changes_rounded, size: 14, color: Color(0xFFFFD700)),
                              SizedBox(width: 5),
                              Text(
                                'TARGET 1RM GOAL CALCULATOR',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '+${goalDelta.toStringAsFixed(1)} $unit (+${pctDelta.toStringAsFixed(1)}%)',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Target: ${_target1rmGoal!.toStringAsFixed(1)} $unit',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Current: ${current1rm.toStringAsFixed(1)} $unit',
                            style: TextStyle(fontSize: 10, color: context.textTertiary),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFFD700),
                          inactiveTrackColor: context.isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1),
                          thumbColor: const Color(0xFFFFD700),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: _target1rmGoal!.clamp(minGoal, maxGoal),
                          min: minGoal,
                          max: maxGoal,
                          divisions: divisions,
                          onChanged: (val) {
                            AppHaptics.step();
                            setState(() => _target1rmGoal = val);
                          },
                        ),
                      ),
                      // Rep Equivalent Requirements
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildRepTargetChip('3RM Need', '$rep3Needed $unit', context),
                          _buildRepTargetChip('5RM Need', '$rep5Needed $unit', context),
                          _buildRepTargetChip('8RM Need', '$rep8Needed $unit', context),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 4-Week Wave Periodization
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.isDark ? const Color(0xFF111319) : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '4-WEEK WAVE PERIODIZATION RAMP',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• W1 (Base): $w1 $unit × 8 reps\n'
                              '• W2 (Volume): $w2 $unit × 6 reps\n'
                              '• W3 (Intensify): $w3 $unit × 4 reps\n'
                              '• W4 (Peak Test): $w4 $unit × 1-2 reps',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.5,
                                height: 1.35,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ScaleTap(
                        onPressed: () {
                          AppHaptics.selection();
                          final prompt = 'Build me a dedicated 4-week wave periodization plan to take my $exName from ${current1rm.toStringAsFixed(1)} $unit to ${_target1rmGoal!.toStringAsFixed(1)} $unit.';
                          if (widget.onAskBreakPr != null) {
                            widget.onAskBreakPr!(prompt);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fitness_center_rounded, size: 12, color: Color(0xFFFFD700)),
                                const SizedBox(width: 4),
                                Text(
                                  'Ask AI to Build 4-Week Cycle for ${_target1rmGoal!.toStringAsFixed(1)} $unit',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            BouncyPressable(
              onTap: () {
                AppHaptics.selection();
                if (widget.onAskBreakPr != null) {
                  widget.onAskBreakPr!('Give me a dedicated periodized progression strategy to break my PR on $exName.');
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFFFD700)),
                    SizedBox(width: 5),
                    Text(
                      'Ask AI How to Break This PR',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Multi-Exercise Recent PRs
            const SizedBox(height: 8),
            for (final pr in (widget.data['records'] as List? ?? []))
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF1E202B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        pr['exerciseName']?.toString() ?? 'Exercise',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${pr['value'] ?? 0} $unit',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepTargetChip(String label, String value, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF111319) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.isDark ? const Color(0x1FFFFFFF) : const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
        ],
      ),
    );
  }
}





