import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../../../../data/providers.dart';
import '../../../../domain/models/suggestion_model.dart';
import '../suggestion_explain_sheet.dart';

class EmptyWorkoutView extends ConsumerStatefulWidget {
  final Suggestion? nextWorkoutSuggestion;
  final VoidCallback onStartSuggestedRoutine;
  final Function(String routineId) onSelectRoutine;
  final VoidCallback onAddExercise;
  final VoidCallback onOpenRoutines;
  final VoidCallback onCopyLast;
  final VoidCallback onPasteImport;
  final VoidCallback onMarkRestDay;

  const EmptyWorkoutView({
    super.key,
    this.nextWorkoutSuggestion,
    required this.onStartSuggestedRoutine,
    required this.onSelectRoutine,
    required this.onAddExercise,
    required this.onOpenRoutines,
    required this.onCopyLast,
    required this.onPasteImport,
    required this.onMarkRestDay,
  });

  @override
  ConsumerState<EmptyWorkoutView> createState() => _EmptyWorkoutViewState();
}

class _EmptyWorkoutViewState extends ConsumerState<EmptyWorkoutView> {
  bool _isSuggestionDismissed = false;

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(routinesProvider);
    final showSuggestion = widget.nextWorkoutSuggestion != null && !_isSuggestionDismissed;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sleek AI Coach Recommendation Hero Card
          if (showSuggestion) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF424242) : const Color(0xFFE5E5E5),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0x08000000),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: context.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(Icons.auto_awesome_rounded, color: context.accent, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AI RECOVERY & PROGRESSION COACH',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: context.accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      BouncyPressable(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useRootNavigator: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => SuggestionExplainSheet(
                              suggestion: widget.nextWorkoutSuggestion!,
                              onApply: widget.onStartSuggestedRoutine,
                            ),
                          );
                        },
                        scaleDown: 0.94,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: context.chipBorder, width: 0.8),
                          ),
                          child: Text(
                            'Why?',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BouncyPressable(
                        onTap: () => setState(() => _isSuggestionDismissed = true),
                        scaleDown: 0.92,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: context.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.nextWorkoutSuggestion?.title.replaceAll('Suggested Workout: ', '') ??
                        'Push Hypertrophy (Chest • Shoulders • Triceps)',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.nextWorkoutSuggestion?.body ??
                        'Chest and Triceps have fully recovered. Ready to push progressive overload.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BouncyPressable(
                    onTap: widget.onStartSuggestedRoutine,
                    scaleDown: 0.97,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: context.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Start Recommended Session',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 2. Quick Routines Horizontal Header
          Row(
            children: [
              Text(
                'QUICK ROUTINES & PRESETS',
                style: AppTypography.labelSmall.copyWith(
                  color: context.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              BouncyPressable(
                onTap: widget.onOpenRoutines,
                scaleDown: 0.94,
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Routines Carousel
          routinesAsync.when(
            data: (routines) {
              if (routines.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 108,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: routines.length + 1,
                  itemBuilder: (context, index) {
                    if (index == routines.length) {
                      return BouncyPressable(
                        onTap: widget.onOpenRoutines,
                        scaleDown: 0.96,
                        child: Container(
                          width: 130,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.cardBorder),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline_rounded, color: context.accent, size: 24),
                              const SizedBox(height: 6),
                              Text(
                                'New Preset',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Create template',
                                style: TextStyle(fontSize: 10, color: context.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final r = routines[index];
                    return BouncyPressable(
                      onTap: () => widget.onSelectRoutine(r.id),
                      scaleDown: 0.96,
                      child: Container(
                        width: 175,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x06000000),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.play_circle_fill_rounded, size: 20, color: context.accent),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.description.isNotEmpty ? r.description : '${r.items.length} movements',
                              style: TextStyle(fontSize: 11, color: context.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${r.items.length} MOVEMENTS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: context.textSecondary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox(height: 108),
            error: (_, _) => const SizedBox(height: 108),
          ),

          const SizedBox(height: 20),

          // 3. Quick Actions Grid
          Text(
            'LOGGING OPTIONS',
            style: AppTypography.labelSmall.copyWith(
              color: context.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildActionTile(
                context: context,
                icon: Icons.add_circle_outline_rounded,
                label: 'Add Movement',
                sublabel: 'Custom pick',
                onTap: widget.onAddExercise,
              ),
              const SizedBox(width: 8),
              _buildActionTile(
                context: context,
                icon: Icons.dashboard_customize_rounded,
                label: 'Presets',
                sublabel: 'Templates',
                onTap: widget.onOpenRoutines,
              ),
              const SizedBox(width: 8),
              _buildActionTile(
                context: context,
                icon: Icons.copy_rounded,
                label: 'Copy Last',
                sublabel: 'Past session',
                onTap: widget.onCopyLast,
              ),
              const SizedBox(width: 8),
              _buildActionTile(
                context: context,
                icon: Icons.spa_rounded,
                label: 'Rest Day',
                sublabel: 'Log recovery',
                onTap: widget.onMarkRestDay,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: BouncyPressable(
        onTap: onTap,
        scaleDown: 0.95,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cardBorder),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x06000000),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 21, color: context.accent),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 9.5,
                  color: context.textTertiary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

