import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Ultra-Luxury Biometric Telemetry Chronograph Dial inspired by
/// Apple Watch Ultra, WHOOP 4.0, and high-precision horology instrumentation.
///
/// Features:
/// - Sapphire Aperture Bezel with milled concentric circular lathe (azurage/snailing) texture
/// - Concentric Dual-Arc telemetry:
///   1. Outer Arc: Session Target Volume Load with chromatic sweep & photon bloom
///   2. Inner Arc: Neuromuscular Readiness Index with electric cyan/mint stroke
/// - Laser-etched calibration graduation scale with 24 micro-ticks & 5 major cardinal markers
/// - Dual glowing specular highlight jewels with pure white specular cores
/// - Atmospheric sub-surface caustic backlight bloom & inner vignette
/// - Physical ease-out cubic spring sweep on entry
/// - Tabular numerical readout with micro-typography & biometric status pill
class WorkoutTelemetryDial extends StatefulWidget {
  final double progress; // 0.0 to 1.0 (Outer volume load arc)
  final double readinessProgress; // 0.0 to 1.0 (Inner readiness arc)
  final String valueText;
  final String label;
  final String? subLabel;
  final double size;
  final bool compact;
  final Color? accentColor;
  final bool animate;

  const WorkoutTelemetryDial({
    super.key,
    required this.progress,
    this.readinessProgress = 0.94,
    required this.valueText,
    this.label = 'LOAD',
    this.subLabel,
    this.size = 92.0,
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
    double size = 40.0,
    bool animate = true,
  }) {
    return WorkoutTelemetryDial(
      key: key,
      progress: progress,
      readinessProgress: 0.90,
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
      duration: const Duration(milliseconds: 1100),
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
            final currentProgress = widget.animate
                ? _animation.value
                : widget.progress.clamp(0.05, 1.0);

            final currentReadiness = widget.animate
                ? (_animation.value / (widget.progress == 0 ? 1 : widget.progress) * widget.readinessProgress).clamp(0.05, 1.0)
                : widget.readinessProgress.clamp(0.05, 1.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                // 1. Multi-tier sub-surface ambient caustic backlight aura
                if (!widget.compact)
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: isDark ? 0.30 : 0.18),
                          accent.withValues(alpha: isDark ? 0.10 : 0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                // 2. Dual-Concentric Horology Telemetry Dial Canvas
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _DualRingTelemetryPainter(
                    loadProgress: currentProgress,
                    readinessProgress: currentReadiness,
                    accentColor: accent,
                    isDark: isDark,
                    compact: widget.compact,
                  ),
                ),

                // 3. Central Horology Readout Hub
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCentralValue(context, isDark),
                    if (!widget.compact) ...[
                      const SizedBox(height: 1),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: context.textTertiary,
                        ),
                      ),
                      if (widget.subLabel != null) ...[
                        const SizedBox(height: 2.5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.14 : 0.10),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.30 : 0.22),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            widget.subLabel!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 6.8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildCentralValue(BuildContext context, bool isDark) {
    if (widget.compact) {
      return Text(
        widget.valueText,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: widget.size * 0.29,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: context.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    // Split number and percentage for luxury typographical hierarchy
    final text = widget.valueText;
    final hasPercent = text.endsWith('%');
    final numberPart = hasPercent ? text.substring(0, text.length - 1) : text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          numberPart,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18.0,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: context.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (hasPercent)
          Padding(
            padding: const EdgeInsets.only(left: 1.0),
            child: Text(
              '%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: context.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ),
      ],
    );
  }
}

class _DualRingTelemetryPainter extends CustomPainter {
  final double loadProgress;
  final double readinessProgress;
  final Color accentColor;
  final bool isDark;
  final bool compact;

  _DualRingTelemetryPainter({
    required this.loadProgress,
    required this.readinessProgress,
    required this.accentColor,
    required this.isDark,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerStroke = compact ? 3.6 : 5.8;
    final outerRadius = (size.width - outerStroke) / 2;

    // Start angle at bottom-left (135° = 2.356 rad) sweeping 270° (4.712 rad) to bottom-right
    const startAngle = 135 * pi / 180;
    const totalSweep = 270 * pi / 180;
    final outerSweep = totalSweep * loadProgress;

    // ── 0. Luxury Horological Aperture & Recessed Bezel (Standard Mode Only) ──
    if (!compact) {
      // Recessed circular dial aperture disc
      final apertureRadius = outerRadius + 2.0;
      final apertureColor = isDark ? const Color(0xFF0F1118) : const Color(0xFFF3F5FA);
      canvas.drawCircle(
        center,
        apertureRadius,
        Paint()
          ..color = apertureColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      // Fine perimeter bezel hairline ring
      final bezelRingColor = isDark
          ? const Color(0xFF232735)
          : const Color(0xFFDFE3EC);
      canvas.drawCircle(
        center,
        apertureRadius,
        Paint()
          ..color = bezelRingColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..isAntiAlias = true,
      );

      // Concentric Lathe Azurage Guilloché Rings (3 micro-hairline circular grooves)
      final latheColor = isDark
          ? Colors.white.withValues(alpha: 0.038)
          : Colors.black.withValues(alpha: 0.030);
      final lathePaint = Paint()
        ..color = latheColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..isAntiAlias = true;

      canvas.drawCircle(center, outerRadius - 3.5, lathePaint);
      canvas.drawCircle(center, outerRadius - 7.5, lathePaint);
      canvas.drawCircle(center, outerRadius - 13.5, lathePaint);
    }

    // ── 1. Outer Inactive Track Recessed Groove & Track Arc ──
    final grooveUnderColor = isDark
        ? const Color(0xFF0A0C11)
        : const Color(0xFFD6DBE6);

    // Deep recessed groove shadow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      totalSweep,
      false,
      Paint()
        ..color = grooveUnderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke + 0.8
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    final outerTrackColor = isDark
        ? const Color(0xFF1B1E29)
        : const Color(0xFFE2E6F0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      totalSweep,
      false,
      Paint()
        ..color = outerTrackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    // ── 2. Standard Mode: Precision Calibration Scale & Inner Readiness Arc ──
    if (!compact) {
      final midRadius = outerRadius - 7.5;
      final innerRadius = outerRadius - 13.5;
      const innerStroke = 3.2;

      // ── Micro Laser Calibration Ticks (24 precise divisions) ──
      const totalTicks = 24;
      for (int i = 0; i <= totalTicks; i++) {
        final tickAngle = startAngle + (totalSweep * (i / totalTicks));
        final isMajor = i % 6 == 0; // 0%, 25%, 50%, 75%, 100%
        final isMid = i % 3 == 0 && !isMajor;
        final tickLen = isMajor ? 3.8 : (isMid ? 2.6 : 1.8);

        final tickColor = isMajor
            ? (isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.28))
            : (isMid
                ? (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.14))
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)));

        final p1 = Offset(
          center.dx + cos(tickAngle) * (midRadius - tickLen / 2),
          center.dy + sin(tickAngle) * (midRadius - tickLen / 2),
        );
        final p2 = Offset(
          center.dx + cos(tickAngle) * (midRadius + tickLen / 2),
          center.dy + sin(tickAngle) * (midRadius + tickLen / 2),
        );

        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = tickColor
            ..strokeWidth = isMajor ? 1.1 : 0.7
            ..isAntiAlias = true,
        );
      }

      // ── Inner Readiness Track Arc ──
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        totalSweep,
        false,
        Paint()
          ..color = isDark ? const Color(0xFF141722) : const Color(0xFFE8EBF3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = innerStroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );

      // ── Active Inner Readiness Arc (Electric Cyan / Mint #00E5FF) ──
      const readinessColor = Color(0xFF00E5FF);
      final readinessSweep = totalSweep * readinessProgress;

      // Inner Ambient Bloom
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        readinessSweep,
        false,
        Paint()
          ..color = readinessColor.withValues(alpha: isDark ? 0.38 : 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = innerStroke + 2.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
          ..isAntiAlias = true,
      );

      // Inner Crisp Stroke
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        readinessSweep,
        false,
        Paint()
          ..color = readinessColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = innerStroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );

      // Inner Leading Micro-Jewel
      final innerLeadAngle = startAngle + readinessSweep;
      final innerBeadCenter = Offset(
        center.dx + cos(innerLeadAngle) * innerRadius,
        center.dy + sin(innerLeadAngle) * innerRadius,
      );
      // Cyan micro glow
      canvas.drawCircle(
        innerBeadCenter,
        innerStroke * 0.75,
        Paint()
          ..color = readinessColor.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
          ..isAntiAlias = true,
      );
      // White core
      canvas.drawCircle(
        innerBeadCenter,
        innerStroke * 0.38,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }

    // ── 3. Active Outer Strain Arc with Dynamic Chromatic Sweep & Photon Bloom ──
    final gradientColors = [
      accentColor.withValues(alpha: 0.70),
      accentColor,
    ];

    final progressShader = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + totalSweep,
      colors: gradientColors,
      transform: GradientRotation(startAngle),
    ).createShader(Rect.fromCircle(center: center, radius: outerRadius));

    // Outer photon bloom aura
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      outerSweep,
      false,
      Paint()
        ..color = accentColor.withValues(alpha: isDark ? 0.42 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke + 3.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5)
        ..isAntiAlias = true,
    );

    // Primary precision arc stroke
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      outerSweep,
      false,
      Paint()
        ..shader = progressShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    // ── 4. Leading Edge Specular Highlight Jewel ──
    final leadAngle = startAngle + outerSweep;
    final beadCenter = Offset(
      center.dx + cos(leadAngle) * outerRadius,
      center.dy + sin(leadAngle) * outerRadius,
    );

    // Multi-tier luminous jewel glow
    canvas.drawCircle(
      beadCenter,
      outerStroke * 0.85,
      Paint()
        ..color = accentColor.withValues(alpha: 0.60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..isAntiAlias = true,
    );

    // Colored jewel body
    canvas.drawCircle(
      beadCenter,
      outerStroke * 0.46,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Inner pure white specular diamond glint
    canvas.drawCircle(
      beadCenter,
      outerStroke * 0.25,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _DualRingTelemetryPainter oldDelegate) {
    return oldDelegate.loadProgress != loadProgress ||
        oldDelegate.readinessProgress != readinessProgress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.compact != compact;
  }
}
