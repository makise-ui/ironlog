import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onQuickLogPressed;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onQuickLogPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: bottomInset > 0 ? bottomInset + AppSpacing.xs : AppSpacing.md,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                color: const Color(0x30111524),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(
                  width: 1.0,
                  color: AppColors.glassBorderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavBarItem(
                    icon: Icons.fitness_center_rounded,
                    label: 'Today',
                    isSelected: currentIndex == 0,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTabSelected(0);
                    },
                  ),
                  _NavBarItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'History',
                    isSelected: currentIndex == 1,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTabSelected(1);
                    },
                  ),
                  // Central "+" action button
                  _CentralActionButton(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onQuickLogPressed();
                    },
                  ),
                  _NavBarItem(
                    icon: Icons.insights_rounded,
                    label: 'Analytics',
                    isSelected: currentIndex == 2,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTabSelected(2);
                    },
                  ),
                  _NavBarItem(
                    icon: Icons.tune_rounded,
                    label: 'Settings',
                    isSelected: currentIndex == 3,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTabSelected(3);
                    },
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

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.accentCyan;
    final inactiveColor = AppColors.textTertiary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CentralActionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CentralActionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.accentGradientHorizontal,
          boxShadow: [
            BoxShadow(
              color: AppColors.accentViolet.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            width: 1.5,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
