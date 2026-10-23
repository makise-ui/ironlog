import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Ultra-Luxury Biometric Kinetic Strain Waveform (Oura / Bevel Standard).
///
/// Features:
/// - Smooth multi-frequency cubic Bezier harmonic waves
/// - Sub-surface caustic gradient fill fading to transparent
/// - Dual-layer harmonic resonance (primary stroke + secondary phase-shifted echo)
/// - Glowing peak specular glint bead at the highest energy crest
/// - Elegant ease-out cubic entrance sweep that settles into steady-state
/// - Compact micro-mode for RoutineCards
class WorkoutStrainWaveform extends StatefulWidget {
  final double loadScore; // 0.0 to 1.0 (session volume / strain demand)
  final double width;
  final double height;
  final Color? accentColor;
  final bool animate;
  final bool compact;

  const WorkoutStrainWaveform({
    super.key,
    required this.loadScore,
    this.width = 130.0,
    this.height = 48.0,
    this.accentColor,
    this.animate = true,
    this.compact = false,
  });

  /// Factory for micro-waveform on RoutineCards
  factory WorkoutStrainWaveform.compact({
    Key? key,
    required double loadScore,
    double width = 52.0,
    double height = 24.0,
    Color? accentColor,
    bool animate = true,
  }) {
    return WorkoutStrainWaveform(
      key: key,
      loadScore: loadScore,
      width: width,
      height: height,
      accentColor: accentColor,
      compact: true,
      animate: animate,
    );
  }

  @override
  State<WorkoutStrainWaveform> createState() => _WorkoutStrainWaveformState();
}

class _WorkoutStrainWaveformState extends State<WorkoutStrainWaveform>
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

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutStrainWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadScore != widget.loadScore) {
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
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final animValue = widget.animate ? _animation.value : 1.0;
            return CustomPaint(
              size: Size(widget.width, widget.height),
              painter: _WaveformPainter(
                loadScore: widget.loadScore.clamp(0.20, 1.0),
                progress: animValue,
                accentColor: accent,
                isDark: isDark,
                compact: widget.compact,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double loadScore;
  final double progress; // 0.0 to 1.0
  final Color accentColor;
  final bool isDark;
  final bool compact;

  _WaveformPainter({
    required this.loadScore,
    required this.progress,
    required this.accentColor,
    required this.isDark,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h * 0.52;
    final amplitude = (h * 0.36) * loadScore * progress;
    final phase = progress * 1.5 * pi;

    // ── 1. Secondary Harmonic Echo Wave (Subtle resonance behind) ──
    if (!compact && progress > 0.1) {
      final echoPath = Path();
      const echoStep = 4.0;
      for (double x = 0; x <= w; x += echoStep) {
        final normX = x / w;
        final envelope = sin(normX * pi);
        final y = midY +
            sin(normX * 3.5 * pi - phase * 0.8) *
                (amplitude * 0.55) *
                envelope;
        if (x == 0) {
          echoPath.moveTo(x, y);
        } else {
          echoPath.lineTo(x, y);
        }
      }

      final echoPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      canvas.drawPath(echoPath, echoPaint);
    }

    // ── 2. Primary Kinetic Biometric Wave Path ──
    final primaryPath = Path();
    final fillPath = Path();
    fillPath.moveTo(0, h);

    const step = 2.5;
    double peakX = 0.0;
    double peakY = h;

    for (double x = 0; x <= w; x += step) {
      final normX = x / w;
      // Window envelope to smoothly anchor endpoints
      final envelope = pow(sin(normX * pi), 1.2).toDouble();

      // Dual-frequency harmonic synthesis
      final wave1 = sin(normX * 2.8 * pi - phase);
      final wave2 = sin(normX * 5.6 * pi + phase * 0.5) * 0.35;
      final y = midY - (wave1 + wave2) * amplitude * envelope;

      if (x == 0) {
        primaryPath.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        primaryPath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Track highest energy crest for specular glint
      if (y < peakY) {
        peakY = y;
        peakX = x;
      }
    }

    fillPath.lineTo(w, h);
    fillPath.close();

    // ── 3. Gradient Fill (Sub-surface photon luminescence) ──
    final fillShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF00E5FF).withValues(alpha: (isDark ? 0.22 : 0.14) * progress),
        accentColor.withValues(alpha: (isDark ? 0.08 : 0.04) * progress),
        Colors.transparent,
      ],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = fillShader
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // ── 4. Primary Waveform Glowing Stroke ──
    const cyan = Color(0xFF00E5FF);
    final strokeShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        accentColor,
        cyan,
        accentColor,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final strokeWidth = compact ? 1.8 : 2.4;

    // Outer bloom glow
    canvas.drawPath(
      primaryPath,
      Paint()
        ..color = cyan.withValues(alpha: (isDark ? 0.38 : 0.20) * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..isAntiAlias = true,
    );

    // Sharp precision stroke
    canvas.drawPath(
      primaryPath,
      Paint()
        ..shader = strokeShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    // ── 5. Specular Crest Glint Jewel (Peak of the waveform) ──
    if (peakX > 0 && peakX < w && progress > 0.3) {
      final crestCenter = Offset(peakX, peakY);

      // Ambient crest aura
      canvas.drawCircle(
        crestCenter,
        (compact ? 3.0 : 4.5) * progress,
        Paint()
          ..color = cyan.withValues(alpha: 0.55 * progress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
          ..isAntiAlias = true,
      );

      // Cyan core
      canvas.drawCircle(
        crestCenter,
        (compact ? 1.8 : 2.4) * progress,
        Paint()
          ..color = cyan
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      // White diamond glint
      canvas.drawCircle(
        crestCenter,
        (compact ? 0.9 : 1.2) * progress,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.loadScore != loadScore ||
        oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.compact != compact;
  }
}
