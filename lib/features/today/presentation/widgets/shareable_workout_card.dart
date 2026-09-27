import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../domain/models/workout_model.dart';
import '../../../../domain/models/workout_debrief_model.dart';

/// Captures a [RepaintBoundary] widget referenced by [key] as a 3x resolution PNG
/// and invokes native system sharing via `share_plus`.
Future<bool> captureAndShareWorkoutCard(
  GlobalKey key,
  BuildContext context, {
  String? workoutTitle,
}) async {
  try {
    AppHaptics.step();
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return false;

    // Render image with 3.0 pixel ratio for high-res social sharing
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return false;

    final pngBytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/ironlog_workout_$timestamp.png');
    await file.writeAsBytes(pngBytes);

    AppHaptics.success();
    final shareTitle = workoutTitle != null ? 'Workout: $workoutTitle' : 'Crushed my workout!';
    final result = await Share.shareXFiles(
      [XFile(file.path)],
      text: '$shareTitle • Logged with IronLog 💪',
    );
    return result.status == ShareResultStatus.success;
  } catch (e) {
    debugPrint('Error sharing workout card: $e');
    return false;
  }
}

/// A high-resolution, 9:16 story-ready Titanium Slate glassmorphic workout card.
class ShareableWorkoutCard extends StatelessWidget {
  final WorkoutModel workout;
  final WorkoutDebriefData debrief;
  final WeightUnit unit;

  const ShareableWorkoutCard({
    super.key,
    required this.workout,
    required this.debrief,
    required this.unit,
  });

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = workout.totalSetsCount;
    final volume = workout.totalVolume;
    final exercises = workout.exercises.where((e) => !e.archived).toList();

    return Container(
      width: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141922),
            Color(0xFF0C0E14),
            Color(0xFF08090D),
          ],
        ),
        border: Border.all(color: const Color(0xFF2E3846), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background subtle radial glow
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.accent.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF64748B).withValues(alpha: 0.12),
                ),
              ),
            ),

            // Card content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header & Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: context.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.accent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(Icons.fitness_center_rounded, color: context.accent, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'IRONLOG',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2530),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF333E50)),
                        ),
                        child: Text(
                          AppDateUtils.formatShortDate(workout.date).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Workout Title
                  Text(
                    workout.title,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Big Highlight Stats Grid
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151B24).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF263140)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(
                          label: 'VOLUME',
                          val: UnitConverter.formatWeight(volume, unit: unit),
                          color: context.accent,
                        ),
                        Container(width: 1, height: 32, color: const Color(0xFF263140)),
                        _buildStat(
                          label: 'SETS',
                          val: '$totalSets',
                          color: Colors.white,
                        ),
                        Container(width: 1, height: 32, color: const Color(0xFF263140)),
                        _buildStat(
                          label: 'DURATION',
                          val: _formatDuration(debrief.duration),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Broken PRs Trophy Banner (if any)
                  if (debrief.brokenPrs.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFD97706).withValues(alpha: 0.22),
                            const Color(0xFFB45309).withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  debrief.brokenPrs.length == 1
                                      ? 'NEW PERSONAL RECORD!'
                                      : '${debrief.brokenPrs.length} NEW PERSONAL RECORDS!',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: Color(0xFFFDE68A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                ...debrief.brokenPrs.take(2).map((pr) {
                                  return Text(
                                    '${pr.exerciseName}: ${UnitConverter.formatWeight(pr.value, unit: unit)} (${pr.formattedKind})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Top Lift Highlights
                  const Text(
                    'EXERCISE HIGHLIGHTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...exercises.take(3).map((ex) {
                    final working = ex.sets.where((s) => !s.archived && !s.isWarmup).toList();
                    final topWeight = ex.maxWeight;
                    final bestSet = working.isNotEmpty
                        ? working.firstWhere(
                            (s) => s.weight == topWeight,
                            orElse: () => working.first,
                          )
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ex.exercise.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFCBD5E1),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (bestSet != null)
                            Text(
                              '${bestSet.weight.toStringAsFixed(bestSet.weight.truncateToDouble() == bestSet.weight ? 0 : 1)} ${unit.label} × ${bestSet.reps}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  // AI Debrief Quote Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131822),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF263140)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: context.accent, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'AI COACH INSIGHT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: context.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          debrief.volumeInsight,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Footer Watermark
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: context.accent),
                      const SizedBox(width: 4),
                      const Text(
                        'ATHLETIC INTELLIGENCE • IRONLOG',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat({
    required String label,
    required String val,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Modal dialog showing the shareable story preview and export action.
class ShareWorkoutModalDialog extends StatefulWidget {
  final WorkoutModel workout;
  final WorkoutDebriefData debrief;
  final WeightUnit unit;

  const ShareWorkoutModalDialog({
    super.key,
    required this.workout,
    required this.debrief,
    required this.unit,
  });

  static Future<void> show(
    BuildContext context, {
    required WorkoutModel workout,
    required WorkoutDebriefData debrief,
    required WeightUnit unit,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => ShareWorkoutModalDialog(
        workout: workout,
        debrief: debrief,
        unit: unit,
      ),
    );
  }

  @override
  State<ShareWorkoutModalDialog> createState() => _ShareWorkoutModalDialogState();
}

class _ShareWorkoutModalDialogState extends State<ShareWorkoutModalDialog> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _handleShare() async {
    setState(() => _isSharing = true);
    final ok = await captureAndShareWorkoutCard(
      _cardBoundaryKey,
      context,
      workoutTitle: widget.workout.title,
    );
    if (mounted) {
      setState(() => _isSharing = false);
      if (ok) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // RepaintBoundary containing the shareable card
          RepaintBoundary(
            key: _cardBoundaryKey,
            child: ShareableWorkoutCard(
              workout: widget.workout,
              debrief: widget.debrief,
              unit: widget.unit,
            ),
          ),
          const SizedBox(height: 16),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: GlassButton(
                  text: _isSharing ? 'Generating...' : 'Share Story',
                  icon: _isSharing ? Icons.hourglass_top_rounded : Icons.share_rounded,
                  style: GlassButtonStyle.primary,
                  onPressed: _isSharing ? null : _handleShare,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2530),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
