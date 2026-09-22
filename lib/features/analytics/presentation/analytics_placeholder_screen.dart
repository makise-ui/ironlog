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
            const Text('Analytics', style: AppTypography.displayMedium),
            const SizedBox(height: 2),
            const Text('Deep charts, balance radar, and progression', style: AppTypography.labelSmall),
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
                          color: AppColors.accentCyan.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          size: 32,
                          color: AppColors.accentCyan,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Deep Analytics', style: AppTypography.titleLarge),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Scheduled for Phase 2: e1RM trends, muscle split donut, balance radar, weekly heatmap, PR timeline & isolate processing.',
                        style: AppTypography.bodyMedium,
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
