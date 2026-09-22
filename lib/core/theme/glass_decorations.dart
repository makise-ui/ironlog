import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class GlassDecorations {
  GlassDecorations._();

  static const double defaultBlur = 20.0;
  static const double defaultRadius = AppSpacing.radiusLg; // 24

  static BoxDecoration glassContainer({
    double radius = defaultRadius,
    Color fillColor = AppColors.glassFill,
    Color borderColorLight = AppColors.glassBorderLight,
    Color borderColorDim = AppColors.glassBorderDim,
    double borderWidth = 1.0,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        width: borderWidth,
        color: borderColorLight,
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
    );
  }

  static BoxDecoration glassTile({
    double radius = AppSpacing.radiusMd,
    Color fillColor = AppColors.glassTileFill,
    bool isSelected = false,
  }) {
    return BoxDecoration(
      color: isSelected ? AppColors.glassFillActive : fillColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        width: 1.0,
        color: isSelected
            ? AppColors.accentCyan.withValues(alpha: 0.5)
            : AppColors.glassBorderDim,
      ),
    );
  }

  static BoxDecoration accentButton({
    double radius = AppSpacing.radiusMd,
  }) {
    return BoxDecoration(
      gradient: AppColors.accentGradientHorizontal,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: AppColors.accentViolet.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration pillNav() {
    return BoxDecoration(
      color: const Color(0x220E121E),
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      border: Border.all(
        width: 1.0,
        color: AppColors.glassBorderLight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.6),
          blurRadius: 32,
          spreadRadius: 2,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }
}
