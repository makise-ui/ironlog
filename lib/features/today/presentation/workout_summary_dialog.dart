import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../data/providers.dart';
import '../../../domain/models/workout_model.dart';
import '../../../domain/models/workout_debrief_model.dart';
import 'widgets/shareable_workout_card.dart';

class WorkoutSummaryDialog extends ConsumerStatefulWidget {
  final WorkoutModel workout;
  final Duration elapsed;
  final WeightUnit unit;
  final Function(int feel, String note) onFinish;

  const WorkoutSummaryDialog({
    super.key,
    required this.workout,
    required this.elapsed,
    required this.unit,
    required this.onFinish,
  });

  @override
  ConsumerState<WorkoutSummaryDialog> createState() => _WorkoutSummaryDialogState();
}

class _WorkoutSummaryDialogState extends ConsumerState<WorkoutSummaryDialog> {
  int _selectedFeel = 4; // default good
  final TextEditingController _noteController = TextEditingController();

  WorkoutDebriefData? _debrief;
  bool _loadingDebrief = true;

  final List<IconData> _feelIcons = [
    Icons.sentiment_very_dissatisfied_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.local_fire_department_rounded,
  ];
  final List<String> _feelLabels = ['Tough', 'Fatigued', 'Okay', 'Good', 'Crushed it'];

  @override
  void initState() {
    super.initState();
    if (widget.workout.feel != null) {
      _selectedFeel = widget.workout.feel!;
    }
    _noteController.text = widget.workout.note ?? '';
    _loadDebrief();
  }

  Future<void> _loadDebrief() async {
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final debrief = await repo.getWorkoutDebrief(widget.workout, elapsed: widget.elapsed);
      if (mounted) {
        setState(() {
          _debrief = debrief;
          _loadingDebrief = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDebrief = false);
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = widget.workout.totalSetsCount;
    final volume = widget.workout.totalVolume;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: context.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.7 : 0.1),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with trophy / check icon
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.accent,
                    boxShadow: [
                      BoxShadow(
                        color: context.accent.withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Icon(Icons.check_rounded, color: context.onAccent, size: 30),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Workout Complete!',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamilyDisplay,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  widget.workout.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Metrics Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: context.chipBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.chipBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('TIME', _formatDuration(widget.elapsed), context),
                    Container(width: 1, height: 28, color: context.chipBorder),
                    _buildStatCol('SETS', '$totalSets sets', context),
                    Container(width: 1, height: 28, color: context.chipBorder),
                    _buildStatCol('VOLUME', UnitConverter.formatWeight(volume, unit: widget.unit), context),
                  ],
                ),
              ),

              // Post-Workout AI Debrief section
              _buildDebriefSection(context),

              const SizedBox(height: 14),

              // How did it feel?
              Text(
                'HOW DID IT FEEL?',
                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(5, (index) {
                  final feelVal = index + 1;
                  final isSelected = _selectedFeel == feelVal;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 3,
                        right: index == 4 ? 0 : 3,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.step();
                          setState(() => _selectedFeel = feelVal);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.accent.withValues(alpha: context.isDark ? 0.20 : 0.12)
                                : context.chipBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? context.accent : context.chipBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_feelIcons[index], size: 20, color: isSelected ? context.accent : context.textSecondary),
                              const SizedBox(height: 3),
                              Text(
                                _feelLabels[index],
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? context.textPrimary : context.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Notes
              Text(
                'SESSION NOTES (OPTIONAL)',
                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: context.inputBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.inputBorder),
                ),
                child: TextField(
                  controller: _noteController,
                  maxLines: 2,
                  style: TextStyle(color: context.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Good chest pump, felt strong on bench...',
                    hintStyle: TextStyle(color: context.textTertiary, fontSize: 12),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Post-Workout Fuel Hint
              GestureDetector(
                onTap: () {
                  AppHaptics.tap();
                  Navigator.of(context).pop();
                  widget.onFinish(_selectedFeel, _noteController.text.trim());
                  context.push('/nutrition');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.accent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant_rounded, size: 18, color: context.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Post-Workout Fuel Plan',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.accent),
                            ),
                            Text(
                              'Finish and view calibrated protein & recovery meals',
                              style: TextStyle(fontSize: 10.5, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: context.accent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Finish Button
              GlassButton(
                text: 'Save & Finish Workout',
                icon: Icons.check_circle_outline_rounded,
                style: GlassButtonStyle.primary,
                onPressed: () {
                  AppHaptics.success();
                  Navigator.of(context).pop();
                  widget.onFinish(_selectedFeel, _noteController.text.trim());
                },
              ),
              const SizedBox(height: 8),

              if (_debrief != null) ...[
                GlassButton(
                  text: 'Share Workout Story Card',
                  icon: Icons.share_rounded,
                  style: GlassButtonStyle.secondary,
                  onPressed: () {
                    AppHaptics.tap();
                    ShareWorkoutModalDialog.show(
                      context,
                      workout: widget.workout,
                      debrief: _debrief!,
                      unit: widget.unit,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Keep Logging', style: TextStyle(color: context.textTertiary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebriefSection(BuildContext context) {
    if (_loadingDebrief) {
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.chipBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.accent),
            ),
            const SizedBox(width: 8),
            Text(
              'Analyzing session volume & PRs...',
              style: TextStyle(fontSize: 11.5, color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_debrief == null) return const SizedBox.shrink();
    final debrief = _debrief!;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.chipBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: debrief.hasPrs
              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
              : context.chipBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: context.accent, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'AI POST-WORKOUT DEBRIEF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: context.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            debrief.headline,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          if (debrief.hasPrs) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: debrief.brokenPrs.map((pr) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${pr.exerciseName}: ${UnitConverter.formatWeight(pr.value, unit: widget.unit)} (${pr.formattedKind})',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                debrief.isVolumeSurge
                    ? Icons.trending_up_rounded
                    : (debrief.isVolumeDeload ? Icons.trending_down_rounded : Icons.show_chart_rounded),
                size: 15,
                color: debrief.isVolumeSurge
                    ? const Color(0xFF10B981)
                    : (debrief.isVolumeDeload ? const Color(0xFF38BDF8) : context.accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  debrief.volumeInsight,
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_moon_rounded, size: 15, color: context.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  debrief.recoveryAdvice,
                  style: TextStyle(fontSize: 10.5, color: context.textTertiary, height: 1.25),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.textTertiary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
