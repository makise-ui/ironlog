import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../data/providers.dart';
import '../../../domain/services/csv_import_service.dart';

class CsvImportSheet extends ConsumerStatefulWidget {
  const CsvImportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CsvImportSheet(),
    );
  }

  @override
  ConsumerState<CsvImportSheet> createState() => _CsvImportSheetState();
}

class _CsvImportSheetState extends ConsumerState<CsvImportSheet> {
  bool _isProcessing = false;
  String? _selectedFileName;
  String? _detectedSource;
  int? _previewRowCount;
  String? _csvContent;
  String? _errorMessage;
  CsvImportResult? _importResult;

  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
      _importResult = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content;

      if (file.bytes != null) {
        content = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw const FormatException('Unable to read selected file');
      }

      final parsed = CsvImportService.parseCsv(content);
      if (parsed.isEmpty) {
        throw const FormatException('The selected CSV file is empty.');
      }

      final detected = CsvImportService.detectSource(parsed.first);

      setState(() {
        _selectedFileName = file.name;
        _detectedSource = detected;
        _previewRowCount = parsed.length - 1;
        _csvContent = content;
      });

      AppHaptics.success();
    } catch (e) {
      AppHaptics.warning();
      setState(() {
        _errorMessage = e.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> _executeImport() async {
    if (_csvContent == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    AppHaptics.tap();

    try {
      final db = ref.read(databaseProvider);
      final importer = CsvImportService(db);
      final result = await importer.importCsv(_csvContent!);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _importResult = result;
        });
        AppHaptics.success();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceFirst('FormatException: ', '');
        });
        AppHaptics.warning();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10121A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF262B3D) : const Color(0xFFE2E4EE),
            width: 1.2,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.file_upload_outlined, color: context.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Import Workout History', style: AppTypography.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Migrate from Hevy, Strong, FitNotes or CSV',
                      style: AppTypography.labelSmall.copyWith(color: context.textTertiary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_importResult != null) ...[
            // Success view
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Import Completed Successfully',
                    style: AppTypography.titleMedium.copyWith(color: AppColors.success),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricPill('Workouts', '${_importResult!.workoutsImported}'),
                      _buildMetricPill('Sets', '${_importResult!.setsImported}'),
                      _buildMetricPill('Lifts Matched', '${_importResult!.exercisesMatched}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassButton(
              text: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ] else ...[
            // Selection / preview view
            if (_selectedFileName == null) ...[
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161924) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.accent.withValues(alpha: 0.4),
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.upload_file_rounded, size: 40, color: context.accent),
                      const SizedBox(height: 12),
                      Text('Select CSV File', style: AppTypography.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Supports exports from Hevy, Strong, FitNotes (Android/iOS) and custom spreadsheets',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSmall.copyWith(color: context.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              GlassContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_rounded, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedFileName!,
                            style: AppTypography.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: _pickFile,
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Detected Format:', style: AppTypography.labelMedium.copyWith(color: context.textSecondary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _detectedSource ?? 'CSV',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Set Entries:', style: AppTypography.labelMedium.copyWith(color: context.textSecondary)),
                        Text(
                          '${_previewRowCount ?? 0}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                GlassButton(
                  text: 'Import All Workouts',
                  icon: Icons.check_circle_rounded,
                  onPressed: _executeImport,
                ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.success)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: context.textTertiary)),
      ],
    );
  }
}
