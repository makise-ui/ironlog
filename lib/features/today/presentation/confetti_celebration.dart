import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/services/pr_detector.dart';

class SparkParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double alpha;

  SparkParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    this.alpha = 1.0,
  });
}

class ConfettiOverlay extends StatefulWidget {
  final PrResult prResult;
  final VoidCallback onDismiss;

  const ConfettiOverlay({
    super.key,
    required this.prResult,
    required this.onDismiss,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<SparkParticle> _particles = [];
  final Random _rand = Random();

  final List<Color> _colors = [
    const Color(0xFF00FFCC), // Electric Cyan
    const Color(0xFF10B981), // Emerald
    const Color(0xFF38BDF8), // Sky Cyber
    Colors.white,
    const Color(0xFF00E5FF),
  ];

  @override
  void initState() {
    super.initState();
    AppHaptics.save();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    // Generate 45 sleek kinetic athletic sparks radiating from top center
    for (int i = 0; i < 45; i++) {
      final angle = -pi / 2 + (_rand.nextDouble() - 0.5) * 1.8;
      final speed = 0.8 + _rand.nextDouble() * 1.6;
      _particles.add(SparkParticle(
        x: 0.5 + (_rand.nextDouble() - 0.5) * 0.25,
        y: 0.12,
        vx: cos(angle) * speed * 0.8,
        vy: sin(angle) * speed * 0.9,
        size: 2.5 + _rand.nextDouble() * 4.5,
        color: _colors[_rand.nextInt(_colors.length)],
        alpha: 1.0,
      ));
    }

    _controller.addListener(() {
      final progress = _controller.value;
      setState(() {
        for (final p in _particles) {
          p.x += p.vx * 0.012;
          p.y += p.vy * 0.012;
          p.vy += 0.018; // gentle physics
          p.vx *= 0.985;
          p.alpha = (1.0 - (progress * 1.15)).clamp(0.0, 1.0);
        }
      });
    });

    _controller.forward().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: GestureDetector(
          onTap: widget.onDismiss,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -100) {
              widget.onDismiss();
            }
          },
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(_particles),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14, left: 16, right: 16),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _controller,
                        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.3),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _controller,
                            curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xEE121118),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: C.accent.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: C.accent.withValues(alpha: 0.2),
                                    blurRadius: 28,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Sleek gradient icon badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          C.accent,
                                          const Color(0xFF10B981),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: C.accent.withValues(alpha: 0.4),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: widget.prResult.prType != null
                                          ? Icon(
                                              widget.prResult.prType!.iconData,
                                              color: Colors.black,
                                              size: 22,
                                            )
                                          : const Icon(
                                              Icons.emoji_events_rounded,
                                              color: Colors.black,
                                              size: 24,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: C.accent.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                widget.prResult.isPr ? 'NEW RECORD' : 'WORKOUT COMPLETED',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.0,
                                                  color: C.accent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.prResult.title,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: C.text1,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.prResult.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: C.text2,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: widget.onDismiss,
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: C.surfaceHi,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.close_rounded, size: 14, color: C.text3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<SparkParticle> particles;

  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.alpha <= 0.01) continue;
      final px = p.x * size.width;
      final py = p.y * size.height;

      // Outer kinetic glow halo
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: p.alpha * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 1.2);
      canvas.drawCircle(Offset(px, py), p.size * 1.8, glowPaint);

      // Core particle body
      final corePaint = Paint()..color = p.color.withValues(alpha: p.alpha);
      canvas.drawCircle(Offset(px, py), p.size * 0.7, corePaint);

      // Bright white incandescent center
      final centerPaint = Paint()
        ..color = Colors.white.withValues(alpha: p.alpha * 0.95);
      canvas.drawCircle(Offset(px, py), p.size * 0.35, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

class ConfettiCelebration {
  static void show(BuildContext context) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => ConfettiOverlay(
        prResult: const PrResult(
          isPr: false,
          prType: PrType.sessionVolume,
          title: 'Session Completed!',
          description: 'Workout saved to History. Great work!',
        ),
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}

