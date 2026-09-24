import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';

enum ExercisePattern {
  benchPress,
  inclinePress,
  squat,
  deadlift,
  bicepCurl,
  latPulldown,
  pullUp,
  bentOverRow,
  overheadPress,
  lateralRaise,
  legExtensionPress,
  tricepPushdown,
}

class AnimatedExerciseCanvas extends StatefulWidget {
  final String exerciseName;
  final String muscleGroupId;
  final String equipment;
  final double height;
  final bool isThumbnail;

  const AnimatedExerciseCanvas({
    super.key,
    required this.exerciseName,
    required this.muscleGroupId,
    required this.equipment,
    this.height = 220,
    this.isThumbnail = false,
  });

  static ExercisePattern detectPattern(String name, String muscleGroup, String equipment) {
    final n = name.toLowerCase();
    final mg = muscleGroup.toLowerCase();

    if (n.contains('incline') && (n.contains('press') || n.contains('bench'))) {
      return ExercisePattern.inclinePress;
    }
    if (n.contains('bench') || n.contains('chest press') || n.contains('push-up') || n.contains('dip')) {
      return ExercisePattern.benchPress;
    }
    if (n.contains('squat') || n.contains('lunge') || n.contains('hack squat')) {
      return ExercisePattern.squat;
    }
    if (n.contains('deadlift') || n.contains('hip thrust') || n.contains('good morning')) {
      return ExercisePattern.deadlift;
    }
    if (n.contains('curl') && (mg == 'biceps' || n.contains('bicep') || n.contains('hammer'))) {
      return ExercisePattern.bicepCurl;
    }
    if (n.contains('pulldown')) {
      return ExercisePattern.latPulldown;
    }
    if (n.contains('pull-up') || n.contains('chin-up')) {
      return ExercisePattern.pullUp;
    }
    if (n.contains('row')) {
      return ExercisePattern.bentOverRow;
    }
    if (n.contains('overhead') || n.contains('shoulder press') || n.contains('military') || n.contains('arnold')) {
      return ExercisePattern.overheadPress;
    }
    if (n.contains('lateral raise') || n.contains('front raise') || n.contains('fly')) {
      return ExercisePattern.lateralRaise;
    }
    if (n.contains('leg press') || n.contains('leg extension') || n.contains('leg curl') || n.contains('calf')) {
      return ExercisePattern.legExtensionPress;
    }
    if (n.contains('pushdown') || n.contains('extension') || mg == 'triceps') {
      return ExercisePattern.tricepPushdown;
    }
    if (mg == 'chest' || mg == 'shoulders') {
      return ExercisePattern.benchPress;
    }
    if (mg == 'legs') {
      return ExercisePattern.squat;
    }
    return ExercisePattern.bentOverRow;
  }

  @override
  State<AnimatedExerciseCanvas> createState() => _AnimatedExerciseCanvasState();
}

