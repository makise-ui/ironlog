import 'dart:math';
import 'package:flutter/material.dart';

/// Renders clean, high-resolution vector diagrams for gym exercises.
/// Highlights primary muscle groups, equipment geometry, and movement paths.
class ExerciseDiagramPainter extends CustomPainter {
  final String muscleGroupId;
  final String equipment;
  final bool isDark;
  final bool isThumbnail;

  ExerciseDiagramPainter({
    required this.muscleGroupId,
    required this.equipment,
    required this.isDark,
    this.isThumbnail = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // Color palette
    final baseSilhouetteColor = isDark
        ? const Color(0xFF333333)
        : const Color(0xFFE2E2E8);

    final highlightColor = isDark
        ? const Color(0xFFE5E5E5)
        : const Color(0xFF27272A);

    final equipmentColor = isDark
        ? const Color(0xFF737373)
        : const Color(0xFF71717A);

    final accentGlow = isDark
        ? const Color(0xFF9E9E9E).withValues(alpha: 0.3)
        : const Color(0xFF52525B).withValues(alpha: 0.2);

    final silhouettePaint = Paint()
      ..color = baseSilhouetteColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final highlightPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final equipmentPaint = Paint()
      ..color = equipmentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isThumbnail ? 2.0 : 3.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final glowPaint = Paint()
      ..color = accentGlow
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isThumbnail ? 3 : 8);

    // Draw background grid lines in full view
    if (!isThumbnail) {
      final gridPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03)
        ..strokeWidth = 1;
      for (double x = 0; x < w; x += 24) {
        canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
      }
      for (double y = 0; y < h; y += 24) {
        canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      }
    }

    final scale = min(w, h) / 100.0;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    // Base body coordinates relative to (0,0) center
    // Head: (0, -36) radius 7
    canvas.drawCircle(const Offset(0, -36), 7, silhouettePaint);

    // Torso path
    final torso = Path()
      ..moveTo(-14, -26) // Left shoulder
      ..lineTo(14, -26)  // Right shoulder
      ..lineTo(10, 4)    // Waist right
      ..lineTo(-10, 4)   // Waist left
      ..close();
    canvas.drawPath(torso, silhouettePaint);

    // Pelvis / Hips
    final hips = Path()
      ..moveTo(-11, 4)
      ..lineTo(11, 4)
      ..lineTo(8, 16)
      ..lineTo(-8, 16)
      ..close();
    canvas.drawPath(hips, silhouettePaint);

    // Upper arms
    canvas.drawLine(const Offset(-14, -26), const Offset(-22, -8), Paint()
      ..color = baseSilhouetteColor
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(14, -26), const Offset(22, -8), Paint()
      ..color = baseSilhouetteColor
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round);

    // Forearms
    canvas.drawLine(const Offset(-22, -8), const Offset(-20, 10), Paint()
      ..color = baseSilhouetteColor
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(22, -8), const Offset(20, 10), Paint()
      ..color = baseSilhouetteColor
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round);

    // Thighs / Legs
    canvas.drawLine(const Offset(-6, 16), const Offset(-8, 38), Paint()
      ..color = baseSilhouetteColor
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(6, 16), const Offset(8, 38), Paint()
      ..color = baseSilhouetteColor
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round);

    // Calves
    canvas.drawLine(const Offset(-8, 38), const Offset(-7, 56), Paint()
      ..color = baseSilhouetteColor
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(8, 38), const Offset(7, 56), Paint()
      ..color = baseSilhouetteColor
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round);

