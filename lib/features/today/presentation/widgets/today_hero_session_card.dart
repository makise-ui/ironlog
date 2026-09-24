import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/scale_tap.dart';

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

  String _resolveHeroAsset() {
    final lower = title.toLowerCase();
    if (lower.contains('push') || lower.contains('chest')) {
      return 'assets/images/push_preset.jpg';
    } else if (lower.contains('pull') || lower.contains('back')) {
      return 'assets/images/pull_preset.jpg';
    } else if (lower.contains('leg') || lower.contains('squat') || lower.contains('lower')) {
      return 'assets/images/legs_preset.jpg';
    }
    return 'assets/images/hero_workout.jpg';
  }

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
            // 1. Partial athletic photograph on the right fading cleanly into canvas
            if (!isRestDay)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 210,
                child: IgnorePointer(
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.white.withValues(alpha: context.isDark ? 0.90 : 0.80),
                          Colors.white.withValues(alpha: context.isDark ? 0.45 : 0.30),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Opacity(
                      opacity: context.isDark ? 0.92 : 0.80,
                      child: Image.asset(
                        _resolveHeroAsset(),
                        fit: BoxFit.cover,
                        alignment: const Alignment(0.2, 0.0),
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),

            // 2. Subtle ambient accent glow behind the visual
            if (!isRestDay)
              Positioned(
                top: -20,
                right: -20,
                child: IgnorePointer(
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          C.accent.withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Foreground content
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
                  Text(
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
