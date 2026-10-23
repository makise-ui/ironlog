import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/scale_tap.dart';
import 'workout_telemetry_dial.dart';

class RoutineCard extends StatelessWidget {
  const RoutineCard(
    this.name,
    this.detail, {
    super.key,
    this.onTap,
    this.icon,
  });

  final String name;
  final String detail;
  final VoidCallback? onTap;
  final IconData? icon;

  double _resolveRoutineLoad(String routineName) {
    final lower = routineName.toLowerCase();
    if (lower.contains('leg') || lower.contains('squat') || lower.contains('lower')) {
      return 0.92;
    }
    if (lower.contains('pull') || lower.contains('back') || lower.contains('deadlift')) {
      return 0.86;
    }
    if (lower.contains('push') || lower.contains('chest')) {
      return 0.84;
    }
    if (lower.contains('upper')) {
      return 0.88;
    }
    if (lower.contains('arm')) {
      return 0.78;
    }
    return 0.80;
  }

  @override
  Widget build(BuildContext context) {
    final isNewPreset = icon == Icons.add_rounded;
    final loadScore = _resolveRoutineLoad(name);
    final isDark = context.isDark;

    return ScaleTap(
      onPressed: onTap,
      child: Container(
        width: 178,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF161925),
                    Color(0xFF0F1118),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF6F8FC),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF282D3D) : const Color(0xFFDFE3EC),
            width: 1.0,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(S.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Category icon on left, Biometric Micro-Chronograph Ring on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6.5),
                    decoration: BoxDecoration(
                      color: isNewPreset
                          ? C.accent.withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF1B1E2B) : const Color(0xFFEEF1F8)),
                      borderRadius: BorderRadius.circular(8.5),
                      border: Border.all(
                        color: isNewPreset
                            ? C.accent.withValues(alpha: 0.35)
                            : (isDark ? const Color(0xFF2B3042) : const Color(0xFFE2E6F0)),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      icon ?? Icons.fitness_center_rounded,
                      size: 14.5,
                      color: isNewPreset ? C.accent : context.textSecondary,
                    ),
                  ),
                  if (!isNewPreset)
                    WorkoutTelemetryDial.compact(
                      progress: loadScore,
                      valueText: '${(loadScore * 100).toInt()}%',
                      size: 38.0,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(5.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B1E2B) : const Color(0xFFEEF1F8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF2B3042) : const Color(0xFFE2E6F0)),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: C.accent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: S.md),

              // Title and Meta details
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3.5),
                  Text(
                    detail,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: context.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
