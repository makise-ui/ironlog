import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../data/providers.dart';
import '../../../domain/services/app_update_service.dart';

class WhatsNewSheet extends ConsumerStatefulWidget {
  const WhatsNewSheet({super.key});

  static Future<void> show(BuildContext context) {
    AppHaptics.tap();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WhatsNewSheet(),
    );
  }

  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final updateService = ref.read(appUpdateServiceProvider);
    final shouldShow = await updateService.shouldShowWhatsNew();
    if (shouldShow && context.mounted) {
      await updateService.markCurrentVersionSeen();
      if (context.mounted) {
        show(context);
      }
    }
  }

  @override
  ConsumerState<WhatsNewSheet> createState() => _WhatsNewSheetState();
}

class _WhatsNewSheetState extends ConsumerState<WhatsNewSheet> {
  bool _autoCheckUpdates = true;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await ref.read(settingsRepositoryProvider).getAutoCheckUpdates();
    if (mounted) {
      setState(() => _autoCheckUpdates = enabled);
    }
  }

  Future<void> _toggleAutoCheck(bool value) async {
    AppHaptics.selection();
    setState(() => _autoCheckUpdates = value);
    await ref.read(settingsRepositoryProvider).setAutoCheckUpdates(value);
  }

  Future<void> _checkNow() async {
    setState(() => _isChecking = true);
    AppHaptics.tap();

    try {
      final updateService = ref.read(appUpdateServiceProvider);
      final result = await updateService.checkForUpdates(isManual: true);

      if (!mounted) return;

      if (result.isUpdateAvailable) {
        _showUpdateAvailableDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('You are on the latest version (${AppUpdateService.currentVersion})!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _showUpdateAvailableDialog(UpdateCheckResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: context.accent, size: 24),
            const SizedBox(width: 10),
            const Text('Update Available!', style: AppTypography.titleMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version (${result.latestVersion}) of IronLog is ready to install.',
              style: TextStyle(color: context.textPrimary, fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            Text(
              'Your Current Version: ${result.currentVersion}',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Later', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accent,
              foregroundColor: context.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (result.downloadUrl != null) {
                launchUrl(Uri.parse(result.downloadUrl!), mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Download Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final release = AppUpdateService.currentRelease;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: context.cardBorder)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.textTertiary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: context.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('What\'s New', style: AppTypography.titleLarge),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              release.version,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.onAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${release.title} • ${release.releaseDate}',
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: context.textSecondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Release Highlights List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              children: [
                // Summary Callout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: context.isDark ? 0.08 : 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, size: 20, color: context.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          release.summary,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text('NEW FEATURES & UPGRADES', style: AppTypography.labelSmall),
                const SizedBox(height: 10),

                ...release.highlights.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassTile(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon, size: 20, color: context.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                    if (item.tag != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: item.tag == 'NEW'
                                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                              : (item.tag == 'FIX'
                                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                                  : context.accent.withValues(alpha: 0.2)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.tag!,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: item.tag == 'NEW'
                                                ? const Color(0xFF10B981)
                                                : (item.tag == 'FIX'
                                                    ? const Color(0xFFF59E0B)
                                                    : context.accent),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 10),
                const Text('UPDATES & PREFERENCES', style: AppTypography.labelSmall),
                const SizedBox(height: 10),

                // Auto Check for Updates Switch Tile
                GlassTile(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.sync_rounded, size: 20, color: context.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto-Check for Updates',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Notify when new features and performance fixes are available',
                              style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoCheckUpdates,
                        activeThumbColor: context.accent,
                        onChanged: _toggleAutoCheck,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              border: Border(top: BorderSide(color: context.cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GlassButton(
                    text: 'Check Now',
                    icon: Icons.refresh_rounded,
                    style: GlassButtonStyle.secondary,
                    isLoading: _isChecking,
                    onPressed: _checkNow,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: GlassButton(
                    text: 'Keep Training',
                    icon: Icons.fitness_center_rounded,
                    style: GlassButtonStyle.primary,
                    onPressed: () {
                      AppHaptics.save();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
