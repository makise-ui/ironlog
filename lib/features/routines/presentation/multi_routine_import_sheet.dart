import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../data/database/database.dart';
import '../../../domain/models/routine_model.dart';
import '../../../domain/services/plan_share_service.dart';

class MultiRoutineImportSheet extends StatefulWidget {
  final PlanBundlePreviewModel bundle;
  final AppDatabase db;
  final Function(List<RoutineModel> importedRoutines) onImported;

  const MultiRoutineImportSheet({
    super.key,
    required this.bundle,
    required this.db,
    required this.onImported,
  });

  static Future<void> show(
    BuildContext context, {
    required PlanBundlePreviewModel bundle,
    required AppDatabase db,
    required Function(List<RoutineModel> importedRoutines) onImported,
  }) {
    AppHaptics.tap();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MultiRoutineImportSheet(
        bundle: bundle,
        db: db,
        onImported: onImported,
      ),
    );
  }

  @override
  State<MultiRoutineImportSheet> createState() => _MultiRoutineImportSheetState();
}

class _MultiRoutineImportSheetState extends State<MultiRoutineImportSheet> {
  late final Set<int> _selectedIndices;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _selectedIndices = List.generate(widget.bundle.routines.length, (i) => i).toSet();
  }

  Future<void> _importSelected() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one preset to import.')),
      );
      return;
    }

    setState(() => _isImporting = true);
    AppHaptics.save();

    try {
      final imported = await PlanShareService.importRoutinesBundleFromPayload(
        widget.bundle.rawPayload,
        widget.db,
        selectedIndices: _selectedIndices.toList(),
      );

      widget.onImported(imported);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${imported.length} preset routines!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing presets: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSelected = _selectedIndices.length == widget.bundle.routines.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Preset Bundle',
                        style: AppTypography.titleLarge.copyWith(color: context.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.bundle.title,
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.cardBorder),

          // Selection control row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedIndices.length} of ${widget.bundle.routines.length} Selected',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    AppHaptics.selection();
                    setState(() {
                      if (allSelected) {
                        _selectedIndices.clear();
                      } else {
                        _selectedIndices.addAll(List.generate(widget.bundle.routines.length, (i) => i));
                      }
                    });
                  },
                  child: Text(
                    allSelected ? 'Deselect All' : 'Select All',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.accent),
                  ),
                ),
              ],
            ),
          ),

          // Routines list
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: widget.bundle.routines.length,
              itemBuilder: (context, index) {
                final routine = widget.bundle.routines[index];
                final isSelected = _selectedIndices.contains(index);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161822) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? context.accent.withValues(alpha: 0.6)
                          : (isDark ? const Color(0xFF262B3D) : const Color(0xFFE2E4EE)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      AppHaptics.selection();
                      setState(() {
                        if (isSelected) {
                          _selectedIndices.remove(index);
                        } else {
                          _selectedIndices.add(index);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: context.accent,
                            onChanged: (val) {
                              AppHaptics.selection();
                              setState(() {
                                if (val == true) {
                                  _selectedIndices.add(index);
                                } else {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        routine.title,
                                        style: TextStyle(
                                          fontSize: 15,
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
                                        color: context.accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${routine.exercises.length} Exercises',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: context.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (routine.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    routine.description,
                                    style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: routine.exercises.take(4).map((e) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: context.chipBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        e.name,
                                        style: TextStyle(fontSize: 10, color: context.textSecondary),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (routine.exercises.length > 4)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      '+${routine.exercises.length - 4} more',
                                      style: TextStyle(fontSize: 10, color: context.textTertiary),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Import Action Bottom Bar
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              8,
              AppSpacing.md,
              MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            child: GlassButton(
              text: _isImporting
                  ? 'Importing...'
                  : 'Import ${_selectedIndices.length} ${_selectedIndices.length == 1 ? "Preset" : "Presets"}',
              icon: Icons.download_done_rounded,
              style: GlassButtonStyle.primary,
              onPressed: _isImporting || _selectedIndices.isEmpty ? null : _importSelected,
            ),
          ),
        ],
      ),
    );
  }
}