class _AnimatedExerciseCanvasState extends State<AnimatedExerciseCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isPlaying = true;
  double _speed = 1.0; // 1.0x or 0.5x Slow-Mo

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    AppHaptics.tap();
    setState(() {
      if (_isPlaying) {
        _controller.stop();
        _isPlaying = false;
      } else {
        _controller.repeat(reverse: true);
        _isPlaying = true;
      }
    });
  }

  void _toggleSpeed() {
    AppHaptics.step();
    setState(() {
      _speed = _speed == 1.0 ? 0.5 : 1.0;
      final ms = (2400 / _speed).round();
      _controller.duration = Duration(milliseconds: ms);
      if (_isPlaying) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pattern = AnimatedExerciseCanvas.detectPattern(
      widget.exerciseName,
      widget.muscleGroupId,
      widget.equipment,
    );

    if (widget.isThumbnail) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.height, widget.height),
            painter: _ExercisePhysicsPainter(
              pattern: pattern,
              progress: _controller.value,
              muscleGroupId: widget.muscleGroupId,
              equipment: widget.equipment,
              isDark: isDark,
              isThumbnail: true,
            ),
          );
        },
      );
    }

    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF383838) : const Color(0xFFE2E2E8),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated Canvas
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ExercisePhysicsPainter(
                      pattern: pattern,
                      progress: _controller.value,
                      muscleGroupId: widget.muscleGroupId,
                      equipment: widget.equipment,
                      isDark: isDark,
                      isThumbnail: false,
                    ),
                  );
                },
              ),
            ),

            // Top Badges: Equipment & Muscle Tag
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF141414) : Colors.white).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF424242) : const Color(0xFFE5E5E5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isPlaying ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isPlaying ? 'ANIMATED REP' : 'PAUSED',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Control Bar: Phase Indicator, Speed Toggle, Play/Pause
            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final isLowering = _controller.status == AnimationStatus.forward;
                  final phaseText = isLowering
                      ? 'LOWERING (ECCENTRIC)'
                      : 'LIFTING (CONCENTRIC)';

                  return Row(
                    children: [
                      // Phase Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF121212) : Colors.white).withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF383838) : const Color(0xFFE2E2E8),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          phaseText,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Speed Toggle (1.0x / 0.5x)
                      GestureDetector(
                        onTap: _toggleSpeed,
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF262626) : const Color(0xFFEEEEF0)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF383838) : const Color(0xFFD4D4D8),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${_speed}x',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      ),

                      // Play/Pause Button
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF262626) : const Color(0xFFEEEEF0)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF383838) : const Color(0xFFD4D4D8),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 16,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed Vector Physics Painter that animates the lifter, joints, and equipment
class _ExercisePhysicsPainter extends CustomPainter {
  final ExercisePattern pattern;
  final double progress; // 0.0 (lockout/start) -> 1.0 (bottom/stretch)
  final String muscleGroupId;
  final String equipment;
  final bool isDark;
  final bool isThumbnail;

