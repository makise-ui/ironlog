import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../../../../data/database/database.dart';
import '../../../../domain/models/routine_model.dart';
import '../../../../domain/services/plan_share_service.dart';
import 'routine_preview_sheet.dart';

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
  MobileScannerController? _scannerController;
  bool _isScanningHandled = false;
  bool _isTorchOn = false;
  String? _importError;

  bool get _isCameraSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    final initialTab = widget.routineToShare != null ? 1 : 0;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab,
    );

    if (_isCameraSupported) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _importController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onCodeDetected(String rawCode) {
    if (_isScanningHandled) return;
    final clean = rawCode.trim();
    if (clean.isEmpty) return;

    try {
      final preview = PlanShareService.parsePreview(clean);
      _isScanningHandled = true;
      AppHaptics.success();

      Navigator.pop(context); // Close the scanner dialog

      // Open the rich preview sheet for confirmation!
      RoutinePreviewSheet.showForScannedPreview(
        context,
        previewData: preview,
        hasActiveExercises: false,
        onImportConfirmed: (imported) {
          widget.onRoutineImported?.call(imported);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully imported "${imported.name}"!')),
          );
        },
      );
    } catch (e) {
      // Invalid QR code format scanned
      AppHaptics.warning();
      setState(() {
        _importError = 'Scanned QR code is not a valid IronLog workout routine.';
      });
    }
  }

  void _handleManualPreview() {
    final text = _importController.text.trim();
    if (text.isEmpty) return;

    setState(() => _importError = null);

    try {
      final preview = PlanShareService.parsePreview(text);
      AppHaptics.success();

      Navigator.pop(context);

      RoutinePreviewSheet.showForScannedPreview(
        context,
        previewData: preview,
        hasActiveExercises: false,
        onImportConfirmed: (imported) {
          widget.onRoutineImported?.call(imported);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully imported "${imported.name}"!')),
          );
        },
      );
    } catch (e) {
      AppHaptics.warning();
      setState(() {
        _importError = e.toString().replaceFirst('Exception: ', '').replaceFirst('FormatException: ', '');
      });
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: context.accent,
              labelColor: context.accent,
              unselectedLabelColor: context.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 18), text: 'Scan Camera'),
                Tab(icon: Icon(Icons.qr_code_2_rounded, size: 18), text: 'Share QR'),
                Tab(icon: Icon(Icons.paste_rounded, size: 18), text: 'Paste Code'),
              ],
            ),
            const SizedBox(height: 14),

            // Tab View Body
            SizedBox(
              height: 380,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // prevent camera swipe interference
                children: [
                  _buildCameraScanTab(),
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

  Widget _buildCameraScanTab() {
    if (!_isCameraSupported || _scannerController == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, size: 48, color: context.textSecondary),
              const SizedBox(height: 12),
              Text(
                'Live camera scanner is available on Android and iOS mobile devices.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the "Paste Code" tab to import your routine code on desktop.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: context.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _tabController.animateTo(2),
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Go to Paste Code'),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController!,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded, size: 40, color: Colors.amber),
                      const SizedBox(height: 8),
                      Text(
                        'Camera permission needed or camera unavailable.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final val = barcode.rawValue;
                if (val != null && val.isNotEmpty) {
                  _onCodeDetected(val);
                  break;
                }
              }
            },
          ),

          // Viewfinder Target Frame
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.accent, width: 2.5),
            ),
          ),

          // Torch & Helper Overlay
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_rounded, size: 15, color: Colors.white70),
                  const SizedBox(width: 6),
                  const Text(
                    'Point at another screen',
                    style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _scannerController?.toggleTorch();
                      setState(() => _isTorchOn = !_isTorchOn);
                    },
                    child: Icon(
                      _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isTorchOn ? Colors.amber : Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_importError != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _importError!,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShareTab() {
    if (widget.routineToShare == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center_rounded, size: 40, color: context.textSecondary),
              const SizedBox(height: 10),
              Text(
                'Select a routine from your library or today\'s session to share its QR code.',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
            size: 180.0,
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
        const SizedBox(height: 14),

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
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Paste a routine JSON code to preview its workouts and confirm import.',
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 12),

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
          onTap: _handleManualPreview,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: context.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_rounded, size: 18, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    'Preview & Confirm Import',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
