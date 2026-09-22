import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool enableBlur;
  final Color? fillColor;
  final Color? borderColor;
  final Gradient? borderGradient;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.radius = AppSpacing.radiusLg,
    this.blur = 20.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.enableBlur = true,
    this.fillColor,
    this.borderColor,
    this.borderGradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor ?? AppColors.glassFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          width: 1.0,
          color: borderColor ?? AppColors.glassBorderLight,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: AppColors.accentCyan.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }

    if (enableBlur) {
      content = RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: content,
          ),
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
