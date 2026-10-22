import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/scale_tap.dart';
import 'anatomical_routine_visual.dart';

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

  @override
  Widget build(BuildContext context) {
    final isNewPreset = icon == Icons.add_rounded;

    return ScaleTap(
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 178,
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.hairline),
            boxShadow: context.isDark
                ? null
                : [
                    const BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // Biomechanical anatomical muscle heatmap visual on the right
              if (!isNewPreset)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: 95,
                  child: AnatomicalRoutineVisual(
                    routineName: name,
                    compact: true,
                    width: 95,
                  ),
                ),

              // Foreground card content
              Padding(
                padding: const EdgeInsets.all(S.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isNewPreset
                                ? C.accent.withValues(alpha: 0.15)
                                : C.surfaceHi,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: C.hairline),
                          ),
                          child: Icon(
                            icon ?? Icons.fitness_center_rounded,
                            size: 14,
                            color: isNewPreset ? C.accent : C.text2,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: C.surfaceHi,
                            shape: BoxShape.circle,
                            border: Border.all(color: C.hairline),
                          ),
                          child: Icon(
                            isNewPreset ? Icons.add_rounded : Icons.play_arrow_rounded,
                            size: 16,
                            color: C.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: S.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: C.text1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
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
            ],
          ),
        ),
      ),
    );
  }
}
