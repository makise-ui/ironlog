import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class GlassDecorations {
  GlassDecorations._();

  static const double defaultBlur = 16.0;
  static const double defaultRadius = AppSpacing.radiusMd; // 16

  static BoxDecoration glassContainer({
    double radius = defaultRadius,
    Color? fillColor,
    Color? borderColor,
    double borderWidth = 1.0,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: fillColor ?? AppColors.backgroundCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        width: borderWidth,
        color: borderColor ?? AppColors.glassBorderLight,
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
    );
  }

  static BoxDecoration glassTile({
    double radius = AppSpacing.radiusMd,
    Color? fillColor,
    bool isSelected = false,
    Color? selectedColor,
  }) {
    final active = selectedColor ?? AppColors.activeAccentDark;
    return BoxDecoration(
      color: isSelected
          ? active.withValues(alpha: 0.12)
          : (fillColor ?? AppColors.backgroundCard),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        width: 1.0,
        color: isSelected ? active : AppColors.glassBorderLight,
      ),
    );
  }

  static BoxDecoration accentButton({
    double radius = 12.0,
    Color? color,
  }) {
    final btnColor = color ?? AppColors.activeAccentDark;
    return BoxDecoration(
      color: btnColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: btnColor.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration pillNav({bool isDark = true}) {
    return BoxDecoration(
      color: isDark ? const Color(0xF2121520) : Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      border: Border.all(
        width: 1.0,
        color: isDark ? AppColors.glassBorderLight : AppColors.lightBorder,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
