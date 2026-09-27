import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../../../../data/database/database.dart';
import '../../../../domain/models/routine_model.dart';
import '../../../../domain/services/plan_share_service.dart';

class RoutineQrShareDialog extends StatefulWidget {
  final RoutineModel? routineToShare;
  final AppDatabase db;
  final Function(RoutineModel)? onRoutineImported;

  const RoutineQrShareDialog({
    super.key,
    this.routineToShare,
    required this.db,
    this.onRoutineImported,
  });

  static Future<void> show(
    BuildContext context, {
    RoutineModel? routineToShare,
    required AppDatabase db,
    Function(RoutineModel)? onRoutineImported,
  }) {
    AppHaptics.tap();
    return showDialog(
      context: context,
      builder: (ctx) => RoutineQrShareDialog(
        routineToShare: routineToShare,
        db: db,
        onRoutineImported: onRoutineImported,
      ),
    );
  }

  @override
  State<RoutineQrShareDialog> createState() => _RoutineQrShareDialogState();
}

class _RoutineQrShareDialogState extends State<RoutineQrShareDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _importController = TextEditingController();
  bool _isImporting = false;
  String? _importError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.routineToShare != null ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _importController.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    final text = _importController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importError = null;
    });

    try {
      final imported = await PlanShareService.importRoutineFromPayload(text, widget.db);
      AppHaptics.success();
      if (!mounted) return;
      Navigator.pop(context);
      widget.onRoutineImported?.call(imported);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported "${imported.name}"!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _importError = e.toString().replaceFirst('Exception: ', '');
      });
      AppHaptics.warning();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.cardBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: context.accent,
              labelColor: context.accent,
              unselectedLabelColor: context.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Share QR Code'),
                Tab(text: 'Import Code'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab View Body
            SizedBox(
              height: 380,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildShareTab(),
                  _buildImportTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareTab() {
    if (widget.routineToShare == null) {
      return Center(
        child: Text(
          'Select a routine from your library to generate its QR code.',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    final routine = widget.routineToShare!;
    final payload = PlanShareService.exportRoutineToPayload(routine);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          routine.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '${routine.items.length} exercises • Scan with IronLog',
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 14),

        // QR Code Container
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: 190.0,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: BouncyPressable(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: payload));
                  AppHaptics.tap();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Routine code copied to clipboard!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.cardBorder),
                  ),
                  child: Center(
                    child: Text(
                      'Copy Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BouncyPressable(
                onTap: () {
                  AppHaptics.tap();
                  Share.share(payload, subject: 'IronLog Routine: ${routine.name}');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: context.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'Share File',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImportTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Import Routine Code',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Paste a routine code shared by a gym partner or exported from IronLog.',
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 14),

        Expanded(
          child: TextField(
            controller: _importController,
            maxLines: null,
            expands: true,
            style: TextStyle(fontSize: 12, color: context.textPrimary, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'Paste {"ironlog_plan": 1, ...} here',
              hintStyle: TextStyle(color: context.textTertiary, fontSize: 12),
              filled: true,
              fillColor: context.isDark ? const Color(0xFF141721) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.accent),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (_importError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _importError!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.error),
            ),
          ),

        BouncyPressable(
          onTap: _isImporting ? null : _handleImport,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: context.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text(
                      'Import Routine into Library',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
