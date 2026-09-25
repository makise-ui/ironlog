import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/utils/haptics.dart';

/// Professional Studio Splash & Brand Reveal Overlay.
///
/// Features:
/// 1. Emergence: High-precision 3D metallic emblem glides into center with
///    an ambient electric cyan backlight bloom.
/// 2. Chrome Shimmer: A sweeping specular light gleam moves across the brushed
///    steel dumbbell plates, checkmark tablet, and chrome typography.
/// 3. Haptic Sync: Tactile micro-haptic impulse fires at the apex of the metallic shimmer.
/// 4. Tagline Reveal: Refined high-kerning "STRENGTH ARCHITECTURE" subtitle fades in.
/// 5. Horizon Dissolve: Elegant scale & fade transition seamlessly unveils the app.
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
  bool _shimmerHapticFired = false;

  @override
  void initState() {
    super.initState();
    _isAnimationComplete = hasShownIntro;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );

    if (!hasShownIntro) {
      _controller.addListener(() {
        final t = _controller.value;

        // Subtle tactile haptic at apex of chrome light shimmer (~0.48)
        if (t >= 0.48 && !_shimmerHapticFired) {
          _shimmerHapticFired = true;
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
    // Phase 1: Intro Logo fade-in & smooth scale settle (0.00 -> 0.32)
    final introFade = const Interval(0.00, 0.28, curve: Curves.easeOutCubic).transform(t);
    final introScale = ui.lerpDouble(
      0.92,
      1.00,
      const Interval(0.00, 0.35, curve: Curves.easeOutCubic).transform(t),
    )!;

    // Ambient backlight bloom (0.10 -> 0.70)
    final glowPulse = math.sin(const Interval(0.10, 0.75, curve: Curves.easeInOut).transform(t) * math.pi);

    // Phase 2: Specular Chrome Shimmer Sweep (0.30 -> 0.72)
    final shimmerProgress = const Interval(0.30, 0.72, curve: Curves.easeInOutSine).transform(t);
    final shimmerPos = ui.lerpDouble(-1.4, 2.4, shimmerProgress)!;

    // Phase 3: Subtitle Tagline Reveal (0.38 -> 0.68)
    final taglineOpacity = const Interval(0.38, 0.65, curve: Curves.easeOut).transform(t);
    final taglineY = ui.lerpDouble(12.0, 0.0, const Interval(0.38, 0.65, curve: Curves.easeOutCubic).transform(t))!;

    // Phase 4: Dissolve & Outro (0.75 -> 0.98)
    final outroProg = const Interval(0.75, 0.98, curve: Curves.easeInOut).transform(t);
    final bgFadeOut = (1.0 - outroProg).clamp(0.0, 1.0);
    final outroScale = ui.lerpDouble(1.00, 1.05, outroProg)!;
    final logoDissolve = (1.0 - const Interval(0.80, 0.98, curve: Curves.easeIn).transform(t)).clamp(0.0, 1.0);

    final logoSize = math.min(size.width * 0.68, 290.0);
    final centerOffset = Offset(size.width / 2, size.height * 0.44);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // 1. Underlying Main App Screen
        widget.child,

        // 2. Cinematic Backdrop with tap-to-skip
        if (!_isAnimationComplete && t < 0.99)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _skipIntro,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.15),
                    radius: 1.1,
                    colors: isDark
                        ? [
                            const Color(0xFF141724).withValues(alpha: bgFadeOut),
                            const Color(0xFF090A0D).withValues(alpha: bgFadeOut),
                          ]
                        : [
                            const Color(0xFFFFFFFF).withValues(alpha: bgFadeOut),
                            const Color(0xFFF1F3F7).withValues(alpha: bgFadeOut),
                          ],
                  ),
                ),
              ),
            ),
          ),

        // 3. Ambient Backlight Bloom behind the 3D steel emblem
        if (!_isAnimationComplete && glowPulse > 0.01 && bgFadeOut > 0.05)
          Positioned(
            left: centerOffset.dx - (logoSize * 1.1) / 2,
            top: centerOffset.dy - (logoSize * 1.1) / 2,
            child: IgnorePointer(
              child: Container(
                width: logoSize * 1.1,
                height: logoSize * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00E5A3).withValues(alpha: 0.18 * glowPulse * bgFadeOut),
                      const Color(0xFF38BDF8).withValues(alpha: 0.08 * glowPulse * bgFadeOut),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // 4. Centered 3D Metallic Emblem Stage
        if (!_isAnimationComplete && introFade > 0.01 && logoDissolve > 0.01)
          Positioned(
            left: centerOffset.dx - (logoSize / 2),
            top: centerOffset.dy - (logoSize / 2),
            child: IgnorePointer(
              child: Transform.scale(
                scale: introScale * outroScale,
                child: Opacity(
                  opacity: introFade * logoDissolve,
                  child: SizedBox(
                    width: logoSize,
                    height: logoSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // A. Base pristine transparent 3D logo
                        Image.asset(
                          'assets/images/app_logo.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),

                        // B. Dynamic Specular Chrome Light Sweep
                        if (shimmerProgress > 0.01 && shimmerProgress < 0.99)
                          ShaderMask(
                            blendMode: BlendMode.srcATop,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment(shimmerPos - 0.4, -0.6),
                                end: Alignment(shimmerPos + 0.4, 0.6),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.white.withValues(alpha: 0.65),
                                  const Color(0xFFE2E8F0).withValues(alpha: 0.85),
                                  const Color(0xFF38BDF8).withValues(alpha: 0.40),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.35, 0.50, 0.62, 0.75, 1.0],
                              ).createShader(bounds);
                            },
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 5. Luxury Typography Tagline below logo
        if (!_isAnimationComplete && taglineOpacity > 0.01 && logoDissolve > 0.01)
          Positioned(
            left: 0,
            right: 0,
            top: centerOffset.dy + (logoSize * 0.48) + taglineY,
            child: IgnorePointer(
              child: Opacity(
                opacity: taglineOpacity * logoDissolve,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 1,
                        color: (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)).withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'STRENGTH ARCHITECTURE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4.0,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 18,
                        height: 1,
                        color: (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)).withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
