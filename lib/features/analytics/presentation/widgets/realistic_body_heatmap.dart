import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../domain/models/muscle_recovery_model.dart';

/// Interactive 360-degree turntable human anatomy recovery & fatigue heatmap.
/// Renders an authentic, athletic 3D human anatomy model with interactive 360° drag rotation,
/// dynamic on-skin physiological recovery heat highlights, touch selection, and detailed recovery metrics.
class RealisticBodyHeatmap extends StatefulWidget {
  final Map<String, MuscleRecoveryData> recoveryData;
  final ValueChanged<String>? onMuscleSelected;

  const RealisticBodyHeatmap({
    super.key,
    required this.recoveryData,
    this.onMuscleSelected,
  });

  @override
  State<RealisticBodyHeatmap> createState() => _RealisticBodyHeatmapState();
}

class _RealisticBodyHeatmapState extends State<RealisticBodyHeatmap>
    with TickerProviderStateMixin {
  // Current rotation angle in degrees (0.0 to 360.0)
  double _currentAngle = 0.0;
  bool _postWorkoutHeatMode = false;
  String _selectedMuscleId = 'chest';

  // Loaded 360 turntable angle images
  final Map<int, ui.Image> _angleImages = {};
  bool _imagesLoaded = false;

  late final AnimationController _pulseController;
  AnimationController? _snapController;
  Animation<double>? _snapAnimation;

  final List<int> _keyAngles = [0, 45, 90, 135, 180];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() {
            _currentAngle = _snapAnimation!.value % 360.0;
            if (_currentAngle < 0) _currentAngle += 360.0;
          });
        }
      });

    _loadTurntableImages();
  }

  Future<void> _loadTurntableImages() async {
    try {
      for (final angle in _keyAngles) {
        final data = await rootBundle.load('assets/images/turntable/angle_$angle.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _angleImages[angle] = frame.image;
      }

      if (mounted) {
        setState(() {
          _imagesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading turntable images: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _snapController?.dispose();
    super.dispose();
  }

  void _rotateByDelta(double dx) {
    // 1 pixel drag = ~0.65 degrees rotation
    final newAngle = (_currentAngle - dx * 0.65) % 360.0;
    setState(() {
      _currentAngle = newAngle < 0 ? newAngle + 360.0 : newAngle;
    });
  }

  void _animateToAngle(double targetAngle) {
    AppHaptics.selection();
    _snapController?.stop();

    // Find shortest angular distance
    double diff = (targetAngle - _currentAngle) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;

    final endAngle = _currentAngle + diff;

    _snapAnimation = Tween<double>(
      begin: _currentAngle,
      end: endAngle,
    ).animate(CurvedAnimation(parent: _snapController!, curve: Curves.easeOutCubic));

    _snapController!.forward(from: 0.0);
  }

  void _selectMuscle(String muscleId) {
    AppHaptics.selection();
    setState(() {
      _selectedMuscleId = muscleId;
    });
    widget.onMuscleSelected?.call(muscleId);
  }

  MuscleRecoveryData _getRecovery(String muscleId) {
    final key = muscleId.toLowerCase().trim();

    if (_postWorkoutHeatMode) {
      final displayName = key.isNotEmpty ? (key[0].toUpperCase() + key.substring(1)) : 'Muscle';
      if (key == 'chest' || key == 'triceps' || key == 'deltoids' || key == 'shoulders') {
        return MuscleRecoveryData(
          id: key,
          name: displayName,
          recoveryPercent: 0.22,
          hoursSinceLastTrained: 2.5,
          lastTrainedDate: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
          weeklySetsCount: 12,
          status: 'Acute Fatigue',
          tip: 'Heavy mechanical tension and micro-trauma. Active glycogen depletion detected. Allow 48h rest.',
        );
      }
      if (key == 'core' || key == 'biceps' || key == 'back' || key == 'traps' || key == 'lats') {
        return MuscleRecoveryData(
          id: key,
          name: displayName,
          recoveryPercent: 0.58,
          hoursSinceLastTrained: 26.0,
          lastTrainedDate: DateTime.now().subtract(const Duration(hours: 26)),
          weeklySetsCount: 8,
          status: 'Recovering',
          tip: 'Supercompensation phase active. Muscle tissue repair and protein synthesis in progress.',
        );
      }
      return MuscleRecoveryData(
        id: key,
        name: displayName,
        recoveryPercent: 0.95,
        hoursSinceLastTrained: 72.0,
        lastTrainedDate: DateTime.now().subtract(const Duration(days: 3)),
        weeklySetsCount: 6,
        status: 'Fully Recovered',
        tip: 'Zero muscular fatigue. Neuromuscular system primed for maximum load.',
      );
    }

    if (widget.recoveryData.containsKey(key)) {
      return widget.recoveryData[key]!;
    }
    if (key == 'deltoids' || key == 'traps') {
      return widget.recoveryData['shoulders'] ?? _fallback(muscleId);
    }
    if (key == 'lats' || key == 'lower_back') {
      return widget.recoveryData['back'] ?? _fallback(muscleId);
    }
    if (key == 'quads' || key == 'hamstrings' || key == 'calves' || key == 'glutes') {
      return widget.recoveryData['legs'] ?? _fallback(muscleId);
    }
    if (key == 'biceps' || key == 'triceps' || key == 'forearms') {
      return widget.recoveryData['arms'] ?? _fallback(muscleId);
    }
    return _fallback(muscleId);
  }

  MuscleRecoveryData _fallback(String id) {
    final name = id.isNotEmpty ? (id[0].toUpperCase() + id.substring(1)) : 'Unknown';
    return MuscleRecoveryData(
      id: id,
      name: name,
      recoveryPercent: 1.0,
      hoursSinceLastTrained: null,
      lastTrainedDate: null,
      weeklySetsCount: 0,
      status: 'Fully Recovered',
      tip: 'Optimal readiness. Zero muscular fatigue detected.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeData = _getRecovery(_selectedMuscleId);

    final normAngle = _currentAngle % 360.0;
    final isSideFacing = (normAngle >= 67.5 && normAngle <= 112.5) || (normAngle >= 247.5 && normAngle <= 292.5);
    final isBackFacing = normAngle > 112.5 && normAngle < 247.5;

    // Dynamic muscles visible at current 360 degree angle
    final frontMuscles = [
      ('chest', 'Chest'),
      ('shoulders', 'Delts'),
      ('biceps', 'Biceps'),
      ('core', 'Abs/Core'),
      ('legs', 'Quads'),
      ('calves', 'Calves'),
      ('forearms', 'Forearms'),
    ];

    final backMuscles = [
      ('traps', 'Traps'),
      ('back', 'Lats/Back'),
      ('triceps', 'Triceps'),
      ('lower_back', 'Lower Back'),
      ('glutes', 'Glutes'),
      ('legs', 'Hamstrings'),
      ('calves', 'Calves'),
    ];

    final sideMuscles = [
      ('shoulders', 'Delts'),
      ('chest', 'Chest'),
      ('back', 'Lats/Back'),
      ('biceps', 'Biceps'),
      ('triceps', 'Triceps'),
      ('forearms', 'Forearms'),
      ('core', 'Abs/Core'),
      ('glutes', 'Glutes'),
      ('legs', 'Legs/Thigh'),
      ('calves', 'Calves'),
    ];

    final currentPillList = isSideFacing
        ? sideMuscles
        : (isBackFacing ? backMuscles : frontMuscles);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.threed_rotation_rounded, size: 20, color: context.accent),
                        const SizedBox(width: 8),
                        Text(
                          '360° Muscle Heatmap',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Drag model to spin 360° • Direct on-skin thermal recovery',
                      style: TextStyle(fontSize: 11, color: context.textTertiary),
                    ),
                  ],
                ),
              ),
              // 360 Cardinal Angle Quick Pills
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: context.chipBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.chipBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAngleJumpPill('Front', 0.0),
                    _buildAngleJumpPill('Side', 90.0),
                    _buildAngleJumpPill('Back', 180.0),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Simulation Toggle + Responsive Legend (Wrap to prevent overflow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _postWorkoutHeatMode = !_postWorkoutHeatMode);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _postWorkoutHeatMode
                        ? const Color(0xFFEF4444).withValues(alpha: 0.16)
                        : context.chipBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _postWorkoutHeatMode
                          ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                          : context.chipBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _postWorkoutHeatMode ? Icons.local_fire_department_rounded : Icons.flash_on_rounded,
                        size: 13,
                        color: _postWorkoutHeatMode ? const Color(0xFFEF4444) : context.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _postWorkoutHeatMode ? 'Post-Workout Heat' : 'Live Log Recovery',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _postWorkoutHeatMode ? const Color(0xFFEF4444) : context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Wrap(
                spacing: 8,
                children: [
                  _buildLegendDot(const Color(0xFF10B981), 'Ready', context),
                  _buildLegendDot(const Color(0xFFF59E0B), 'Recovering', context),
                  _buildLegendDot(const Color(0xFFEF4444), 'Fatigued', context),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 360 Turntable Frame
          Center(
            child: Container(
              height: 380,
              width: 285, // 3:4 Aspect Ratio matching 896x1200
              decoration: BoxDecoration(
                color: const Color(0xFF090B10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E2530), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    if (!_imagesLoaded) {
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        _rotateByDelta(details.primaryDelta!);
                      },
                      onTapDown: (details) {
                        final size = context.size;
                        if (size == null) return;
                        final normalized = Offset(
                          details.localPosition.dx / size.width,
                          details.localPosition.dy / size.height,
                        );
                        final hitMuscle = _hitTest360(normalized, _currentAngle);
                        if (hitMuscle != null) {
                          _selectMuscle(hitMuscle);
                        }
                      },
                      child: CustomPaint(
                        painter: _Turntable360SkinHeatmapPainter(
                          angleDegrees: _currentAngle,
                          angleImages: _angleImages,
                          selectedMuscleId: _selectedMuscleId,
                          pulseValue: _pulseController.value,
                          recoveryGetter: _getRecovery,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Turntable Scrub & Drag Dial Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.chipBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.chipBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: context.accent),
                const SizedBox(width: 8),
                Text(
                  'DRAG TO ROTATE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: context.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: context.accent,
                      inactiveTrackColor: context.chipBorder,
                      thumbColor: context.accent,
                    ),
                    child: Slider(
                      value: _currentAngle,
                      min: 0.0,
                      max: 360.0,
                      onChanged: (val) {
                        setState(() => _currentAngle = val % 360.0);
                      },
                    ),
                  ),
                ),
                Text(
                  '${_currentAngle.round()}°',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Quick Muscle Selection Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: currentPillList.map((entry) {
                final id = entry.$1;
                final label = entry.$2;
                final isSelected = _selectedMuscleId == id;
                final data = _getRecovery(id);

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _selectMuscle(id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.accent.withValues(alpha: isDark ? 0.22 : 0.14)
                            : context.chipBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? context.accent : context.chipBorder,
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: data.color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? context.textPrimary : context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Detailed Muscle Recovery Card
          _buildMuscleRecoveryCard(activeData, context),
        ],
      ),
    );
  }

  Widget _buildAngleJumpPill(String label, double targetAngle) {
    // Check if current angle is near target
    double diff = (_currentAngle - targetAngle).abs();
    if (diff > 180.0) diff = 360.0 - diff;
    final isSelected = diff <= 25.0;

    return GestureDetector(
      onTap: () => _animateToAngle(targetAngle),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? context.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? context.onAccent : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String text, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 10, color: context.textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMuscleRecoveryCard(MuscleRecoveryData data, BuildContext context) {
    final pct = (data.recoveryPercent * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.chipBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.color.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.color,
                      boxShadow: [
                        BoxShadow(
                          color: data.color.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: data.color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '$pct% ${data.status}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: data.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Recovery Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: data.recoveryPercent.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: context.chipBorder,
              valueColor: AlwaysStoppedAnimation<Color>(data.color),
            ),
          ),
          const SizedBox(height: 10),

          // Details row
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: context.textTertiary),
              const SizedBox(width: 5),
              Text(
                data.hoursSinceLastTrained != null
                    ? '${data.hoursSinceLastTrained!.toStringAsFixed(1)} hours since last trained'
                    : 'No workouts in last 7 days',
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
              const Spacer(),
              Text(
                '${data.weeklySetsCount} sets / 7d',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Science Recovery Tip
          Text(
            data.tip,
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Determines which muscle was tapped at the given 360 degree angle
  String? _hitTest360(Offset p, double angle) {
    final normAngle = angle % 360.0;
    int nearestKey;
    bool isMirrored = false;

    if (normAngle <= 22.5 || normAngle > 337.5) {
      nearestKey = 0;
    } else if (normAngle <= 67.5) {
      nearestKey = 45;
    } else if (normAngle <= 112.5) {
      nearestKey = 90;
    } else if (normAngle <= 157.5) {
      nearestKey = 135;
    } else if (normAngle <= 202.5) {
      nearestKey = 180;
    } else if (normAngle <= 247.5) {
      nearestKey = 135;
      isMirrored = true;
    } else if (normAngle <= 292.5) {
      nearestKey = 90;
      isMirrored = true;
    } else {
      nearestKey = 45;
      isMirrored = true;
    }

    // Unmirror x so coordinates match canonical asset orientation (facing right)
    final x = isMirrored ? 1.0 - p.dx : p.dx;
    final y = p.dy;

    if (nearestKey == 90) {
      // LATERAL SIDE PROFILE (Facing right in canonical orientation)
      if (y >= 0.15 && y <= 0.22 && x >= 0.38 && x <= 0.54) return 'traps';
      if (y >= 0.20 && y <= 0.27 && x >= 0.40 && x <= 0.56) return 'shoulders';
      if (y >= 0.25 && y <= 0.32) {
        if (x > 0.51) return 'chest';
        if (x < 0.43) return 'back';
        return 'triceps';
      }
      if (y >= 0.28 && y <= 0.36) {
        if (x > 0.51) return 'core';
        if (x < 0.43) return 'back';
        return 'biceps';
      }
      if (y >= 0.36 && y <= 0.45) {
        if (x > 0.51) return 'core';
        if (x < 0.44) return 'lower_back';
        return 'forearms';
      }
      if (y >= 0.44 && y <= 0.53 && x < 0.49) return 'glutes';
      if (y >= 0.52 && y <= 0.70 && x >= 0.41 && x <= 0.59) return 'legs';
      if (y >= 0.70 && y <= 0.88 && x >= 0.40 && x <= 0.56) return 'calves';
      return null;
    }

    if (nearestKey == 180 || nearestKey == 135) {
      // BACK & 3/4 BACK
      if (y >= 0.14 && y <= 0.26 && (x >= 0.38 && x <= 0.62)) return 'traps';
      if (y >= 0.17 && y <= 0.28 && ((x >= 0.25 && x <= 0.38) || (x >= 0.62 && x <= 0.75))) return 'shoulders';
      if (y >= 0.24 && y <= 0.40 && (x >= 0.33 && x <= 0.67)) return 'back';
      if (y >= 0.23 && y <= 0.37 && ((x >= 0.22 && x <= 0.35) || (x >= 0.65 && x <= 0.78))) return 'triceps';
      if (y >= 0.34 && y <= 0.44 && (x >= 0.40 && x <= 0.60)) return 'lower_back';
      if (y >= 0.42 && y <= 0.55 && (x >= 0.35 && x <= 0.65)) return 'glutes';
      if (y >= 0.54 && y <= 0.72 && (x >= 0.34 && x <= 0.66)) return 'legs';
      if (y >= 0.71 && y <= 0.90 && (x >= 0.34 && x <= 0.66)) return 'calves';
      return null;
    }

    // FRONT (0) & 3/4 FRONT (45)
    if (y >= 0.17 && y <= 0.29 && ((x >= 0.25 && x <= 0.38) || (x >= 0.62 && x <= 0.75))) return 'shoulders';
    if (y >= 0.19 && y <= 0.31 && (x >= 0.36 && x <= 0.64)) return 'chest';
    if (y >= 0.25 && y <= 0.38 && ((x >= 0.22 && x <= 0.35) || (x >= 0.65 && x <= 0.78))) return 'biceps';
    if (y >= 0.37 && y <= 0.53 && ((x >= 0.18 && x <= 0.32) || (x >= 0.68 && x <= 0.82))) return 'forearms';
    if (y >= 0.29 && y <= 0.46 && (x >= 0.37 && x <= 0.63)) return 'core';
    if (y >= 0.46 && y <= 0.68 && (x >= 0.33 && x <= 0.67)) return 'legs';
    if (y >= 0.68 && y <= 0.90 && (x >= 0.33 && x <= 0.67)) return 'calves';
    return null;
  }
}

/// Painter that renders the 360-degree turntable character and on-skin thermal heat.
class _Turntable360SkinHeatmapPainter extends CustomPainter {
  final double angleDegrees;
  final Map<int, ui.Image> angleImages;
  final String selectedMuscleId;
  final double pulseValue;
  final MuscleRecoveryData Function(String) recoveryGetter;

  _Turntable360SkinHeatmapPainter({
    required this.angleDegrees,
    required this.angleImages,
    required this.selectedMuscleId,
    required this.pulseValue,
    required this.recoveryGetter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Determine nearest turntable angle and whether it needs horizontal mirroring
    // Angles: 0, 45, 90, 135, 180, 225, 270, 315
    final normAngle = angleDegrees % 360.0;
    int nearestKey;
    bool isMirrored = false;

    if (normAngle <= 22.5 || normAngle > 337.5) {
      nearestKey = 0;
    } else if (normAngle <= 67.5) {
      nearestKey = 45;
    } else if (normAngle <= 112.5) {
      nearestKey = 90;
    } else if (normAngle <= 157.5) {
      nearestKey = 135;
    } else if (normAngle <= 202.5) {
      nearestKey = 180;
    } else if (normAngle <= 247.5) {
      nearestKey = 135;
      isMirrored = true;
    } else if (normAngle <= 292.5) {
      nearestKey = 90;
      isMirrored = true;
    } else {
      nearestKey = 45;
      isMirrored = true;
    }

    final image = angleImages[nearestKey];
    if (image == null) return;

    // 1. Isolate in canvas layer
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());

    // If mirrored (left-facing rotation), flip horizontally around center
    if (isMirrored) {
      canvas.save();
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }

    // 2. Draw 3D body frame
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, w, h),
      Paint(),
    );

    // 3. Paint on-skin thermal recovery heat according to angle sector
    if (nearestKey == 0 || nearestKey == 45) {
      _paintFrontThermalHeat(canvas, w, h, isQuarter: nearestKey == 45);
    } else if (nearestKey == 90) {
      _paintSideThermalHeat(canvas, w, h);
    } else {
      _paintBackThermalHeat(canvas, w, h, isQuarter: nearestKey == 135);
    }

    if (isMirrored) {
      canvas.restore();
    }

    // 4. Restore canvas layer
    canvas.restore();

    // 5. Draw selected muscle pulsing indicator
    _paintSelectedIndicators(canvas, w, h, nearestKey, isMirrored);
  }

  void _paintFrontThermalHeat(Canvas canvas, double w, double h, {required bool isQuarter}) {
    final shift = isQuarter ? w * 0.03 : 0.0;

    // Chest
    final chestColor = recoveryGetter('chest').color;
    _drawSkinMuscle(canvas, Offset(w * 0.43 + shift, h * 0.25), w * 0.075, h * 0.055, chestColor, 'chest');
    _drawSkinMuscle(canvas, Offset(w * 0.57 + shift, h * 0.25), w * 0.075, h * 0.055, chestColor, 'chest');

    // Shoulders
    final deltColor = recoveryGetter('shoulders').color;
    _drawSkinMuscle(canvas, Offset(w * 0.32 + shift, h * 0.23), w * 0.065, h * 0.060, deltColor, 'shoulders');
    _drawSkinMuscle(canvas, Offset(w * 0.68 + shift, h * 0.23), w * 0.065, h * 0.060, deltColor, 'shoulders');

    // Biceps
    final bicepColor = recoveryGetter('biceps').color;
    _drawSkinMuscle(canvas, Offset(w * 0.28 + shift, h * 0.32), w * 0.045, h * 0.055, bicepColor, 'biceps');
    _drawSkinMuscle(canvas, Offset(w * 0.72 + shift, h * 0.32), w * 0.045, h * 0.055, bicepColor, 'biceps');

    // Forearms
    final forearmColor = recoveryGetter('forearms').color;
    _drawSkinMuscle(canvas, Offset(w * 0.25 + shift, h * 0.44), w * 0.045, h * 0.070, forearmColor, 'forearms');
    _drawSkinMuscle(canvas, Offset(w * 0.75 + shift, h * 0.44), w * 0.045, h * 0.070, forearmColor, 'forearms');

    // Core
    final coreColor = recoveryGetter('core').color;
    _drawSkinMuscle(canvas, Offset(w * 0.50 + shift, h * 0.34), w * 0.065, h * 0.035, coreColor, 'core');
    _drawSkinMuscle(canvas, Offset(w * 0.50 + shift, h * 0.39), w * 0.075, h * 0.040, coreColor, 'core');
    _drawSkinMuscle(canvas, Offset(w * 0.50 + shift, h * 0.44), w * 0.065, h * 0.035, coreColor, 'core');

    // Quads
    final quadColor = recoveryGetter('legs').color;
    _drawSkinMuscle(canvas, Offset(w * 0.42 + shift, h * 0.56), w * 0.075, h * 0.095, quadColor, 'legs');
    _drawSkinMuscle(canvas, Offset(w * 0.58 + shift, h * 0.56), w * 0.075, h * 0.095, quadColor, 'legs');

    // Calves
    final calfColor = recoveryGetter('calves').color;
    _drawSkinMuscle(canvas, Offset(w * 0.40 + shift, h * 0.79), w * 0.055, h * 0.085, calfColor, 'calves');
    _drawSkinMuscle(canvas, Offset(w * 0.60 + shift, h * 0.79), w * 0.055, h * 0.085, calfColor, 'calves');
  }

  void _paintSideThermalHeat(Canvas canvas, double w, double h) {
    // Deltoids
    final deltColor = recoveryGetter('shoulders').color;
    _drawSkinMuscle(canvas, Offset(w * 0.48, h * 0.24), w * 0.065, h * 0.055, deltColor, 'shoulders');

    // Traps Profile
    final trapsColor = recoveryGetter('traps').color;
    _drawSkinMuscle(canvas, Offset(w * 0.46, h * 0.19), w * 0.050, h * 0.040, trapsColor, 'traps');

    // Chest Profile
    final chestColor = recoveryGetter('chest').color;
    _drawSkinMuscle(canvas, Offset(w * 0.55, h * 0.27), w * 0.045, h * 0.045, chestColor, 'chest');

    // Lats / Upper Back Profile
    final backColor = recoveryGetter('back').color;
    _drawSkinMuscle(canvas, Offset(w * 0.43, h * 0.32), w * 0.048, h * 0.058, backColor, 'back');

    // Triceps (Posterior Upper Arm)
    final tricepColor = recoveryGetter('triceps').color;
    _drawSkinMuscle(canvas, Offset(w * 0.44, h * 0.30), w * 0.035, h * 0.050, tricepColor, 'triceps');

    // Biceps (Anterior Upper Arm)
    final bicepColor = recoveryGetter('biceps').color;
    _drawSkinMuscle(canvas, Offset(w * 0.48, h * 0.31), w * 0.035, h * 0.050, bicepColor, 'biceps');

    // Forearm Profile
    final forearmColor = recoveryGetter('forearms').color;
    _drawSkinMuscle(canvas, Offset(w * 0.48, h * 0.43), w * 0.038, h * 0.060, forearmColor, 'forearms');

    // Core / Abs Profile
    final coreColor = recoveryGetter('core').color;
    _drawSkinMuscle(canvas, Offset(w * 0.54, h * 0.38), w * 0.045, h * 0.055, coreColor, 'core');

    // Lower Back Profile
    final lbColor = recoveryGetter('lower_back').color;
    _drawSkinMuscle(canvas, Offset(w * 0.44, h * 0.41), w * 0.040, h * 0.045, lbColor, 'lower_back');

    // Glutes Profile
    final gluteColor = recoveryGetter('glutes').color;
    _drawSkinMuscle(canvas, Offset(w * 0.46, h * 0.49), w * 0.060, h * 0.060, gluteColor, 'glutes');

    // Quad / Hamstring Lateral
    final legColor = recoveryGetter('legs').color;
    _drawSkinMuscle(canvas, Offset(w * 0.50, h * 0.60), w * 0.065, h * 0.090, legColor, 'legs');

    // Calf Profile
    final calfColor = recoveryGetter('calves').color;
    _drawSkinMuscle(canvas, Offset(w * 0.475, h * 0.78), w * 0.048, h * 0.075, calfColor, 'calves');
  }

  void _paintBackThermalHeat(Canvas canvas, double w, double h, {required bool isQuarter}) {
    final shift = isQuarter ? -w * 0.03 : 0.0;

    // Traps
    final trapsColor = recoveryGetter('traps').color;
    _drawSkinMuscle(canvas, Offset(w * 0.50 + shift, h * 0.19), w * 0.090, h * 0.050, trapsColor, 'traps');
    _drawSkinMuscle(canvas, Offset(w * 0.50 + shift, h * 0.25), w * 0.070, h * 0.040, trapsColor, 'traps');

    // Rear Delts
    final deltColor = recoveryGetter('shoulders').color;
    _drawSkinMuscle(canvas, Offset(w * 0.32 + shift, h * 0.22), w * 0.060, h * 0.050, deltColor, 'shoulders');
    _drawSkinMuscle(canvas, Offset(w * 0.68 + shift, h * 0.22), w * 0.060, h * 0.050, deltColor, 'shoulders');

    // Triceps
    final tricepColor = recoveryGetter('triceps').color;
    _drawSkinMuscle(canvas, Offset(w * 0.28 + shift, h * 0.29), w * 0.050, h * 0.060, tricepColor, 'triceps');
    _drawSkinMuscle(canvas, Offset(w * 0.72 + shift, h * 0.29), w * 0.050, h * 0.060, tricepColor, 'triceps');

    // Lats
    final latsColor = recoveryGetter('back').color;
    _drawSkinMuscle(canvas, Offset(w * 0.41 + shift, h * 0.32), w * 0.070, h * 0.065, latsColor, 'back');
    _drawSkinMuscle(canvas, Offset(w * 0.59 + shift, h * 0.32), w * 0.070, h * 0.065, latsColor, 'back');

    // Lower Back
    final lbColor = recoveryGetter('lower_back').color;
    _drawSkinMuscle(canvas, Offset(w * 0.50 + shift, h * 0.39), w * 0.065, h * 0.045, lbColor, 'lower_back');

    // Glutes
    final gluteColor = recoveryGetter('glutes').color;
    _drawSkinMuscle(canvas, Offset(w * 0.43 + shift, h * 0.48), w * 0.075, h * 0.055, gluteColor, 'glutes');
    _drawSkinMuscle(canvas, Offset(w * 0.57 + shift, h * 0.48), w * 0.075, h * 0.055, gluteColor, 'glutes');

    // Hamstrings
    final hamsColor = recoveryGetter('legs').color;
    _drawSkinMuscle(canvas, Offset(w * 0.42 + shift, h * 0.63), w * 0.065, h * 0.085, hamsColor, 'legs');
    _drawSkinMuscle(canvas, Offset(w * 0.58 + shift, h * 0.63), w * 0.065, h * 0.085, hamsColor, 'legs');

    // Calves
    final calfColor = recoveryGetter('calves').color;
    _drawSkinMuscle(canvas, Offset(w * 0.40 + shift, h * 0.80), w * 0.055, h * 0.085, calfColor, 'calves');
    _drawSkinMuscle(canvas, Offset(w * 0.60 + shift, h * 0.80), w * 0.055, h * 0.085, calfColor, 'calves');
  }

  void _drawSkinMuscle(
    Canvas canvas,
    Offset center,
    double radiusX,
    double radiusY,
    Color color,
    String muscleId,
  ) {
    final isSelected = selectedMuscleId == muscleId;

    final colorTintPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isSelected ? 0.72 : 0.50),
          color.withValues(alpha: isSelected ? 0.35 : 0.22),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.75, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: radiusX * 2.1, height: radiusY * 2.1))
      ..blendMode = BlendMode.srcATop;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2.0, height: radiusY * 2.0),
      colorTintPaint,
    );

    final radiancePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isSelected ? 0.42 : 0.22),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: radiusX * 1.8, height: radiusY * 1.8))
      ..blendMode = BlendMode.hardLight;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 1.8, height: radiusY * 1.8),
      radiancePaint,
    );
  }

  void _paintSelectedIndicators(Canvas canvas, double w, double h, int nearestKey, bool isMirrored) {
    final data = recoveryGetter(selectedMuscleId);
    final color = data.color;
    final List<Offset> targets = [];
    double rx = w * 0.07;
    double ry = h * 0.06;

    if (nearestKey == 90) {
      // LATERAL SIDE PROFILE (angle 90° or mirrored 270°)
      // Single accurately centered indicators aligned to lateral muscle profiles
      switch (selectedMuscleId) {
        case 'shoulders':
          targets.add(Offset(w * 0.48, h * 0.24));
          rx = w * 0.065;
          ry = h * 0.055;
          break;
        case 'chest':
          targets.add(Offset(w * 0.55, h * 0.27));
          rx = w * 0.045;
          ry = h * 0.045;
          break;
        case 'back':
          targets.add(Offset(w * 0.43, h * 0.32));
          rx = w * 0.048;
          ry = h * 0.058;
          break;
        case 'biceps':
          targets.add(Offset(w * 0.48, h * 0.31));
          rx = w * 0.035;
          ry = h * 0.050;
          break;
        case 'triceps':
          targets.add(Offset(w * 0.44, h * 0.30));
          rx = w * 0.035;
          ry = h * 0.050;
          break;
        case 'forearms':
          targets.add(Offset(w * 0.48, h * 0.43));
          rx = w * 0.038;
          ry = h * 0.060;
          break;
        case 'core':
          targets.add(Offset(w * 0.54, h * 0.38));
          rx = w * 0.045;
          ry = h * 0.055;
          break;
        case 'lower_back':
          targets.add(Offset(w * 0.44, h * 0.41));
          rx = w * 0.040;
          ry = h * 0.045;
          break;
        case 'glutes':
          targets.add(Offset(w * 0.46, h * 0.49));
          rx = w * 0.060;
          ry = h * 0.060;
          break;
        case 'traps':
          targets.add(Offset(w * 0.46, h * 0.19));
          rx = w * 0.050;
          ry = h * 0.040;
          break;
        case 'legs':
          targets.add(Offset(w * 0.50, h * 0.60));
          rx = w * 0.065;
          ry = h * 0.090;
          break;
        case 'calves':
          targets.add(Offset(w * 0.475, h * 0.78));
          rx = w * 0.048;
          ry = h * 0.075;
          break;
      }
    } else if (nearestKey == 180 || nearestKey == 135) {
      final shift = nearestKey == 135 ? -w * 0.025 : 0.0;
      switch (selectedMuscleId) {
        case 'traps':
          targets.add(Offset(w * 0.50 + shift, h * 0.21));
          rx = w * 0.085;
          ry = h * 0.055;
          break;
        case 'shoulders':
          targets.addAll([Offset(w * 0.32 + shift, h * 0.22), Offset(w * 0.68 + shift, h * 0.22)]);
          rx = w * 0.060;
          ry = h * 0.050;
          break;
        case 'triceps':
          targets.addAll([Offset(w * 0.28 + shift, h * 0.29), Offset(w * 0.72 + shift, h * 0.29)]);
          rx = w * 0.050;
          ry = h * 0.060;
          break;
        case 'back':
          targets.addAll([Offset(w * 0.41 + shift, h * 0.32), Offset(w * 0.59 + shift, h * 0.32)]);
          rx = w * 0.070;
          ry = h * 0.065;
          break;
        case 'lower_back':
          targets.add(Offset(w * 0.50 + shift, h * 0.39));
          rx = w * 0.065;
          ry = h * 0.045;
          break;
        case 'glutes':
          targets.addAll([Offset(w * 0.43 + shift, h * 0.48), Offset(w * 0.57 + shift, h * 0.48)]);
          rx = w * 0.075;
          ry = h * 0.055;
          break;
        case 'legs':
          targets.addAll([Offset(w * 0.42 + shift, h * 0.63), Offset(w * 0.58 + shift, h * 0.63)]);
          rx = w * 0.065;
          ry = h * 0.085;
          break;
        case 'calves':
          targets.addAll([Offset(w * 0.40 + shift, h * 0.80), Offset(w * 0.60 + shift, h * 0.80)]);
          rx = w * 0.055;
          ry = h * 0.085;
          break;
      }
    } else {
      final shift = nearestKey == 45 ? w * 0.025 : 0.0;
      switch (selectedMuscleId) {
        case 'chest':
          targets.addAll([Offset(w * 0.43 + shift, h * 0.25), Offset(w * 0.57 + shift, h * 0.25)]);
          rx = w * 0.075;
          ry = h * 0.055;
          break;
        case 'shoulders':
          targets.addAll([Offset(w * 0.32 + shift, h * 0.23), Offset(w * 0.68 + shift, h * 0.23)]);
          rx = w * 0.065;
          ry = h * 0.060;
          break;
        case 'biceps':
          targets.addAll([Offset(w * 0.28 + shift, h * 0.32), Offset(w * 0.72 + shift, h * 0.32)]);
          rx = w * 0.045;
          ry = h * 0.055;
          break;
        case 'forearms':
          targets.addAll([Offset(w * 0.25 + shift, h * 0.44), Offset(w * 0.75 + shift, h * 0.44)]);
          rx = w * 0.045;
          ry = h * 0.070;
          break;
        case 'core':
          targets.add(Offset(w * 0.50 + shift, h * 0.38));
          rx = w * 0.080;
          ry = h * 0.060;
          break;
        case 'legs':
          targets.addAll([Offset(w * 0.42 + shift, h * 0.56), Offset(w * 0.58 + shift, h * 0.56)]);
          rx = w * 0.075;
          ry = h * 0.095;
          break;
        case 'calves':
          targets.addAll([Offset(w * 0.40 + shift, h * 0.79), Offset(w * 0.60 + shift, h * 0.79)]);
          rx = w * 0.055;
          ry = h * 0.085;
          break;
      }
    }

    for (final rawTarget in targets) {
      final target = isMirrored ? Offset(w - rawTarget.dx, rawTarget.dy) : rawTarget;
      final pulseRadiusX = rx * (1.05 + 0.12 * pulseValue);
      final pulseRadiusY = ry * (1.05 + 0.12 * pulseValue);

      final ringPaint = Paint()
        ..color = color.withValues(alpha: 0.90 - 0.40 * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawOval(
        Rect.fromCenter(center: target, width: pulseRadiusX * 2.0, height: pulseRadiusY * 2.0),
        ringPaint,
      );

      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(target, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Turntable360SkinHeatmapPainter oldDelegate) {
    return oldDelegate.angleDegrees != angleDegrees ||
        oldDelegate.selectedMuscleId != selectedMuscleId ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.angleImages != angleImages;
  }
}
