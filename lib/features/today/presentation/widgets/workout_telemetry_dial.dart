import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Precision Biometric Telemetry Dial inspired by WHOOP 4.0, Bevel Health,
/// and Apple Watch Activity rings.
///
/// Renders an anti-aliased concentric dual-arc gauge with smooth rounded caps,
/// a vibrant gradient stroke, and an engineered central readout hub.
class WorkoutTelemetryDial extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String valueText;
  final String label;
  final double size;
  final bool compact;
  final Color? accentColor;

  const WorkoutTelemetryDial({
    super.key,
    required this.progress,
    required this.valueText,
    this.label = 'LOAD',
    this.size = 88.0,
    this.compact = false,
    this.accentColor,
  });

  /// Factory for compact micro-gauge on RoutineCards
  factory WorkoutTelemetryDial.compact({
    Key? key,
    required double progress,
    required String valueText,
    Color? accentColor,
    double size = 42.0,
  }) {
    return WorkoutTelemetryDial(
      key: key,
      progress: progress,
      valueText: valueText,
      size: size,
      compact: true,
      accentColor: accentColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? context.accent;

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Ambient radial backlight aura behind the dial
            if (!compact)
              Container(
                width: size * 0.95,
                height: size * 0.95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.22 : 0.14),
                      accent.withValues(alpha: isDark ? 0.06 : 0.02),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),

            // 2. Dual-Arc Telemetry Gauge
            CustomPaint(
              size: Size(size, size),
              painter: _TelemetryDialPainter(
                progress: progress.clamp(0.05, 1.0),
                accentColor: accent,
                isDark: isDark,
                compact: compact,
              ),
            ),

            // 3. Central Instrumentation Readout
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  valueText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: compact ? (size * 0.28) : 17.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: compact ? -0.5 : -0.2,
                    color: context.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryDialPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final bool isDark;
  final bool compact;

  _TelemetryDialPainter({
    required this.progress,
    required this.accentColor,
    required this.isDark,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = compact ? 3.5 : 6.0;
    final radius = (size.width - strokeWidth) / 2;

    // Start angle at bottom-left (-225 degrees) sweeping 270 degrees towards bottom-right
    const startAngle = 135 * pi / 180;
    const totalSweep = 270 * pi / 180;
    final currentSweep = totalSweep * progress;

    // ── 1. Inactive Track Arc ──
    final trackColor = isDark
        ? const Color(0xFF1E212A)
        : const Color(0xFFE2E5EC);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // ── 2. Subtle Inner Telemetry Reticle Arc (Standard size only) ──
    if (!compact) {
      final innerRadius = radius - 7.5;
      final innerTrackPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        totalSweep,
        false,
        innerTrackPaint,
      );

      // Micro tick marks at 25%, 50%, 75%
      final tickPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      for (int i = 0; i <= 4; i++) {
        final tickAngle = startAngle + (totalSweep * (i / 4));
        final p1 = Offset(
          center.dx + cos(tickAngle) * (innerRadius - 2),
          center.dy + sin(tickAngle) * (innerRadius - 2),
        );
        final p2 = Offset(
          center.dx + cos(tickAngle) * (innerRadius + 2),
          center.dy + sin(tickAngle) * (innerRadius + 2),
        );
        canvas.drawLine(p1, p2, tickPaint);
      }
    }

    // ── 3. Active Progress Arc with Gradient ──
    // Create a dynamic gradient hue shift (from accent to high-energy cyan/violet)
    final gradientColors = [
      accentColor.withValues(alpha: 0.85),
      accentColor,
    ];

    final progressShader = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + totalSweep,
      colors: gradientColors,
      transform: GradientRotation(startAngle),
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Outer bloom shadow
    final bloomPaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.35 : 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..isAntiAlias = true;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      currentSweep,
      false,
      bloomPaint,
    );

    final progressPaint = Paint()
      ..shader = progressShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      currentSweep,
      false,
      progressPaint,
    );

    // ── 4. Leading Edge Specular Highlight Bead ──
    final leadAngle = startAngle + currentSweep;
    final beadCenter = Offset(
      center.dx + cos(leadAngle) * radius,
      center.dy + sin(leadAngle) * radius,
    );

    final beadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(beadCenter, strokeWidth * 0.32, beadPaint);
  }

  @override
  bool shouldRepaint(covariant _TelemetryDialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.compact != compact;
  }
}
