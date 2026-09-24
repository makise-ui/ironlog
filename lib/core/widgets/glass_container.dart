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
    this.radius = AppSpacing.radiusMd,
    this.blur = 16.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.enableBlur = false,
    this.fillColor,
    this.borderColor,
    this.borderGradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultFill = context.cardBg;
    final defaultBorder = context.cardBorder;

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor ?? defaultFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          width: 1.0,
          color: borderColor ?? defaultBorder,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: context.accent.withValues(alpha: 0.1),
          highlightColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
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
