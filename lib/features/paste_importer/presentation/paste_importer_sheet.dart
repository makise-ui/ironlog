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
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: Theme.of(context).brightness,
              primary: context.accent,
              onPrimary: context.onAccent,
              secondary: context.accent,
              onSecondary: context.onAccent,
              error: AppColors.error,
              onError: Colors.white,
              surface: context.cardElevated,
              onSurface: context.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;
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
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(
          top: BorderSide(color: context.sheetBorder, width: 1.5),
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
                color: context.handleBar,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paste-to-Log Importer',
                      style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
                    ),
                    Text(
                      'Free-text multi-set parser',
                      style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.cardBorder),

          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                          color: context.chipBg,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: context.chipBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: context.accent),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              AppDateUtils.formatFullDate(_selectedDate),
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadSample,
                      icon: Icon(Icons.auto_fix_high_rounded, size: 16, color: context.accent),
                      label: Text('Load Example', style: TextStyle(color: context.accent, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Free Text Input Box
                Container(
                  decoration: BoxDecoration(
                    color: context.inputBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: context.inputBorder),
                  ),
                  child: TextField(
                    controller: _textController,
                    maxLines: 5,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      color: context.textPrimary,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Paste workout notes here...\n\nExample:\nBENCH PRESS: 7.5/15, 10/13, 10/15\nIncline DB Press: 32kg x 8, 30kg x 10',
                      hintStyle: TextStyle(color: context.textTertiary, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Preview section
                Row(
                  children: [
                    Text(
                      'PARSED PREVIEW',
                      style: AppTypography.labelMedium.copyWith(color: context.textSecondary),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (_parsedBlocks.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: Text(
                          '${_parsedBlocks.length} exercises',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.accent,
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
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: context.cardBorder),
                    ),
                    child: Center(
                      child: Text(
                        'Type or paste workout text above to see the interactive preview.',
                        style: TextStyle(color: context.textTertiary, fontSize: 13),
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
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                '${block.sets.length} sets',
                                style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
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
                                  color: context.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '${s.weight} ${unit.name} × ${s.reps}',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                    fontFeatures: const [FontFeature.tabularFigures()],
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
