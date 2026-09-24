import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_container.dart';

class AnalyticsPlaceholderScreen extends StatelessWidget {
  const AnalyticsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics',
              style: AppTypography.displayMedium.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              'Deep charts, balance radar, and progression',
              style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: Center(
                child: GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.accent.withValues(alpha: 0.15),
                          border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          size: 32,
                          color: context.accent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Deep Analytics',
                        style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Scheduled for Phase 2: e1RM trends, muscle split donut, balance radar, weekly heatmap, PR timeline & isolate processing.',
                        style: AppTypography.bodyMedium.copyWith(color: context.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}
