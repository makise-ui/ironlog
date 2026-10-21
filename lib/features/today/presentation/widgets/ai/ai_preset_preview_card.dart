import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironlog/core/theme/app_colors.dart';
import 'package:ironlog/core/utils/haptics.dart';
import 'package:ironlog/core/widgets/scale_tap.dart';
import 'package:ironlog/domain/models/ai_chat_message.dart';

// ── Preset Preview Card (Interactive In-Chat UI) ───────────────────────────
class PresetPreviewCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final Function(String title, String category, List<String> exerciseNames) onImport;
  final Function(String title, List<String> exerciseNames) onStartNow;
  final Function(String prompt) onAskChanges;

  const PresetPreviewCard({
    super.key,
    required this.data,
    required this.onImport,
    required this.onStartNow,
    required this.onAskChanges,
  });

  @override
  ConsumerState<PresetPreviewCard> createState() => PresetPreviewCardState();
}

class PresetPreviewCardState extends ConsumerState<PresetPreviewCard> {
  bool _isImported = false;
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title']?.toString() ?? 'Workout Preset';
    final category = widget.data['category']?.toString() ?? 'Hypertrophy';
    final description = widget.data['description']?.toString() ?? '';
    final rawExercises = widget.data['exercises'] as List? ?? [];
    final exercises = rawExercises.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final exerciseNames = exercises.map((e) => e['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.accent.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.accent.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.accent.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.fitness_center_rounded, color: context.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: context.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${exercises.length} movements • Recommended Split',
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20),
                  color: context.textTertiary,
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),

          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Text(
                description,
                style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.35),
              ),
            ),

          const Divider(height: 16, thickness: 0.6),

          // Exercise List (if expanded)
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: exercises.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final ex = entry.value;
                  final name = ex['name']?.toString() ?? 'Exercise';
                  final sets = ex['targetSets'] ?? 3;
                  final reps = ex['targetReps']?.toString() ?? '8-12';
                  final rest = ex['restSeconds'] ?? 90;
                  final notes = ex['notes']?.toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF171A24) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.cardBorder, width: 0.7),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: context.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$idx',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: context.accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.chipBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$sets sets × $reps',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.chipBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${rest}s',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              '💡 $notes',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Quick Preset Customization Chips ("Ask for Changes")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask AI for changes to this preset:',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.textTertiary),
                ),
                const SizedBox(height: 5),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChangeChip('Swap an exercise', () => widget.onAskChanges('Can you swap one of the exercises in "$title"? Give me alternative options.'), context),
                      const SizedBox(width: 6),
                      _buildChangeChip('Higher volume (+sets)', () => widget.onAskChanges('Make "$title" higher volume with 4-5 sets per exercise.'), context),
                      const SizedBox(width: 6),
                      _buildChangeChip('Dumbbell only', () => widget.onAskChanges('Modify "$title" to use only dumbbells and bodyweight.'), context),
                      const SizedBox(width: 6),
                      _buildChangeChip('Shorten to 40 min', () => widget.onAskChanges('Streamline "$title" so it can be completed in under 40 minutes.'), context),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Primary Actions: Import / Start Today
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13151D) : const Color(0xFFEAEFF6),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => widget.onStartNow(title, exerciseNames),
                    icon: Icon(Icons.play_arrow_rounded, size: 18, color: context.accent),
                    label: Text(
                      'Start Today',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isImported ? AppColors.workingSet : context.accent,
                      foregroundColor: context.onAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _isImported
                        ? null
                        : () async {
                            await widget.onImport(title, category, exerciseNames);
                            if (mounted) setState(() => _isImported = true);
                          },
                    icon: Icon(
                      _isImported ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
                      size: 17,
                    ),
                    label: Text(
                      _isImported ? 'Saved!' : 'Save Preset',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeChip(String label, VoidCallback onTap, BuildContext context) {
    return ScaleTap(
      onPressed: () {
        AppHaptics.step();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E212D)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2E3344)
              : const Color(0xFFDCE2EE),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 11, color: context.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Workout Deletion Confirmation Card (In-Chat UI) ────────────────────────
class WorkoutDeletionCard extends StatelessWidget {
  final AiToolExecutionResult result;
  final VoidCallback onAllow;
  final VoidCallback onReject;

  const WorkoutDeletionCard({
    super.key,
    required this.result,
    required this.onAllow,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = result.data?['status']?.toString() ?? '';
    final isPending = status == 'pending_confirmation';
    final isDeleted = status == 'deleted';
    final isCancelled = status == 'cancelled';

    if (isDeleted) {
      final title = result.data?['workoutTitle']?.toString() ?? 'Workout';
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.workingSet),
            const SizedBox(width: 7),
            Text(
              'Workout "$title" deleted',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (isCancelled) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E212D) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 14, color: context.textTertiary),
            const SizedBox(width: 7),
            Text(
              'Workout deletion rejected — kept session',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    if (!isPending) return const SizedBox.shrink();

    final message = result.data?['message']?.toString() ??
        'The AI assistant is requesting to permanently delete this workout session. All logged exercises and sets will be removed.';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: 16,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delete Workout Request',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.4,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: context.textSecondary,
                  side: BorderSide(
                    color: context.isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                ),
                onPressed: onReject,
                child: const Text(
                  'Reject',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                ),
                icon: const Icon(Icons.delete_forever_rounded, size: 14),
                label: const Text(
                  'Allow Delete',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onAllow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
