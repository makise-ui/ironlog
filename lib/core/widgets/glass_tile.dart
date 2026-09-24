import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'scale_tap.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBorderColor = borderColor ??
        (isSelected
            ? context.accent
            : context.cardBorder);

    final effectiveFillColor = fillColor ??
        (isSelected
            ? context.accent.withValues(alpha: isDark ? 0.12 : 0.08)
            : context.cardBg);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveFillColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          width: isSelected ? 1.2 : 1.0,
          color: effectiveBorderColor,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = ScaleTap(
        onPressed: onTap,
        scaleDown: 0.98,
        child: content,
      );
    } else if (onLongPress != null) {
      content = GestureDetector(
        onLongPress: onLongPress,
        child: content,
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
