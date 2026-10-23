import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Ultra-Premium Biometric Telemetry Dial inspired by WHOOP 4.0, Bevel Health,
/// and Apple Watch Activity instrumentation.
///
/// Features:
/// - Smooth animated progress sweep with physical ease-out curves
/// - Dual-concentric calibrated gauge with laser-etched graduation ticks
/// - Luminous multi-tone chromatic gradient arc
/// - Leading-edge glowing specular bead with emissive bloom
/// - Sub-surface ambient caustic backlight aura
/// - Tabular numerical readout with micro-tracking instrumentation labels
class WorkoutTelemetryDial extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final String valueText;
  final String label;
  final double size;
  final bool compact;
  final Color? accentColor;
  final bool animate;

  const WorkoutTelemetryDial({
    super.key,
    required this.progress,
    required this.valueText,
    this.label = 'LOAD',
    this.size = 88.0,
    this.compact = false,
    this.accentColor,
    this.animate = true,
  });

  /// Factory for compact micro-gauge on RoutineCards
  factory WorkoutTelemetryDial.compact({
    Key? key,
    required double progress,
    required String valueText,
    Color? accentColor,
    double size = 42.0,
    bool animate = true,
  }) {
    return WorkoutTelemetryDial(
      key: key,
      progress: progress,
      valueText: valueText,
      size: size,
      compact: true,
      accentColor: accentColor,
      animate: animate,
    );
  }

  @override
  State<WorkoutTelemetryDial> createState() => _WorkoutTelemetryDialState();
}

class _WorkoutTelemetryDialState extends State<WorkoutTelemetryDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    final target = widget.progress.clamp(0.05, 1.0);
    _animation = Tween<double>(
      begin: widget.animate ? 0.0 : target,
      end: target,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutTelemetryDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      final target = widget.progress.clamp(0.05, 1.0);
      _animation = Tween<double>(
        begin: _animation.value,
        end: target,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? context.accent;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final currentProgress = widget.animate ? _animation.value : widget.progress.clamp(0.05, 1.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                // 1. Sub-surface ambient caustic backlight aura
                if (!widget.compact)
                  Container(
                    width: widget.size * 0.96,
                    height: widget.size * 0.96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: isDark ? 0.25 : 0.16),
                          accent.withValues(alpha: isDark ? 0.08 : 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.52, 1.0],
                      ),
                    ),
                  ),

                // 2. Dual-Concentric Telemetry Dial Canvas
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _TelemetryDialPainter(
                    progress: currentProgress,
                    accentColor: accent,
                    isDark: isDark,
                    compact: widget.compact,
                  ),
                ),

                // 3. Central Instrumentation Readout Hub
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.valueText,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: widget.compact ? (widget.size * 0.28) : 17.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: widget.compact ? -0.5 : -0.3,
                        color: context.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (!widget.compact) ...[
                      const SizedBox(height: 1.5),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
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
    final strokeWidth = compact ? 3.6 : 6.2;
    final radius = (size.width - strokeWidth) / 2;

    // Start angle at bottom-left (135° = 2.356 rad) sweeping 270° (4.712 rad) to bottom-right
    const startAngle = 135 * pi / 180;
    const totalSweep = 270 * pi / 180;
    final currentSweep = totalSweep * progress;

    // ── 1. Inactive Track Arc ──
    final trackColor = isDark
        ? const Color(0xFF1C1F27)
        : const Color(0xFFE2E5ED);

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

    // ── 2. Laser-Etched Concentric Calibration Scale (Standard size only) ──
    if (!compact) {
      final innerRadius = radius - 8.0;

      // Fine concentric hairline
      final innerHairlinePaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..isAntiAlias = true;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        totalSweep,
        false,
        innerHairlinePaint,
      );

      // Micro graduation ticks at 10 intervals
      const totalTicks = 12;
      for (int i = 0; i <= totalTicks; i++) {
        final tickAngle = startAngle + (totalSweep * (i / totalTicks));
        final isMajor = i == 0 || i == 3 || i == 6 || i == 9 || i == 12;
        final tickLen = isMajor ? 3.5 : 2.0;

        final tickColor = isMajor
            ? (isDark ? Colors.white.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.18))
            : (isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.08));

        final p1 = Offset(
          center.dx + cos(tickAngle) * (innerRadius - tickLen / 2),
          center.dy + sin(tickAngle) * (innerRadius - tickLen / 2),
        );
        final p2 = Offset(
          center.dx + cos(tickAngle) * (innerRadius + tickLen / 2),
          center.dy + sin(tickAngle) * (innerRadius + tickLen / 2),
        );

        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = tickColor
            ..strokeWidth = isMajor ? 1.0 : 0.75
            ..isAntiAlias = true,
        );
      }
    }

    // ── 3. Active Progress Arc with Dynamic Chromatic Gradient ──
    final gradientColors = [
      accentColor.withValues(alpha: 0.70),
      accentColor,
    ];

    final progressShader = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + totalSweep,
      colors: gradientColors,
      transform: GradientRotation(startAngle),
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Outer bloom aura shadow
    final bloomPaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.40 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..isAntiAlias = true;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      currentSweep,
      false,
      bloomPaint,
    );

    // Primary crisp gradient stroke
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

    // Outer luminous glow around bead
    canvas.drawCircle(
      beadCenter,
      strokeWidth * 0.75,
      Paint()
        ..color = accentColor.withValues(alpha: 0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
        ..isAntiAlias = true,
    );

    // Inner pure white specular core
    canvas.drawCircle(
      beadCenter,
      strokeWidth * 0.35,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _TelemetryDialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.compact != compact;
  }
}
