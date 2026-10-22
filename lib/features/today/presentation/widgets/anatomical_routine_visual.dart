import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum RoutineTargetCategory {
  push,
  pull,
  legs,
  upper,
  arms,
  core,
  fullBody,
  recovery,
}

/// Renders a sleek, telemetry-styled anatomical muscle heatmap silhouette.
///
/// Designed as a luxury replacement for raster stock photography on the right
/// side of workout cards (TodayHeroSessionCard, RoutineCard, RoutinesSheet).
/// Automatically highlights relevant muscle groups in the user's active theme accent color.
class AnatomicalRoutineVisual extends StatelessWidget {
  final String routineName;
  final RoutineTargetCategory? targetOverride;
  final double? width;
  final double? height;
  final bool compact;
  final Color? accentColor;

  const AnatomicalRoutineVisual({
    super.key,
    required this.routineName,
    this.targetOverride,
    this.width,
    this.height,
    this.compact = false,
    this.accentColor,
  });

  static RoutineTargetCategory resolveCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('push') || lower.contains('chest') || lower.contains('bench')) {
      return RoutineTargetCategory.push;
    } else if (lower.contains('pull') || lower.contains('back') || lower.contains('deadlift') || lower.contains('row')) {
      return RoutineTargetCategory.pull;
    } else if (lower.contains('leg') || lower.contains('squat') || lower.contains('lower') || lower.contains('quad')) {
      return RoutineTargetCategory.legs;
    } else if (lower.contains('upper')) {
      return RoutineTargetCategory.upper;
    } else if (lower.contains('arm') || lower.contains('bicep') || lower.contains('tricep')) {
      return RoutineTargetCategory.arms;
    } else if (lower.contains('core') || lower.contains('ab')) {
      return RoutineTargetCategory.core;
    } else if (lower.contains('rest') || lower.contains('recovery')) {
      return RoutineTargetCategory.recovery;
    }
    return RoutineTargetCategory.fullBody;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? context.accent;
    final category = targetOverride ?? resolveCategory(routineName);

    return RepaintBoundary(
      child: IgnorePointer(
        child: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.95 : 0.90),
                Colors.white.withValues(alpha: isDark ? 0.70 : 0.60),
                Colors.white.withValues(alpha: isDark ? 0.20 : 0.15),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 0.78, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: SizedBox(
            width: width ?? (compact ? 100 : 150),
            height: height ?? (compact ? 130 : 170),
            child: CustomPaint(
              painter: _AnatomicalSilhouettePainter(
                category: category,
                accentColor: accent,
                isDark: isDark,
                compact: compact,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnatomicalSilhouettePainter extends CustomPainter {
  final RoutineTargetCategory category;
  final Color accentColor;
  final bool isDark;
  final bool compact;

  _AnatomicalSilhouettePainter({
    required this.category,
    required this.accentColor,
    required this.isDark,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base color tones
    final baseSilhouette = isDark
        ? const Color(0xFF24262E)
        : const Color(0xFFDFE2E8);

    final contourLineColor = isDark
        ? const Color(0xFF353944)
        : const Color(0xFFCBD0DB);

    final telemetryLineColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    final glowAlpha = isDark ? 0.42 : 0.32;
    final coreAlpha = isDark ? 0.95 : 0.88;

    final basePaint = Paint()
      ..color = baseSilhouette
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final contourPaint = Paint()
      ..color = contourLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..isAntiAlias = true;

    final activeGlowPaint = Paint()
      ..color = accentColor.withValues(alpha: glowAlpha)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0)
      ..isAntiAlias = true;

    final activeCorePaint = Paint()
      ..color = accentColor.withValues(alpha: coreAlpha)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Draw subtle sports telemetry grid & reticle background
    _paintTelemetryBackground(canvas, size, telemetryLineColor);

    // 2. Ambient radial backlight aura behind the figure
    if (category != RoutineTargetCategory.recovery) {
      final auraCenter = Offset(w * 0.58, h * 0.45);
      final auraRadius = min(w, h) * 0.50;
      final auraPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            accentColor.withValues(alpha: isDark ? 0.22 : 0.16),
            accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: auraCenter, radius: auraRadius));

      canvas.drawCircle(auraCenter, auraRadius, auraPaint);
    }

    // 3. Normalized Athletic Silhouette (coordinate space: 120 x 170)
    // Scale and center figure nicely on the right half
    final double targetHeight = h * 0.90;
    final double scale = targetHeight / 170.0;
    final double offsetX = (w - (120.0 * scale)) * 0.72; // position slightly biased to right edge
    final double offsetY = (h - targetHeight) * 0.50;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    // Body parts drawing
    _paintHeadAndNeck(canvas, basePaint, contourPaint);
    _paintTorsoBase(canvas, basePaint, contourPaint);
    _paintArmsBase(canvas, basePaint, contourPaint);
    _paintLegsBase(canvas, basePaint, contourPaint);

    // 4. Highlight targeted muscles based on routine category
    _paintMuscleHeatmap(
      canvas,
      activeGlowPaint,
      activeCorePaint,
    );

    canvas.restore();
  }

  void _paintTelemetryBackground(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final cx = size.width * 0.60;
    final cy = size.height * 0.45;

    // Target reticle rings
    canvas.drawCircle(Offset(cx, cy), size.height * 0.32, p);
    canvas.drawCircle(Offset(cx, cy), size.height * 0.48, p);

    // Crosshair ticks
    canvas.drawLine(Offset(cx - 10, cy), Offset(cx + 10, cy), p);
    canvas.drawLine(Offset(cx, cy - 10), Offset(cx, cy + 10), p);

    // Fine vertical cadence line
    canvas.drawLine(Offset(cx, 8), Offset(cx, size.height - 8), p);
  }

  void _paintHeadAndNeck(Canvas canvas, Paint basePaint, Paint contourPaint) {
    const cx = 60.0;
    // Head oval
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 7.5, 8, 15, 18),
      const Radius.circular(8),
    );
    canvas.drawRRect(headRect, basePaint);

    // Neck
    final neckPath = Path()
      ..moveTo(cx - 5, 24)
      ..lineTo(cx + 5, 24)
      ..lineTo(cx + 6, 32)
      ..lineTo(cx - 6, 32)
      ..close();
    canvas.drawPath(neckPath, basePaint);
  }

  void _paintTorsoBase(Canvas canvas, Paint basePaint, Paint contourPaint) {
    const cx = 60.0;

    // Traps and Upper Torso Path
    final torsoPath = Path()
      ..moveTo(cx - 6, 29)
      ..lineTo(cx - 24, 38) // Left shoulder point
      ..lineTo(cx - 21, 56) // Left lat sweep
      ..lineTo(cx - 13, 86) // Left waist
      ..lineTo(cx + 13, 86) // Right waist
      ..lineTo(cx + 21, 56) // Right lat sweep
      ..lineTo(cx + 24, 38) // Right shoulder point
      ..lineTo(cx + 6, 29)
      ..close();

    canvas.drawPath(torsoPath, basePaint);

    // Anatomical contour division: Sternum / Linea alba
    canvas.drawLine(const Offset(cx, 38), const Offset(cx, 82), contourPaint);

    // Pelvis / Hips
    final hipsPath = Path()
      ..moveTo(cx - 14, 86)
      ..lineTo(cx + 14, 86)
      ..lineTo(cx + 11, 102)
      ..lineTo(cx, 106)
      ..lineTo(cx - 11, 102)
      ..close();

    canvas.drawPath(hipsPath, basePaint);
  }

  void _paintArmsBase(Canvas canvas, Paint basePaint, Paint contourPaint) {
    const cx = 60.0;

    // Left Arm (bicep + forearm)
    final leftArm = Path()
      ..moveTo(cx - 24, 38)
      ..lineTo(cx - 30, 56)
      ..lineTo(cx - 26, 76)
      ..lineTo(cx - 21, 76)
      ..lineTo(cx - 24, 56)
      ..close();
    canvas.drawPath(leftArm, basePaint);

    final leftForearm = Path()
      ..moveTo(cx - 26, 78)
      ..lineTo(cx - 24, 100)
      ..lineTo(cx - 20, 100)
      ..lineTo(cx - 21, 78)
      ..close();
    canvas.drawPath(leftForearm, basePaint);

    // Right Arm (bicep + forearm)
    final rightArm = Path()
      ..moveTo(cx + 24, 38)
      ..lineTo(cx + 30, 56)
      ..lineTo(cx + 26, 76)
      ..lineTo(cx + 21, 76)
      ..lineTo(cx + 24, 56)
      ..close();
    canvas.drawPath(rightArm, basePaint);

    final rightForearm = Path()
      ..moveTo(cx + 26, 78)
      ..lineTo(cx + 24, 100)
      ..lineTo(cx + 20, 100)
      ..lineTo(cx + 21, 78)
      ..close();
    canvas.drawPath(rightForearm, basePaint);
  }

  void _paintLegsBase(Canvas canvas, Paint basePaint, Paint contourPaint) {
    const cx = 60.0;

    // Left Thigh / Quad
    final leftThigh = Path()
      ..moveTo(cx - 13, 100)
      ..lineTo(cx - 18, 126)
      ..lineTo(cx - 12, 136)
      ..lineTo(cx - 4, 136)
      ..lineTo(cx - 2, 105)
      ..close();
    canvas.drawPath(leftThigh, basePaint);

    // Left Calf
    final leftCalf = Path()
      ..moveTo(cx - 12, 138)
      ..lineTo(cx - 15, 154)
      ..lineTo(cx - 9, 166)
      ..lineTo(cx - 5, 166)
      ..lineTo(cx - 5, 138)
      ..close();
    canvas.drawPath(leftCalf, basePaint);

    // Right Thigh / Quad
    final rightThigh = Path()
      ..moveTo(cx + 13, 100)
      ..lineTo(cx + 18, 126)
      ..lineTo(cx + 12, 136)
      ..lineTo(cx + 4, 136)
      ..lineTo(cx + 2, 105)
      ..close();
    canvas.drawPath(rightThigh, basePaint);

    // Right Calf
    final rightCalf = Path()
      ..moveTo(cx + 12, 138)
      ..lineTo(cx + 15, 154)
      ..lineTo(cx + 9, 166)
      ..lineTo(cx + 5, 166)
      ..lineTo(cx + 5, 138)
      ..close();
    canvas.drawPath(rightCalf, basePaint);
  }

  void _paintMuscleHeatmap(Canvas canvas, Paint glow, Paint core) {
    const cx = 60.0;

    final isPush = category == RoutineTargetCategory.push;
    final isPull = category == RoutineTargetCategory.pull;
    final isLegs = category == RoutineTargetCategory.legs;
    final isUpper = category == RoutineTargetCategory.upper;
    final isArms = category == RoutineTargetCategory.arms;
    final isCore = category == RoutineTargetCategory.core;
    final isFull = category == RoutineTargetCategory.fullBody;

    // ── Chest / Pectorals (Push, Upper, FullBody) ──
    if (isPush || isUpper || isFull) {
      final leftPec = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx - 15, 41, 13.5, 14),
        const Radius.circular(3.5),
      );
      final rightPec = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx + 1.5, 41, 13.5, 14),
        const Radius.circular(3.5),
      );
      canvas.drawRRect(leftPec, glow);
      canvas.drawRRect(leftPec, core);
      canvas.drawRRect(rightPec, glow);
      canvas.drawRRect(rightPec, core);
    }

    // ── Deltoids / Shoulders (Push, Pull, Upper, Arms, FullBody) ──
    if (isPush || isPull || isUpper || isArms || isFull) {
      final leftDelt = Path()
        ..moveTo(cx - 18, 36)
        ..lineTo(cx - 26, 40)
        ..lineTo(cx - 24, 50)
        ..lineTo(cx - 17, 44)
        ..close();
      final rightDelt = Path()
        ..moveTo(cx + 18, 36)
        ..lineTo(cx + 26, 40)
        ..lineTo(cx + 24, 50)
        ..lineTo(cx + 17, 44)
        ..close();
      canvas.drawPath(leftDelt, glow);
      canvas.drawPath(leftDelt, core);
      canvas.drawPath(rightDelt, glow);
      canvas.drawPath(rightDelt, core);
    }

    // ── Triceps / Biceps (Arms, Push, Pull, Upper) ──
    if (isArms || (isPush && !compact)) {
      // Triceps lateral head
      final leftTri = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx - 28, 51, 6, 17),
        const Radius.circular(2.5),
      );
      final rightTri = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx + 22, 51, 6, 17),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(leftTri, glow);
      canvas.drawRRect(leftTri, core);
      canvas.drawRRect(rightTri, glow);
      canvas.drawRRect(rightTri, core);
    }

    if (isArms || isPull) {
      // Biceps peak
      final leftBi = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx - 25, 52, 5.5, 15),
        const Radius.circular(2.5),
      );
      final rightBi = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx + 19.5, 52, 5.5, 15),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(leftBi, glow);
      canvas.drawRRect(leftBi, core);
      canvas.drawRRect(rightBi, glow);
      canvas.drawRRect(rightBi, core);
    }

    // ── Lats / Back Wings (Pull, Upper, FullBody) ──
    if (isPull || isUpper || isFull) {
      final leftLat = Path()
        ..moveTo(cx - 16, 52)
        ..lineTo(cx - 22, 58)
        ..lineTo(cx - 14, 76)
        ..lineTo(cx - 11, 68)
        ..close();
      final rightLat = Path()
        ..moveTo(cx + 16, 52)
        ..lineTo(cx + 22, 58)
        ..lineTo(cx + 14, 76)
        ..lineTo(cx + 11, 68)
        ..close();
      canvas.drawPath(leftLat, glow);
      canvas.drawPath(leftLat, core);
      canvas.drawPath(rightLat, glow);
      canvas.drawPath(rightLat, core);
    }

    // ── Traps (Pull, Upper) ──
    if (isPull || isUpper) {
      final traps = Path()
        ..moveTo(cx - 6, 29)
        ..lineTo(cx - 18, 36)
        ..lineTo(cx + 18, 36)
        ..lineTo(cx + 6, 29)
        ..close();
      canvas.drawPath(traps, glow);
      canvas.drawPath(traps, core);
    }

    // ── Abdominals / Core (Core, FullBody, Push) ──
    if (isCore || isFull) {
      for (int i = 0; i < 3; i++) {
        final y = 58.0 + (i * 8.5);
        final rLeft = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 8.5, y, 7.5, 7),
          const Radius.circular(2),
        );
        final rRight = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + 1.0, y, 7.5, 7),
          const Radius.circular(2),
        );
        canvas.drawRRect(rLeft, glow);
        canvas.drawRRect(rLeft, core);
        canvas.drawRRect(rRight, glow);
        canvas.drawRRect(rRight, core);
      }
    }

    // ── Quads / Thighs (Legs, FullBody) ──
    if (isLegs || isFull) {
      final leftQuad = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx - 16, 102, 12, 28),
        const Radius.circular(4),
      );
      final rightQuad = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx + 4, 102, 12, 28),
        const Radius.circular(4),
      );
      canvas.drawRRect(leftQuad, glow);
      canvas.drawRRect(leftQuad, core);
      canvas.drawRRect(rightQuad, glow);
      canvas.drawRRect(rightQuad, core);
    }

    // ── Calves (Legs) ──
    if (isLegs) {
      final leftGastro = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx - 14, 140, 8, 20),
        const Radius.circular(3),
      );
      final rightGastro = RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx + 6, 140, 8, 20),
        const Radius.circular(3),
      );
      canvas.drawRRect(leftGastro, glow);
      canvas.drawRRect(leftGastro, core);
      canvas.drawRRect(rightGastro, glow);
      canvas.drawRRect(rightGastro, core);
    }
  }

  @override
  bool shouldRepaint(covariant _AnatomicalSilhouettePainter oldDelegate) {
    return oldDelegate.category != category ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.compact != compact;
  }
}
