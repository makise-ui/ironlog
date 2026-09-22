import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AuroraBackground extends StatefulWidget {
  final Widget child;

  const AuroraBackground({
    super.key,
    required this.child,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: AppColors.background,
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AuroraPainter(progress: _controller.value),
                );
              },
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double progress;

  _AuroraPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    // Blob 1: Violet glow drifting top-left
    final cx1 = size.width * (0.28 + 0.12 * math.sin(t));
    final cy1 = size.height * (0.20 + 0.08 * math.cos(t));
    final r1 = size.width * 0.75;
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accentViolet.withValues(alpha: 0.18),
          AppColors.accentViolet.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx1, cy1), radius: r1));
    canvas.drawCircle(Offset(cx1, cy1), r1, paint1);

    // Blob 2: Cyan glow drifting around mid/bottom-right
    final cx2 = size.width * (0.75 + 0.10 * math.cos(t * 0.8));
    final cy2 = size.height * (0.65 + 0.12 * math.sin(t * 0.8));
    final r2 = size.width * 0.80;
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accentCyan.withValues(alpha: 0.14),
          AppColors.accentCyan.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: r2));
    canvas.drawCircle(Offset(cx2, cy2), r2, paint2);

    // Blob 3: Deep blue / subtle magenta drifting around mid-right
    final cx3 = size.width * (0.50 + 0.14 * math.sin(t * 1.2));
    final cy3 = size.height * (0.42 + 0.10 * math.cos(t * 1.2));
    final r3 = size.width * 0.65;
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6366F1).withValues(alpha: 0.12),
          const Color(0xFF6366F1).withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx3, cy3), radius: r3));
    canvas.drawCircle(Offset(cx3, cy3), r3, paint3);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
