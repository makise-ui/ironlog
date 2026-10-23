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

    return ScaleTap(
      onPressed: onTap,
      child: Container(
        width: 178,
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.isDark ? const Color(0xFF232733) : const Color(0xFFE2E5ED),
            width: 1.0,
          ),
          boxShadow: context.isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
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
        child: Padding(
          padding: const EdgeInsets.all(S.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Category icon on left, Biometric Telemetry Ring on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isNewPreset ? C.accent.withValues(alpha: 0.15) : C.surfaceHi,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.hairline),
                    ),
                    child: Icon(
                      icon ?? Icons.fitness_center_rounded,
                      size: 14,
                      color: isNewPreset ? C.accent : C.text2,
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
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: C.surfaceHi,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.hairline),
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
                      fontWeight: FontWeight.w700,
                      color: C.text1,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: C.text2,
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
