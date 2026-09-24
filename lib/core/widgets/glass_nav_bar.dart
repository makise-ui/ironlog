import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/haptics.dart';
import 'scale_tap.dart';

class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onQuickLogPressed;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.onQuickLogPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navBg = isDark ? const Color(0xF2090A0E) : const Color(0xF6FFFFFF);
    final topBorderColor = isDark ? C.hairline : const Color(0xFFE5E7EB);

    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              bottom: bottomInset > 0 ? bottomInset : 8,
              top: 6,
            ),
            decoration: BoxDecoration(
              color: navBg,
              border: Border(
                top: BorderSide(
                  color: topBorderColor,
                  width: 0.8,
                ),
              ),
            ),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  _NavBarItem(
                    icon: Icons.bolt_rounded,
                    label: 'Today',
                    isSelected: currentIndex == 0,
                    onTap: () {
                      AppHaptics.step();
                      onTabSelected(0);
                    },
                  ),
                  _NavBarItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'History',
                    isSelected: currentIndex == 1,
                    onTap: () {
                      AppHaptics.step();
                      onTabSelected(1);
                    },
                  ),
                  if (onQuickLogPressed != null)
                    Expanded(
                      child: Center(
                        child: ScaleTap(
                          onPressed: () {
                            AppHaptics.mediumImpact();
                            onQuickLogPressed!();
                          },
                          scaleDown: 0.90,
                          enableHaptic: false,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: C.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: C.accent.withValues(alpha: isDark ? 0.32 : 0.22),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: C.onAccent,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  _NavBarItem(
                    icon: Icons.insights_rounded,
                    label: 'Analytics',
                    isSelected: currentIndex == 2,
                    onTap: () {
                      AppHaptics.step();
                      onTabSelected(2);
                    },
                  ),
                  _NavBarItem(
                    icon: Icons.tune_rounded,
                    label: 'Settings',
                    isSelected: currentIndex == 3,
                    onTap: () {
                      AppHaptics.step();
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
    final activeColor = C.accent;
    final inactiveColor = C.text3;

    return Expanded(
      child: ScaleTap(
        onPressed: onTap,
        scaleDown: 0.94,
        enableHaptic: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: isSelected ? 4 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
