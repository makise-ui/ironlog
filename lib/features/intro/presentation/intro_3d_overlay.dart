import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/utils/haptics.dart';

/// Dynamic Splash & Intro Animation.
///
/// 1. Settle: The metallic IronLog emblem emerges centered with an ambient aura.
/// 2. Break: With a mechanical haptic impulse, the two dumbbell arms detach,
///    tumbling and falling downward under gravity.
/// 3. Ascend: The center notes/checklist tablet floats gracefully to the top.
/// 4. Plunge: The chrome 'IRONLOG' text falls down off-screen.
/// 5. Reveal: The dark backdrop dissolves, seamlessly revealing the main app.
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
  bool _breakHapticFired = false;
  bool _dockHapticFired = false;

  @override
  void initState() {
    super.initState();
    _isAnimationComplete = hasShownIntro;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1950),
    );

    if (!hasShownIntro) {
      _controller.addListener(() {
        final t = _controller.value;

        // Mechanical break impact haptic when arms snap apart (~0.28)
        if (t >= 0.28 && !_breakHapticFired) {
          _breakHapticFired = true;
          AppHaptics.heavy();
        }

        // Subtle settle haptic when notes reach the top (~0.85)
        if (t >= 0.85 && !_dockHapticFired) {
          _dockHapticFired = true;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!hasShownIntro) {
      precacheImage(const AssetImage('assets/images/app_logo.png'), context);
      precacheImage(const AssetImage('assets/images/logo_left_arm.png'), context);
      precacheImage(const AssetImage('assets/images/logo_right_arm.png'), context);
      precacheImage(const AssetImage('assets/images/logo_center_notes.png'), context);
      precacheImage(const AssetImage('assets/images/logo_text_ironlog.png'), context);
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

  @override
  Widget build(BuildContext context) {
    if (hasShownIntro && _isAnimationComplete) {
      return widget.child;
    }

    final t = _controller.value;
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- TIMING INTERVALS ---
    // Phase 1: Intro Logo fade-in & settle (0.00 -> 0.28)
    final introFade = const Interval(0.00, 0.24, curve: Curves.easeOut).transform(t);
    final introScale = ui.lerpDouble(
      0.90,
      1.0,
      const Interval(0.00, 0.28, curve: Curves.easeOutCubic).transform(t),
    )!;

    // Phase 2: The Break (0.28 -> 0.88)
    final breakProg = const Interval(0.28, 0.88, curve: Curves.linear).transform(t);
    // Gravity acceleration for falling pieces
    final gravityProg = Curves.easeInQuad.transform(breakProg);

    // Ripple / Shockwave pulse on break (0.28 -> 0.48)
    final shockProg = const Interval(0.28, 0.48, curve: Curves.easeOut).transform(t);

    // Phase 3: Notes Ascend smoothly towards top (0.28 -> 0.85)
    final notesAscendProg = const Interval(0.28, 0.85, curve: Curves.easeInOutCubic).transform(t);

    // Phase 4: Screen reveal / Background fade out (0.75 -> 0.98)
    final bgFadeOut = (1.0 - const Interval(0.75, 0.98, curve: Curves.easeInOut).transform(t)).clamp(0.0, 1.0);

    // Logo display size (proportional to screen width)
    final logoSize = math.min(size.width * 0.72, 310.0);
    final centerOffset = Offset(size.width / 2, size.height * 0.45);

    // Physics parameters for the pieces:
    // 1. Left Arm (Dumbbell):
    // Moves left: -140px, falls down: +460px with gravity, rotates CCW: -30 degrees
    final leftDx = -140.0 * breakProg;
    final leftDy = 480.0 * gravityProg;
    final leftRot = -0.52 * breakProg; // ~ -30 deg
    final leftOpacity = (1.0 - breakProg * 1.35).clamp(0.0, 1.0);

    // 2. Right Arm (Dumbbell):
    // Moves right: +140px, falls down: +460px with gravity, rotates CW: +30 degrees
    final rightDx = 140.0 * breakProg;
    final rightDy = 480.0 * gravityProg;
    final rightRot = 0.52 * breakProg; // ~ +30 deg
    final rightOpacity = (1.0 - breakProg * 1.35).clamp(0.0, 1.0);

    // 3. Notes Tablet:
    // Moves UPWARD towards the top of the screen (-320px)
    final notesDy = -size.height * 0.44 * notesAscendProg;
    final notesScale = ui.lerpDouble(1.0, 0.88, notesAscendProg)!;
    final notesOpacity = (1.0 - const Interval(0.70, 0.95, curve: Curves.easeIn).transform(t)).clamp(0.0, 1.0);

    // 4. IRONLOG Text:
    // Drops down rapidly (+360px) and fades out
    final textDy = 360.0 * gravityProg;
    final textOpacity = (1.0 - breakProg * 1.5).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // 1. Underlying Main App Screen
        widget.child,

        // 2. Backdrop Overlay with tap-to-skip
        if (!_isAnimationComplete && t < 0.99)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _skipIntro,
              child: Container(
                color: (isDark
                        ? const Color(0xFF0C0D10)
                        : const Color(0xFFF4F4F6))
                    .withValues(alpha: bgFadeOut),
              ),
            ),
          ),

        // 3. Shockwave Flash Ripple when breaking apart
        if (!_isAnimationComplete && shockProg > 0.01 && shockProg < 0.99)
          Positioned(
            left: centerOffset.dx - (logoSize * (0.8 + shockProg * 1.2)) / 2,
            top: centerOffset.dy - (logoSize * (0.8 + shockProg * 1.2)) / 2,
            child: IgnorePointer(
              child: Container(
                width: logoSize * (0.8 + shockProg * 1.2),
                height: logoSize * (0.8 + shockProg * 1.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: (1.0 - shockProg) * 0.35,
                    ),
                    width: 2.5 * (1.0 - shockProg),
                  ),
                ),
              ),
            ),
          ),

        // 4. Logo Stage (Centered)
        if (!_isAnimationComplete && introFade > 0.01)
          Positioned(
            left: centerOffset.dx - (logoSize / 2),
            top: centerOffset.dy - (logoSize / 2),
            child: IgnorePointer(
              child: SizedBox(
                width: logoSize,
                height: logoSize,
                child: Transform.scale(
                  scale: introScale,
                  child: Opacity(
                    opacity: introFade,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // --- A. BEFORE BREAK: Full Logo with intact ambient glow ---
                        if (breakProg <= 0.01)
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),

                        // --- B. AFTER BREAK: Dynamic Separated Physics Components ---
                        if (breakProg > 0.0) ...[
                          // 1. LEFT DUMBBELL ARM (Falls down to the left)
                          Positioned.fill(
                            child: Transform.translate(
                              offset: Offset(leftDx, leftDy),
                              child: Transform.rotate(
                                angle: leftRot,
                                alignment: const Alignment(-0.35, 0.0),
                                child: Opacity(
                                  opacity: leftOpacity,
                                  child: Image.asset(
                                    'assets/images/logo_left_arm.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 2. RIGHT DUMBBELL ARM (Falls down to the right)
                          Positioned.fill(
                            child: Transform.translate(
                              offset: Offset(rightDx, rightDy),
                              child: Transform.rotate(
                                angle: rightRot,
                                alignment: const Alignment(0.35, 0.0),
                                child: Opacity(
                                  opacity: rightOpacity,
                                  child: Image.asset(
                                    'assets/images/logo_right_arm.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 3. IRONLOG CHROME TEXT (Falls straight down)
                          Positioned.fill(
                            child: Transform.translate(
                              offset: Offset(0.0, textDy),
                              child: Opacity(
                                opacity: textOpacity,
                                child: Image.asset(
                                  'assets/images/logo_text_ironlog.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                          // 4. CENTER NOTES TABLET (Floats upward to the top)
                          Positioned.fill(
                            child: Transform.translate(
                              offset: Offset(0.0, notesDy),
                              child: Transform.scale(
                                scale: notesScale,
                                child: Opacity(
                                  opacity: notesOpacity,
                                  child: Image.asset(
                                    'assets/images/logo_center_notes.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
