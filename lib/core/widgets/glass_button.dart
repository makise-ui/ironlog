import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

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
    Decoration decoration;
    Color textColor = AppColors.textPrimary;

    switch (style) {
      case GlassButtonStyle.primary:
        decoration = BoxDecoration(
          gradient: AppColors.accentGradientHorizontal,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentViolet.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        );
        textColor = Colors.white;
        break;

      case GlassButtonStyle.secondary:
        decoration = BoxDecoration(
          color: AppColors.glassFillActive,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            width: 1.0,
            color: AppColors.glassBorderLight,
          ),
        );
        textColor = AppColors.textPrimary;
        break;

      case GlassButtonStyle.danger:
        decoration = BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            width: 1.0,
            color: AppColors.error.withValues(alpha: 0.4),
          ),
        );
        textColor = AppColors.error;
        break;

      case GlassButtonStyle.ghost:
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        );
        textColor = AppColors.textSecondary;
        break;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width ?? 0,
        minHeight: height,
      ),
      child: Container(
        width: width,
        height: height,
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed != null && !isLoading
                ? () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  }
                : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
