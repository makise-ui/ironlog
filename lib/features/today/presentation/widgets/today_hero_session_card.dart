import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/scale_tap.dart';
import 'anatomical_routine_visual.dart';

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

  @override
  Widget build(BuildContext context) {
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
        child: Stack(
          children: [
            // 1. Biomechanical anatomical muscle heatmap visual on the right
            if (!isRestDay)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 175,
                child: AnatomicalRoutineVisual(
                  routineName: title,
                  width: 175,
                  compact: false,
                ),
              ),

            // 2. Foreground content
            Padding(
              padding: const EdgeInsets.all(S.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header tag row
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

          // Title & target muscle subtitle
          Text(
            title,
            style: T.title.copyWith(fontSize: 22),
          ),
          const SizedBox(height: S.xs),
          Text(
            subtitle,
            style: T.body.copyWith(color: C.text2),
          ),
          const SizedBox(height: S.xl),

          // Meta statistics row
          Row(
            children: [
              _buildMetaItem(
                Icons.fitness_center_rounded,
                '$exerciseCount ${exerciseCount == 1 ? "exercise" : "exercises"}',
              ),
              const SizedBox(width: S.xl),
              _buildMetaItem(
                Icons.schedule_rounded,
                isActive && elapsedText != null ? elapsedText! : '~$estimatedMinutes min',
              ),
            ],
          ),
          const SizedBox(height: S.xl),

          // THE ONE HERO CTA
          ScaleTap(
            onPressed: onStartWorkout,
            child: Container(
              width: double.infinity,
              height: 54,
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
                          fontSize: 16,
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
  ],
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
        Icon(icon, size: 16, color: C.text2),
        const SizedBox(width: 6),
        Text(
          text,
          style: T.body.copyWith(
            fontSize: 13,
            color: C.text1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