    // ── Targeted Muscle Highlight Layer ──
    final mg = muscleGroupId.toLowerCase();
    if (mg == 'chest') {
      // Pectorals
      final chestPath = Path()
        ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-11, -24, 22, 13),
          const Radius.circular(4),
        ));
      canvas.drawPath(chestPath, glowPaint);
      canvas.drawPath(chestPath, highlightPaint);
    } else if (mg == 'back') {
      // Lats / Traps
      final backPath = Path()
        ..moveTo(-13, -25)
        ..lineTo(13, -25)
        ..lineTo(8, -5)
        ..lineTo(-8, -5)
        ..close();
      canvas.drawPath(backPath, glowPaint);
      canvas.drawPath(backPath, highlightPaint);
    } else if (mg == 'shoulders') {
      // Deltoids
      canvas.drawCircle(const Offset(-15, -24), 5.5, glowPaint);
      canvas.drawCircle(const Offset(-15, -24), 5.5, highlightPaint);
      canvas.drawCircle(const Offset(15, -24), 5.5, glowPaint);
      canvas.drawCircle(const Offset(15, -24), 5.5, highlightPaint);
    } else if (mg == 'biceps') {
      // Biceps
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-20, -18, 6, 12), const Radius.circular(3)),
        glowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-20, -18, 6, 12), const Radius.circular(3)),
        highlightPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(14, -18, 6, 12), const Radius.circular(3)),
        glowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(14, -18, 6, 12), const Radius.circular(3)),
        highlightPaint,
      );
    } else if (mg == 'triceps') {
      // Triceps
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -18, 5, 12), const Radius.circular(3)),
        glowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -18, 5, 12), const Radius.circular(3)),
        highlightPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(19, -18, 5, 12), const Radius.circular(3)),
        glowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(19, -18, 5, 12), const Radius.circular(3)),
        highlightPaint,
      );
    } else if (mg == 'legs') {
      // Quads / Hamstrings
      final legLeft = RRect.fromRectAndRadius(const Rect.fromLTWH(-12, 18, 7, 20), const Radius.circular(3));
      final legRight = RRect.fromRectAndRadius(const Rect.fromLTWH(5, 18, 7, 20), const Radius.circular(3));
      canvas.drawRRect(legLeft, glowPaint);
      canvas.drawRRect(legLeft, highlightPaint);
      canvas.drawRRect(legRight, glowPaint);
      canvas.drawRRect(legRight, highlightPaint);
    } else if (mg == 'glutes') {
      // Glutes
      final glutePath = Path()
        ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, 6, 20, 11), const Radius.circular(4)));
      canvas.drawPath(glutePath, glowPaint);
      canvas.drawPath(glutePath, highlightPaint);
    } else if (mg == 'core') {
      // Abs
      final corePath = Path()
        ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -10, 14, 15), const Radius.circular(3)));
      canvas.drawPath(corePath, glowPaint);
      canvas.drawPath(corePath, highlightPaint);
    } else if (mg == 'forearms') {
      // Forearms
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-23, -2, 5, 13), const Radius.circular(2)),
        highlightPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(18, -2, 5, 13), const Radius.circular(2)),
        highlightPaint,
      );
    }

    // ── Equipment Overlay ──
    final eq = equipment.toLowerCase();
    if (eq == 'barbell') {
      // Horizontal bar with plate discs
      canvas.drawLine(const Offset(-38, -14), const Offset(38, -14), equipmentPaint);
      // Outer weights
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-37, -22, 4, 16), const Radius.circular(1)),
        Paint()..color = equipmentColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(33, -22, 4, 16), const Radius.circular(1)),
        Paint()..color = equipmentColor,
      );
    } else if (eq == 'dumbbell') {
      // Two dumbbells in hands
      // Left dumbbell
      canvas.drawLine(const Offset(-21, 1), const Offset(-21, 17), equipmentPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-25, 0, 8, 3), const Radius.circular(1)),
        Paint()..color = equipmentColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-25, 15, 8, 3), const Radius.circular(1)),
        Paint()..color = equipmentColor,
      );
      // Right dumbbell
      canvas.drawLine(const Offset(21, 1), const Offset(21, 17), equipmentPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(17, 0, 8, 3), const Radius.circular(1)),
        Paint()..color = equipmentColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(17, 15, 8, 3), const Radius.circular(1)),
        Paint()..color = equipmentColor,
      );
    } else if (eq == 'cable') {
      // Cable pulley lines
      final cablePaint = Paint()
        ..color = equipmentColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(-32, -38), const Offset(-21, 10), cablePaint);
      canvas.drawLine(const Offset(32, -38), const Offset(21, 10), cablePaint);
      canvas.drawCircle(const Offset(-32, -38), 3, Paint()..color = equipmentColor);
      canvas.drawCircle(const Offset(32, -38), 3, Paint()..color = equipmentColor);
    } else if (eq == 'machine') {
      // Machine structural guide rail / seat
      final machinePaint = Paint()
        ..color = equipmentColor.withValues(alpha: 0.5)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-26, -30, 52, 60), const Radius.circular(8)),
        machinePaint,
      );
    }

    // Concentric movement arrows (only in full preview)
    if (!isThumbnail) {
      final arrowPaint = Paint()
        ..color = (isDark ? const Color(0xFFE5E5E5) : const Color(0xFF3F3F46))
            .withValues(alpha: 0.7)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Subtle curved motion guide
      final motionPath = Path()
        ..moveTo(-30, -5)
        ..quadraticBezierTo(-33, -15, -28, -25);
      canvas.drawPath(motionPath, arrowPaint);

      final motionPathR = Path()
        ..moveTo(30, -5)
        ..quadraticBezierTo(33, -15, 28, -25);
      canvas.drawPath(motionPathR, arrowPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ExerciseDiagramPainter oldDelegate) {
    return oldDelegate.muscleGroupId != muscleGroupId ||
        oldDelegate.equipment != equipment ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isThumbnail != isThumbnail;
  }
}
