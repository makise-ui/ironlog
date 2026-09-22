import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../domain/services/paste_parser.dart';
import '../../../data/providers.dart';

class PasteImporterSheet extends ConsumerStatefulWidget {
  final VoidCallback onImportCompleted;

  const PasteImporterSheet({
    super.key,
    required this.onImportCompleted,
  });

  @override
  ConsumerState<PasteImporterSheet> createState() => _PasteImporterSheetState();
}

class _PasteImporterSheetState extends ConsumerState<PasteImporterSheet> {
  final TextEditingController _textController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<ParsedExerciseBlock> _parsedBlocks = [];
  bool _isCommitting = false;

  final String _sampleText = '''BENCH PRESS: 7.5/15, 10/13, 10/15
Incline DB Press: 32kg x 8, 32kg x 8, 30kg x 10
Overhead Barbell Press: 40/8, 42.5/6
Tricep Rope Pushdown: 25/12, 30/10''';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final blocks = PasteParser.parse(_textController.text);
    setState(() {
      _parsedBlocks = blocks;
    });
  }

  void _loadSample() {
    AppHaptics.tap();
    _textController.text = _sampleText;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentCyan,
              surface: AppColors.backgroundCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      AppHaptics.step();
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _commit() async {
    if (_parsedBlocks.isEmpty || _isCommitting) return;

    AppHaptics.save();
    setState(() => _isCommitting = true);

    try {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.commitParsedWorkout(
        blocks: _parsedBlocks,
        date: _selectedDate,
      );

      widget.onImportCompleted();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error committing workout: $e');
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitNotifierProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xF00D0F18),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(
          top: BorderSide(color: AppColors.glassBorderLight, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paste-to-Log Importer', style: AppTypography.titleLarge),
                    Text('Free-text multi-set parser', style: AppTypography.labelSmall),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.glassBorderDim),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Date picker row + Load Example button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.glassFillActive,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: AppColors.glassBorderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.accentCyan),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              AppDateUtils.formatFullDate(_selectedDate),
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadSample,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 16, color: AppColors.accentCyan),
                      label: const Text('Load Example', style: TextStyle(color: AppColors.accentCyan, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Free Text Input Box
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.glassFillActive,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.glassBorderLight),
                  ),
                  child: TextField(
                    controller: _textController,
                    maxLines: 5,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Paste workout notes here...\n\nExample:\nBENCH PRESS: 7.5/15, 10/13, 10/15\nIncline DB Press: 32kg x 8, 30kg x 10',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Preview section
                Row(
                  children: [
                    const Text('PARSED PREVIEW', style: AppTypography.labelMedium),
                    const SizedBox(width: AppSpacing.xs),
                    if (_parsedBlocks.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: Text(
                          '${_parsedBlocks.length} exercises',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                if (_parsedBlocks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.glassTileFill,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.glassBorderDim),
                    ),
                    child: const Center(
                      child: Text(
                        'Type or paste workout text above to see the interactive preview.',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._parsedBlocks.map((block) {
                    return GlassTile(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                block.exerciseName,
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${block.sets.length} sets',
                                style: AppTypography.labelSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: block.sets.map((s) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '${s.weight} ${unit.name} × ${s.reps}',
                                  style: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Bottom Commit Bar
          Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
              top: AppSpacing.xs,
            ),
            child: GlassButton(
              text: 'Commit to Log (${_parsedBlocks.length} Exercises)',
              icon: Icons.upload_rounded,
              isLoading: _isCommitting,
              onPressed: _parsedBlocks.isNotEmpty ? _commit : null,
            ),
          ),
        ],
      ),
    );
  }
}
