import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/set_model.dart';
import '../../../../domain/services/effort_analytics_service.dart';

class EffortDistributionCard extends StatelessWidget {
  final List<SetModel> sets;

  const EffortDistributionCard({super.key, required this.sets});

  @override
  Widget build(BuildContext context) {
    final summary = EffortAnalyticsService.evaluateCollection(sets);
    if (summary.totalSets == 0) return const SizedBox.shrink();

    final stimulatingPct = (summary.stimulatingRatio * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: context.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Training Effort & Stimulus',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Avg RPE ${summary.averageRpe}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stimulating Ratio Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: summary.stimulatingSets,
                    child: Container(color: context.accent),
                  ),
                  if (summary.junkVolumeSets > 0)
                    Expanded(
                      flex: summary.junkVolumeSets,
                      child: Container(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stat Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat('Stimulating Sets', '${summary.stimulatingSets} ($stimulatingPct%)', context.accent),
              _buildStat('Effective Reps', '${summary.totalEffectiveReps}', context.textPrimary),
              _buildStat('Junk Volume', '${summary.junkVolumeSets}', summary.junkVolumeSets > 2 ? AppColors.warning : context.textTertiary),
            ],
          ),
          const SizedBox(height: 10),

          // Coaching insight message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  summary.junkVolumeSets > 3 ? Icons.info_outline : Icons.check_circle_outline,
                  size: 16,
                  color: summary.junkVolumeSets > 3 ? AppColors.warning : context.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary.fatigueWarning,
                    style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
