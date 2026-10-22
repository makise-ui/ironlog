import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/scale_tap.dart';
import 'workout_telemetry_dial.dart';

class TodayHeroSessionCard extends StatelessWidget {
  const TodayHeroSessionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.exerciseCount = 0,
    this.estimatedMinutes = 0,
    this.isActive = false,
    this.isPaused = false,
    this.isRestDay = false,
    this.isFinished = false,
    this.elapsedText,
    required this.onStartWorkout,
    this.onExplainAI,
    this.onDiscardWorkout,
  });

  final String title;
  final String subtitle;
  final int exerciseCount;
  final int estimatedMinutes;
  final bool isActive;
  final bool isPaused;
  final bool isRestDay;
  final bool isFinished;
  final String? elapsedText;
  final VoidCallback onStartWorkout;
  final VoidCallback? onExplainAI;
  final VoidCallback? onDiscardWorkout;

  /// Extracts target muscle group tags for clean visual telemetry chips
  List<String> _extractMuscleTags(String text) {
    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(text);
    if (parenMatch != null) {
      final inside = parenMatch.group(1)!;
      final parts = inside
          .split(RegExp(r'[•·,]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts;
    }
    final lower = text.toLowerCase();
    if (lower.contains('push')) return ['Chest', 'Shoulders', 'Triceps'];
    if (lower.contains('pull')) return ['Back', 'Biceps', 'Lats'];
    if (lower.contains('leg') || lower.contains('squat') || lower.contains('lower')) {
      return ['Quads', 'Hamstrings', 'Calves'];
    }
    if (lower.contains('upper')) return ['Chest', 'Back', 'Arms'];
    if (lower.contains('arm')) return ['Biceps', 'Triceps'];
    if (lower.contains('core') || lower.contains('ab')) return ['Core', 'Abs'];
    return ['Full Body'];
  }

  /// Removes bracketed parenthetical text from display title to keep typography bold & clean
  String _cleanDisplayTitle(String raw) {
    return raw.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  /// Calculates an authentic workload/volume score (0.65 to 0.95) based on workout volume
  double _calculateLoadScore() {
    if (exerciseCount == 0 && estimatedMinutes == 0) return 0.82;
    final score = ((exerciseCount * 8.0) + (estimatedMinutes * 0.90)) / 100.0;
    return score.clamp(0.65, 0.95);
  }

  @override
  Widget build(BuildContext context) {
    final targetMuscles = _extractMuscleTags(title);
    final loadScore = _calculateLoadScore();

    return ScaleTap(
      onPressed: onStartWorkout,
      child: Container(
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(R.card),
          border: Border.all(color: C.hairline),
          boxShadow: context.isDark
              ? null
              : [
                  const BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(S.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header tag row: Status badge + AI Coach button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusTag(),
                  if (onExplainAI != null && !isActive && !isRestDay)
                    ScaleTap(
                      onPressed: onExplainAI,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: C.surfaceHi,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: C.hairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 13, color: C.accent),
                            const SizedBox(width: 4),
                            Text(
                              'AI COACH',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: C.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: S.lg),

              // 2. Cockpit Zone: Left 65% Typography & Badges | Right 35% Biometric Load Dial
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Clean Title, Target Muscle Badges & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cleanDisplayTitle(title),
                          style: T.title.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Muscle Target Telemetry Badges
                        if (!isRestDay && targetMuscles.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: targetMuscles.map((m) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: C.accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: C.accent.withValues(alpha: 0.22),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 4.5,
                                      height: 4.5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: C.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 4.5),
                                    Text(
                                      m,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],

                        Text(
                          subtitle,
                          style: T.body.copyWith(
                            color: C.text2,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Right Column: Dedicated Biometric Telemetry Dial
                  if (!isRestDay) ...[
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: WorkoutTelemetryDial(
                        progress: isFinished ? 1.0 : loadScore,
                        valueText: isFinished ? '100%' : '${(loadScore * 100).toInt()}%',
                        label: isFinished
                            ? 'COMPLETE'
                            : (isActive ? 'IN SESSION' : 'TARGET LOAD'),
                        size: 82.0,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: S.lg),

              // 3. Meta statistics capsule (Exercises & Duration)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: C.surfaceHi,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMetaItem(
                      Icons.fitness_center_rounded,
                      '$exerciseCount ${exerciseCount == 1 ? "exercise" : "exercises"}',
                    ),
                    Container(
                      height: 12,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: C.hairline,
                    ),
                    _buildMetaItem(
                      Icons.schedule_rounded,
                      isActive && elapsedText != null ? elapsedText! : '~$estimatedMinutes min',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: S.lg),

              // 4. Hero CTA Button
              ScaleTap(
                onPressed: onStartWorkout,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: C.accent,
                    borderRadius: BorderRadius.circular(R.button),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isFinished
                            ? Icons.replay_rounded
                            : (isActive ? Icons.play_arrow_rounded : Icons.bolt_rounded),
                        color: C.onAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isFinished
                                ? 'Reopen Workout Session'
                                : (isActive
                                    ? (isPaused ? 'Resume Workout' : 'Continue Workout')
                                    : (isRestDay ? 'Log Workout Anyway' : 'Start Workout')),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: C.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Subtle secondary action if active/paused
              if (isActive && !isFinished && onDiscardWorkout != null) ...[
                const SizedBox(height: S.md),
                Center(
                  child: ScaleTap(
                    onPressed: onDiscardWorkout,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      child: Text(
                        'Discard Active Session',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: C.text2,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildStatusTag() {
    String label = "TODAY'S SESSION";
    Color dotColor = C.accent;

    if (isFinished) {
      label = 'COMPLETED TODAY';
      dotColor = C.positive;
    } else if (isActive) {
      if (isPaused) {
        label = 'WORKOUT PAUSED';
        dotColor = Colors.orangeAccent;
      } else {
        label = 'IN PROGRESS';
        dotColor = C.positive;
      }
    } else if (isRestDay) {
      label = 'REST & RECOVERY';
      dotColor = Colors.lightBlueAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: C.surfaceHi,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: T.label.copyWith(fontSize: 10, color: C.text2),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: C.text2),
        const SizedBox(width: 5),
        Text(
          text,
          style: T.body.copyWith(
            fontSize: 12.5,
            color: C.text1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
