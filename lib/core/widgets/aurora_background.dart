import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Clean, modern athletic app canvas with subtle studio depth
class AuroraBackground extends StatelessWidget {
  final Widget child;

  const AuroraBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return Container(
        color: AppColors.backgroundLight,
        child: child,
      );
    }

    return Container(
      color: AppColors.background,
      child: child,
    );
  }
}