  _ExercisePhysicsPainter({
    required this.pattern,
    required this.progress,
    required this.muscleGroupId,
    required this.equipment,
    required this.isDark,
    required this.isThumbnail,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final scale = min(w, h) / 100.0;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    // Color definitions
    final steelColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280);
    final chromeColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF9CA3AF);
    final plateColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFF374151);
    final benchPadColor = isDark ? const Color(0xFF262626) : const Color(0xFFD1D5DB);
    final frameColor = isDark ? const Color(0xFF404040) : const Color(0xFF9CA3AF);

    final skinColor = isDark ? const Color(0xFF52525B) : const Color(0xFFD4D4D8);
    final activeMuscleColor = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF18181B);

    final t = Curves.easeInOutSine.transform(progress);

    // Subtle background floor line
    final floorPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(-46, 42), const Offset(46, 42), floorPaint);

    switch (pattern) {
      case ExercisePattern.benchPress:
      case ExercisePattern.inclinePress:
        _drawBenchPress(
          canvas,
          t: t,
          isIncline: pattern == ExercisePattern.inclinePress,
          steel: steelColor,
          chrome: chromeColor,
          plate: plateColor,
          benchPad: benchPadColor,
          frame: frameColor,
          skin: skinColor,
          activeMuscle: activeMuscleColor,
        );
        break;

      case ExercisePattern.squat:
        _drawSquat(
          canvas,
          t: t,
          steel: steelColor,
          chrome: chromeColor,
          plate: plateColor,
          frame: frameColor,
          skin: skinColor,
          activeMuscle: activeMuscleColor,
        );
        break;

      case ExercisePattern.deadlift:
        _drawDeadlift(
          canvas,
          t: t,
          steel: steelColor,
          chrome: chromeColor,
          plate: plateColor,
          skin: skinColor,
          activeMuscle: activeMuscleColor,
        );
        break;

      case ExercisePattern.bicepCurl:
        _drawBicepCurl(
          canvas,
          t: t,
          steel: steelColor,
          plate: plateColor,
          skin: skinColor,
          activeMuscle: activeMuscleColor,
        );
        break;

      case ExercisePattern.latPulldown:
      case ExercisePattern.pullUp:
        _drawLatPulldown(
          canvas,
          t: t,
          isPullup: pattern == ExercisePattern.pullUp,
          steel: steelColor,
          chrome: chromeColor,
          frame: frameColor,
          plate: plateColor,
          skin: skinColor,
          activeMuscle: activeMuscleColor,
        );
        break;

      case ExercisePattern.bentOverRow:
        _drawBentOverRow(
          canvas,
          t: t,
          steel: steelColor,
          chrome: chromeColor,
          plate: plateColor,
          skin: skinColor,
          activeMuscle: activeMuscleColor,
        );
        break;

      case ExercisePattern.overheadPress:
        _drawOverheadPress(
          canvas,
          t: t,
          steel: steelColor,
          chrome: chromeColor,
          plate: plateColor,
          skin: skinColor,
          activeMuscle: activeMuscleColor,
        );
        break;

      default:
        _drawBenchPress(
          canvas,
          t: t,
          isIncline: false,
          steel: steelColor,
          chrome: chromeColor,
          plate: plateColor,
          benchPad: benchPadColor,
          frame: frameColor,
          skin: skinColor,
          activeMuscle: activeMuscleColor,
        );
    }

    canvas.restore();
  }

  // 1. BENCH PRESS (Detailed bench, upright rack, bar with plates, lifter arms lowering & pressing)
  void _drawBenchPress(
    Canvas canvas, {
    required double t,
    required bool isIncline,
    required Color steel,
    required Color chrome,
    required Color plate,
    required Color benchPad,
    required Color frame,
    required Color skin,
    required Color activeMuscle,
  }) {
    final angle = isIncline ? -0.32 : 0.0;

    // Equipment: Bench Rack Upright Posts
    final rackPaint = Paint()
      ..color = frame
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(22, -18), const Offset(22, 42), rackPaint);
    canvas.drawLine(const Offset(-28, 12), const Offset(-28, 42), rackPaint);
    // Bench horizontal support beam
    canvas.drawLine(const Offset(-32, 22), const Offset(22, 22), rackPaint..strokeWidth = 2.5);

    // Bench J-Hooks
    final hookPaint = Paint()
      ..color = steel
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final hook = Path()
      ..moveTo(22, -18)
      ..lineTo(25, -18)
      ..lineTo(25, -23);
    canvas.drawPath(hook, hookPaint);

    // Bench Leather Pad
    canvas.save();
    canvas.rotate(angle);
    final padPaint = Paint()..color = benchPad;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-32, 6, 44, 8), const Radius.circular(3)),
      padPaint,
    );
    // Stitch line
    canvas.drawLine(
      const Offset(-30, 10),
      const Offset(10, 10),
      Paint()..color = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.3)..strokeWidth = 1,
    );
    canvas.restore();

    // Lifter Head on bench
    canvas.drawCircle(const Offset(10, 3), 6.5, Paint()..color = skin);

    // Lifter Torso lying on bench
    final torsoPaint = Paint()..color = skin..strokeWidth = 9.0..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(6, 7), const Offset(-18, 7), torsoPaint);

    // Lifter Chest Highlight (pulses in intensity as bar presses up)
    final chestPulse = (1.0 - t * 0.5);
    final chestHighlight = Paint()
      ..color = activeMuscle.withValues(alpha: chestPulse)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(2, 6), const Offset(-10, 6), chestHighlight);

    // Lifter Legs (angled down to floor)
    final legPaint = Paint()..color = skin..strokeWidth = 6.0..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-18, 9), const Offset(-24, 24), legPaint);
    canvas.drawLine(const Offset(-24, 24), const Offset(-26, 42), legPaint..strokeWidth = 5.0);

    // Arms & Barbell Physics
    // Bar starts at lockout y = -22 (t = 0.0), lowers to chest y = -2 (t = 1.0)
    final barY = -22.0 + (t * 20.0);
    final barX = -3.0;

    // Elbow position bends outward
    final shoulderX = 2.0;
    final shoulderY = 7.0;
    final elbowX = shoulderX - (6.0 * t) - 4.0;
    final elbowY = shoulderY + (14.0 * t) - 1.0;

    // Upper Arm
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(elbowX, elbowY), Paint()..color = skin..strokeWidth = 6.0..strokeCap = StrokeCap.round);
    // Forearm up to bar
    canvas.drawLine(Offset(elbowX, elbowY), Offset(barX, barY), Paint()..color = skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);

    // ── Olympic Barbell & Weight Plates ──
    final barPaint = Paint()..color = chrome..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-38, barY), Offset(38, barY), barPaint);

    // Bar Knurling markings
    final knurlPaint = Paint()..color = steel..strokeWidth = 2.5;
    canvas.drawLine(Offset(-16, barY), Offset(-7, barY), knurlPaint);
    canvas.drawLine(Offset(7, barY), Offset(16, barY), knurlPaint);

    // Left Olympic Plates
    _drawBarbellPlates(canvas, Offset(-32, barY), plate, steel);
    // Right Olympic Plates
    _drawBarbellPlates(canvas, Offset(32, barY), plate, steel);
  }

  // 2. SQUAT (Squat cage, lifter descending to parallel, Olympic bar on traps, quads contracting)
  void _drawSquat(
    Canvas canvas, {
    required double t,
    required Color steel,
    required Color chrome,
    required Color plate,
    required Color frame,
    required Color skin,
    required Color activeMuscle,
  }) {
    // Power Cage Posts
    final cagePaint = Paint()..color = frame..strokeWidth = 2.5;
    canvas.drawLine(const Offset(-32, -38), const Offset(-32, 42), cagePaint);
    canvas.drawLine(const Offset(32, -38), const Offset(32, 42), cagePaint);
    // Safety spotter horizontal bars
    canvas.drawLine(const Offset(-32, 18), const Offset(-20, 18), cagePaint..strokeWidth = 2);
    canvas.drawLine(const Offset(20, 18), const Offset(32, 18), cagePaint..strokeWidth = 2);

    // Kinematics: Standing (t = 0.0) -> Deep Squat (t = 1.0)
    final hipY = -2.0 + (t * 18.0);
    final kneeY = 16.0 + (t * 2.0);
    final kneeX = -12.0 - (t * 6.0);
    final hipX = -4.0 + (t * 10.0); // Hips hinge backward
    final shoulderY = hipY - 24.0;
    final shoulderX = hipX - 4.0;
    final headY = shoulderY - 9.0;
    final headX = shoulderX + 2.0;

    // Head
    canvas.drawCircle(Offset(headX, headY), 6.5, Paint()..color = skin);

    // Torso (spines stays neutral)
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(hipX, hipY), Paint()..color = skin..strokeWidth = 9.0..strokeCap = StrokeCap.round);

    // Thighs / Quadriceps (glows on ascent)
    final quadGlow = (1.0 - t * 0.4);
    final thighPaint = Paint()..color = skin..strokeWidth = 8.0..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(hipX, hipY), Offset(kneeX, kneeY), thighPaint);
    canvas.drawLine(Offset(hipX, hipY), Offset(kneeX, kneeY), Paint()..color = activeMuscle.withValues(alpha: quadGlow)..strokeWidth = 6.0..strokeCap = StrokeCap.round);

    // Calves down to feet on floor
    final calfPaint = Paint()..color = skin..strokeWidth = 6.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(kneeX, kneeY), const Offset(-10, 42), calfPaint);

    // Arms gripping the bar
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(shoulderX + 6, shoulderY + 8), Paint()..color = skin..strokeWidth = 5.0..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(shoulderX + 6, shoulderY + 8), Offset(shoulderX + 2, shoulderY), Paint()..color = skin..strokeWidth = 4.5..strokeCap = StrokeCap.round);

    // Olympic Bar on Traps
    final barY = shoulderY + 1.0;
    canvas.drawLine(Offset(-36, barY), Offset(36, barY), Paint()..color = chrome..strokeWidth = 3.0..strokeCap = StrokeCap.round);
    _drawBarbellPlates(canvas, Offset(-30, barY), plate, steel);
    _drawBarbellPlates(canvas, Offset(30, barY), plate, steel);
  }

  // 3. DEADLIFT (Lifter hinging down to barbell on floor and standing to lockout)
  void _drawDeadlift(
    Canvas canvas, {
    required double t,
    required Color steel,
    required Color chrome,
    required Color plate,
    required Color skin,
    required Color activeMuscle,
  }) {
    // Kinematics: Lockout (t = 0.0) -> Floor bottom (t = 1.0)
    final barY = 12.0 + (t * 22.0); // Bar moves from midthigh to near floor
    final hipX = 6.0 + (t * 14.0);
    final hipY = 2.0 + (t * 10.0);
    final shoulderX = 2.0 - (t * 4.0);
    final shoulderY = -18.0 + (t * 22.0);
    final headY = shoulderY - 8.0;

    // Head
    canvas.drawCircle(Offset(shoulderX + 1, headY), 6.5, Paint()..color = skin);

    // Torso (hinging at hips)
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(hipX, hipY), Paint()..color = skin..strokeWidth = 8.5..strokeCap = StrokeCap.round);

    // Back & Glutes tension highlight
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(hipX, hipY), Paint()..color = activeMuscle.withValues(alpha: 0.7)..strokeWidth = 5.5..strokeCap = StrokeCap.round);

    // Thighs
    final kneeX = -2.0 - (t * 3.0);
    final kneeY = 18.0 + (t * 4.0);
    canvas.drawLine(Offset(hipX, hipY), Offset(kneeX, kneeY), Paint()..color = skin..strokeWidth = 7.5..strokeCap = StrokeCap.round);
    // Shins
    canvas.drawLine(Offset(kneeX, kneeY), const Offset(-3, 42), Paint()..color = skin..strokeWidth = 6.0..strokeCap = StrokeCap.round);

    // Arms hanging straight down to bar
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(0, barY), Paint()..color = skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);

    // Barbell on shins
    canvas.drawLine(Offset(-36, barY), Offset(36, barY), Paint()..color = chrome..strokeWidth = 2.8..strokeCap = StrokeCap.round);
    _drawBarbellPlates(canvas, Offset(-30, barY), plate, steel);
    _drawBarbellPlates(canvas, Offset(30, barY), plate, steel);
  }

  // 4. BICEP CURL (Lifter standing, elbow fixed, forearm curls up to shoulder)
  void _drawBicepCurl(
    Canvas canvas, {
    required double t,
    required Color steel,
    required Color plate,
    required Color skin,
    required Color activeMuscle,
  }) {
    // Lifter Standing tall
    canvas.drawCircle(const Offset(0, -32), 6.5, Paint()..color = skin);
    canvas.drawLine(const Offset(0, -24), const Offset(0, 8), Paint()..color = skin..strokeWidth = 9.0..strokeCap = StrokeCap.round);

    // Legs
    canvas.drawLine(const Offset(-4, 8), const Offset(-6, 42), Paint()..color = skin..strokeWidth = 7.0..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(4, 8), const Offset(6, 42), Paint()..color = skin..strokeWidth = 7.0..strokeCap = StrokeCap.round);

    // Left arm (resting)
    canvas.drawLine(const Offset(-7, -20), const Offset(-12, -4), Paint()..color = skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(-12, -4), const Offset(-12, 12), Paint()..color = skin..strokeWidth = 5.0..strokeCap = StrokeCap.round);

    // Active Right Arm: Upper arm stays pinned to torso
    final shoulder = const Offset(7, -20);
    final elbow = const Offset(12, -4);
    canvas.drawLine(shoulder, elbow, Paint()..color = skin..strokeWidth = 6.0..strokeCap = StrokeCap.round);

    // Bicep contraction: curl angle from down (1.5 rad) to flexed (-1.4 rad)
    final curlAngle = 1.5 - (t * 2.6);
    final forearmLength = 16.0;
    final handX = elbow.dx + cos(curlAngle) * forearmLength;
    final handY = elbow.dy + sin(curlAngle) * forearmLength;

    // Forearm
    canvas.drawLine(elbow, Offset(handX, handY), Paint()..color = skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);

    // Bicep Muscle Flexing & Bulging at peak
    final bicepBulge = 4.0 + (t * 3.5);
    final bicepPaint = Paint()
      ..color = activeMuscle.withValues(alpha: 0.3 + (t * 0.7))
      ..strokeWidth = bicepBulge
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(7, -16), const Offset(10, -6), bicepPaint);

    // Hex Dumbbell in hand
    _drawDumbbell(canvas, Offset(handX, handY), plate, steel);
  }

  // 5. LAT PULLDOWN / PULL-UP (Overhead station, cable pulling down, weight stack rising)
  void _drawLatPulldown(
    Canvas canvas, {
    required double t,
    required bool isPullup,
    required Color steel,
    required Color chrome,
    required Color frame,
    required Color plate,
    required Color skin,
    required Color activeMuscle,
  }) {
    // Cable Machine Top Frame & Pulley
    final framePaint = Paint()..color = frame..strokeWidth = 3.0;
    canvas.drawLine(const Offset(-28, -38), const Offset(28, -38), framePaint);
    canvas.drawLine(const Offset(24, -38), const Offset(24, 42), framePaint); // Vertical tower
    canvas.drawCircle(const Offset(0, -38), 4.5, Paint()..color = steel..style = PaintingStyle.stroke..strokeWidth = 2);

    // Moving Weight Stack in rear tower (rises as lifter pulls!)
    final stackY = 24.0 - (t * 14.0);
    for (int i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(18, stackY + (i * 3.5), 12, 2.5), const Radius.circular(1)),
        Paint()..color = plate,
      );
    }

    // Kinematics: Overhead reach (t = 0.0) -> Bar at chest (t = 1.0)
    final barY = -30.0 + (t * 18.0);
    final seatY = 16.0;

    // Cable line from pulley to bar
    canvas.drawLine(const Offset(0, -38), Offset(0, barY), Paint()..color = steel..strokeWidth = 1.8);

    // Lifter Seated on Lat Bench
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 16, 18, 6), const Radius.circular(2)),
      Paint()..color = frame,
    );
    // Thigh pad hold-down
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 8, 10, 4), const Radius.circular(2)),
      Paint()..color = steel,
    );

    // Lifter Head & Torso
    canvas.drawCircle(const Offset(-4, -6), 6.5, Paint()..color = skin);
    canvas.drawLine(const Offset(-4, 0), Offset(-4, seatY), Paint()..color = skin..strokeWidth = 9.0..strokeCap = StrokeCap.round);

    // Lats Muscle Contraction
    final latPaint = Paint()..color = activeMuscle.withValues(alpha: 0.3 + (t * 0.7))..strokeWidth = 6.0..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-7, 2), const Offset(-7, 12), latPaint);

    // Arms pulling bar down
    final elbowX = -12.0 - (t * 4.0);
    final elbowY = -8.0 + (t * 12.0);
    canvas.drawLine(const Offset(-4, 2), Offset(elbowX, elbowY), Paint()..color = skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(elbowX, elbowY), Offset(-16, barY), Paint()..color = skin..strokeWidth = 5.0..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(-4, 2), Offset(-elbowX, elbowY), Paint()..color = skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(-elbowX, elbowY), Offset(16, barY), Paint()..color = skin..strokeWidth = 5.0..strokeCap = StrokeCap.round);

    // Ergonomic Curved Lat Pulldown Bar
    final barPath = Path()
      ..moveTo(-32, barY + 3)
      ..lineTo(-26, barY)
      ..lineTo(26, barY)
      ..lineTo(32, barY + 3);
    canvas.drawPath(barPath, Paint()..color = chrome..strokeWidth = 2.8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  // 6. BENT-OVER ROW (Hinged torso, pulling bar up into abdomen)
  void _drawBentOverRow(
    Canvas canvas, {
    required double t,
    required Color steel,
    required Color chrome,
    required Color plate,
    required Color skin,
    required Color activeMuscle,
  }) {
    // Torso fixed at 45 degrees
    final shoulder = const Offset(2, -8);
    final hip = const Offset(14, 8);
    canvas.drawCircle(const Offset(-3, -15), 6.5, Paint()..color = skin);
    canvas.drawLine(shoulder, hip, Paint()..color = skin..strokeWidth = 8.5..strokeCap = StrokeCap.round);

    // Upper back / lats highlight
    canvas.drawLine(shoulder, hip, Paint()..color = activeMuscle.withValues(alpha: 0.3 + (t * 0.7))..strokeWidth = 5.5..strokeCap = StrokeCap.round);

    // Legs
    canvas.drawLine(hip, const Offset(6, 22), Paint()..color = skin..strokeWidth = 7.5..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(6, 22), const Offset(4, 42), Paint()..color = skin..strokeWidth = 6.0..strokeCap = StrokeCap.round);

    // Bar pulls from hanging (y = 22) up to abdomen (y = 5)
    final barY = 22.0 - (t * 17.0);
    final elbowX = 6.0 + (t * 6.0);
    final elbowY = -2.0 - (t * 8.0);

    canvas.drawLine(shoulder, Offset(elbowX, elbowY), Paint()..color = skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(elbowX, elbowY), Offset(0, barY), Paint()..color = skin..strokeWidth = 5.0..strokeCap = StrokeCap.round);

    // Barbell
    canvas.drawLine(Offset(-34, barY), Offset(34, barY), Paint()..color = chrome..strokeWidth = 2.8..strokeCap = StrokeCap.round);
    _drawBarbellPlates(canvas, Offset(-28, barY), plate, steel);
    _drawBarbellPlates(canvas, Offset(28, barY), plate, steel);
  }

  // 7. OVERHEAD PRESS (Standing lifter pressing bar from shoulders to overhead lockout)
  void _drawOverheadPress(
    Canvas canvas, {
    required double t,
    required Color steel,
    required Color chrome,
    required Color plate,
    required Color skin,
    required Color activeMuscle,
  }) {
    // Standing Lifter
    canvas.drawCircle(const Offset(0, -18), 6.5, Paint()..color = skin);
    canvas.drawLine(const Offset(0, -10), const Offset(0, 14), Paint()..color = skin..strokeWidth = 9.0..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(-4, 14), const Offset(-5, 42), Paint()..color = skin..strokeWidth = 7.0..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(4, 14), const Offset(5, 42), Paint()..color = skin..strokeWidth = 7.0..strokeCap = StrokeCap.round);

    // Shoulder highlight
    canvas.drawCircle(const Offset(-6, -9), 4.5, Paint()..color = activeMuscle.withValues(alpha: 0.3 + (t * 0.7)));
    canvas.drawCircle(const Offset(6, -9), 4.5, Paint()..color = activeMuscle.withValues(alpha: 0.3 + (t * 0.7)));

    // Bar moves from collarbone y = -8 (t = 1.0) to overhead y = -36 (t = 0.0)
    final barY = -36.0 + (t * 26.0);
    final elbowX = 8.0 + (t * 6.0);
    final elbowY = -12.0 + (t * 14.0);

    // Arms
    canvas.drawLine(const Offset(6, -9), Offset(elbowX, elbowY), Paint()..color = skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(elbowX, elbowY), Offset(10, barY), Paint()..color = skin..strokeWidth = 5.0..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(-6, -9), Offset(-elbowX, elbowY), Paint()..color = skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(-elbowX, elbowY), Offset(-10, barY), Paint()..color = skin..strokeWidth = 5.0..strokeCap = StrokeCap.round);

    // Barbell
    canvas.drawLine(Offset(-36, barY), Offset(36, barY), Paint()..color = chrome..strokeWidth = 2.8..strokeCap = StrokeCap.round);
    _drawBarbellPlates(canvas, Offset(-30, barY), plate, steel);
    _drawBarbellPlates(canvas, Offset(30, barY), plate, steel);
  }

  // Helper: Draws authentic Olympic weight plates with inner hub
  void _drawBarbellPlates(Canvas canvas, Offset center, Color plateColor, Color steelColor) {
    // 20kg Outer bumper plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 3, center.dy - 12, 6, 24), const Radius.circular(2)),
      Paint()..color = plateColor,
    );
    // 10kg Inner plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(center.dx + 4, center.dy - 9, 4, 18), const Radius.circular(1.5)),
      Paint()..color = plateColor,
    );
    // Steel collar clamp
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(center.dx + 8, center.dy - 4, 3, 8), const Radius.circular(1)),
      Paint()..color = steelColor,
    );
  }

  // Helper: Draws hexagonal rubber dumbbell
  void _drawDumbbell(Canvas canvas, Offset center, Color plateColor, Color steelColor) {
    // Knurled Steel Handle
    canvas.drawLine(
      Offset(center.dx - 1, center.dy - 7),
      Offset(center.dx - 1, center.dy + 7),
      Paint()..color = steelColor..strokeWidth = 2.5,
    );
    // Top hex head
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 6, center.dy - 10, 10, 4), const Radius.circular(1.5)),
      Paint()..color = plateColor,
    );
    // Bottom hex head
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 6, center.dy + 6, 10, 4), const Radius.circular(1.5)),
      Paint()..color = plateColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ExercisePhysicsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pattern != pattern ||
        oldDelegate.isDark != isDark;
  }
}
