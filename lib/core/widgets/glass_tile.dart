import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class GlassTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? fillColor;
  final Color? borderColor;
  final bool isSelected;
  final double? width;
  final double? height;

  const GlassTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = const EdgeInsets.only(bottom: AppSpacing.sm),
    this.radius = AppSpacing.radiusMd,
    this.fillColor,
    this.borderColor,
    this.isSelected = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ??
        (isSelected
            ? AppColors.accentCyan.withValues(alpha: 0.6)
            : AppColors.glassBorderDim);

    final effectiveFillColor = fillColor ??
        (isSelected ? AppColors.glassFillActive : AppColors.glassTileFill);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveFillColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          width: 1.0,
          color: effectiveBorderColor,
        ),
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(radius),
          splashColor: AppColors.accentCyan.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
