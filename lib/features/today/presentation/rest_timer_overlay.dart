import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bouncy_pressable.dart';
import '../../../data/providers.dart';

class RestTimerOverlay extends ConsumerWidget {
  const RestTimerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerService = ref.watch(restTimerProvider);
    final state = timerService.state;

    if (!state.isActive) {
      return const SizedBox.shrink();
    }

    final rem = state.remainingSeconds;
    final mins = rem ~/ 60;
    final secs = rem % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xF5141620) : Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(
                  color: isDark ? const Color(0xFF262B3B) : const Color(0xFFE2E4EE),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Circular Progress Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          value: state.progress,
                          strokeWidth: 3.5,
                          backgroundColor: isDark ? const Color(0xFF1E212D) : const Color(0xFFE2E4EE),
                          valueColor: AlwaysStoppedAnimation<Color>(context.accent),
                        ),
                      ),
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: context.accent,
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Timer text and exercise name
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                            letterSpacing: -0.3,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          state.exerciseName.isNotEmpty ? state.exerciseName : 'Rest Timer',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Controls: -30s, +30s, Pause/Play, Skip
                  _buildAdjustmentPill(
                    label: '-30s',
                    context: context,
                    onTap: () {
                      AppHaptics.step();
                      timerService.addSeconds(-30);
                    },
                  ),
                  const SizedBox(width: 5),
                  _buildAdjustmentPill(
                    label: '+30s',
                    context: context,
                    onTap: () {
                      AppHaptics.step();
                      timerService.addSeconds(30);
                    },
                  ),
                  const SizedBox(width: 6),
                  BouncyPressable(
                    onTap: () {
                      AppHaptics.tap();
                      if (state.isPaused) {
                        timerService.resume();
                      } else {
                        timerService.pause();
                      }
                    },
                    scaleDown: 0.88,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.chipBg,
                        border: Border.all(color: context.chipBorder),
                      ),
                      child: Center(
                        child: Icon(
                          state.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: context.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  BouncyPressable(
                    onTap: () {
                      AppHaptics.tap();
                      timerService.stop();
                    },
                    scaleDown: 0.88,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.chipBg,
                        border: Border.all(color: context.chipBorder),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: context.textTertiary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustmentPill({required String label, required BuildContext context, required VoidCallback onTap}) {
    return BouncyPressable(
      onTap: onTap,
      scaleDown: 0.90,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: context.chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.chipBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
      ),
    );
  }
}

