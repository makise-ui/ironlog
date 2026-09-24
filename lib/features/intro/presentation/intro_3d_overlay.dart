import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/utils/haptics.dart';

/// Clean opening splash transition.
/// Shows only the app logo in the center on launch, then smoothly animates
/// and glides straight up to sit permanently in the top app bar.
class Intro3DOverlay extends StatefulWidget {
  final Widget child;

  const Intro3DOverlay({
    super.key,
    required this.child,
  });

  @override
  State<Intro3DOverlay> createState() => _Intro3DOverlayState();
}

class _Intro3DOverlayState extends State<Intro3DOverlay>
    with SingleTickerProviderStateMixin {
  static bool hasShownIntro = false;
  late final AnimationController _controller;
  late bool _isAnimationComplete;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    _isAnimationComplete = hasShownIntro;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (!hasShownIntro) {
      _controller.addListener(() {
        final t = _controller.value;

        // Subtle haptic touch when docking at the top
        if (t >= 0.95 && !_hapticFired) {
          _hapticFired = true;
          AppHaptics.tap();
        }

        if (_controller.isCompleted) {
          hasShownIntro = true;
          setState(() {
            _isAnimationComplete = true;
          });
        } else {
          setState(() {});
        }
      });

      _controller.forward();
    }
  }

  void _skipIntro() {
    hasShownIntro = true;
    if (!_isAnimationComplete) {
      _controller.stop();
      setState(() {
        _isAnimationComplete = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _getTargetLogoCenter(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Offset(16.0 + 15.0, topPadding + 10.0 + 15.0);
  }

  @override
  Widget build(BuildContext context) {
    if (hasShownIntro && _isAnimationComplete) {
      return widget.child;
    }

    final t = _controller.value;
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Timing intervals
    // Phase 1: Logo fades in and gently settles in the center (0.00 -> 0.28)
    final scaleInProg = const Interval(
      0.00,
      0.28,
      curve: Curves.easeOutCubic,
    ).transform(t);
    final fadeInProg = const Interval(
      0.00,
      0.22,
      curve: Curves.easeOut,
    ).transform(t);

    // Phase 2: Smooth glide from center to top app bar (0.35 -> 1.00)
    final glideProg = const Interval(
      0.35,
      1.00,
      curve: Curves.easeInOutCubic,
    ).transform(t);

    final bgFadeOut = (1.0 -
            const Interval(0.45, 0.95, curve: Curves.easeInOut).transform(t))
        .clamp(0.0, 1.0);

    // Coordinates: from center to top header logo
    final centerPos = Offset(size.width / 2, size.height * 0.44);
    final targetPos = _getTargetLogoCenter(context);

    final currentPos = Offset.lerp(centerPos, targetPos, glideProg)!;
    final currentScale = ui.lerpDouble(0.85, 1.0, scaleInProg)!;
    final currentSize =
        ui.lerpDouble(110.0 * currentScale, 30.0, glideProg)!;
    final currentRadius = ui.lerpDouble(24.0, 8.0, glideProg)!;
    final currentBorderWidth = ui.lerpDouble(1.2, 0.8, glideProg)!;

    final targetBorderColor =
        isDark ? const Color(0xFF424242) : const Color(0xFFD4D4D8);
    final currentBorderColor = Color.lerp(
      Colors.white.withValues(alpha: 0.18),
      targetBorderColor,
      glideProg,
    )!;

    final shadowAlpha = (1.0 - glideProg) * 0.45;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // 1. Underlying App Screen (stable element position)
        widget.child,

        // 2. Backdrop Overlay (tap anywhere to skip)
        if (!_isAnimationComplete && t < 0.999)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _skipIntro,
              child: Container(
                color: (isDark
                        ? const Color(0xFF141414)
                        : const Color(0xFFF6F6F8))
                    .withValues(alpha: bgFadeOut),
              ),
            ),
          ),

        // 3. Gliding App Icon (moves from center straight up to sit in top app bar)
        if (!_isAnimationComplete && fadeInProg > 0.01)
          Positioned(
            left: currentPos.dx - (currentSize / 2),
            top: currentPos.dy - (currentSize / 2),
            child: Opacity(
              opacity: fadeInProg.clamp(0.0, 1.0),
              child: Container(
                width: currentSize,
                height: currentSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(currentRadius),
                  border: Border.all(
                    color: currentBorderColor,
                    width: currentBorderWidth,
                  ),
                  boxShadow: shadowAlpha > 0.01
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: shadowAlpha),
                            blurRadius: 28 * (1.0 - glideProg),
                            offset: Offset(0, 8 * (1.0 - glideProg)),
                          ),
                        ]
                      : null,
                  image: const DecorationImage(
                    image: AssetImage('assets/images/app_logo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
