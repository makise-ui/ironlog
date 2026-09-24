import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'scale_tap.dart';

enum GlassButtonStyle { primary, secondary, danger, ghost }

class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GlassButtonStyle style;
  final double? width;
  final double height;
  final bool isLoading;

  const GlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.style = GlassButtonStyle.primary,
    this.width,
    this.height = 50.0,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Decoration decoration;
    Color textColor;

    switch (style) {
      case GlassButtonStyle.primary:
        decoration = BoxDecoration(
          color: context.accent,
          borderRadius: BorderRadius.circular(14.0),
          boxShadow: [
            BoxShadow(
              color: context.accent.withValues(alpha: isDark ? 0.22 : 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        );
        textColor = context.onAccent;
        break;

      case GlassButtonStyle.secondary:
        decoration = BoxDecoration(
          color: context.cardElevated,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            width: 1.0,
            color: context.cardBorder,
          ),
        );
        textColor = context.textPrimary;
        break;

      case GlassButtonStyle.danger:
        decoration = BoxDecoration(
          color: AppColors.error.withValues(alpha: isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            width: 1.0,
            color: AppColors.error.withValues(alpha: isDark ? 0.40 : 0.25),
          ),
        );
        textColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        break;

      case GlassButtonStyle.ghost:
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
        );
        textColor = context.textSecondary;
        break;
    }

    final buttonContent = Container(
      width: width,
      height: height,
      decoration: decoration,
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: textColor),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width ?? 0,
        minHeight: height,
      ),
      child: onPressed != null && !isLoading
          ? ScaleTap(
              onPressed: onPressed,
              scaleDown: 0.97,
              child: buttonContent,
            )
          : buttonContent,
    );
  }
}
