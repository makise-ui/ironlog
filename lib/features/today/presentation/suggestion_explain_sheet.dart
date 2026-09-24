import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/models/suggestion_model.dart';

class SuggestionExplainSheet extends StatelessWidget {
  final Suggestion suggestion;
  final VoidCallback? onApply;

  const SuggestionExplainSheet({
    super.key,
    required this.suggestion,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(
          top: BorderSide(color: context.sheetBorder, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.handleBar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.psychology_rounded, color: context.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.ruleName,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'CONFIDENCE ${(suggestion.confidence * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: context.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            suggestion.reasonCode,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textTertiary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.textTertiary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Title & Body
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: context.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  suggestion.body,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Explanation Breakdown
          Text(
            'WHY THIS WAS SUGGESTED',
            style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0x20000000) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: context.cardBorder),
            ),
            child: Text(
              suggestion.explanation.trim(),
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12.5,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Action Button
          if (onApply != null)
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    text: suggestion.actionLabel ?? 'Apply Target to Workout',
                    icon: Icons.check_circle_rounded,
                    style: GlassButtonStyle.primary,
                    onPressed: () {
                      AppHaptics.success();
                      Navigator.of(context).pop();
                      onApply!();
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
