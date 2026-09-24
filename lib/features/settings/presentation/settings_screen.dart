import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../data/providers.dart';
import '../../../domain/services/backup_service.dart';
import '../../../domain/services/app_notification_service.dart';
import '../../../domain/models/ai_config_model.dart';
import '../../../domain/services/ai_assistant_service.dart';
import '../../intro/presentation/onboarding_sheet.dart';
import '../../today/presentation/widgets/ai_assistant_sheet.dart';
import 'ai_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _includeWarmup = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isClearing = false;
  int _totalSetsCount = 0;
  int _totalWorkoutsCount = 0;

  String _userAge = '25';
  String _userWeight = '75';
  String _userHeight = '178';
  String _userGoal = 'Build Muscle';
  String _userGender = 'Male';
  bool _aiNotificationsEnabled = true;
  bool _aiSuggestionsEnabled = true;

  AiConfigModel _aiConfig = const AiConfigModel();

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadAiConfig();
  }

  Future<void> _loadAiConfig() async {
    final cfg = await ref.read(aiAssistantServiceProvider).getConfig();
    if (mounted) {
      setState(() {
        _aiConfig = cfg;
      });
    }
  }

  Future<void> _loadStats() async {
    final db = ref.read(databaseProvider);
    final sets = await (db.select(db.sets)..where((t) => t.archived.equals(false))).get();
    final workouts = await (db.select(db.workouts)..where((t) => t.archived.equals(false))).get();
    final warmupPref = await ref.read(settingsRepositoryProvider).getIncludeWarmupInVolume();

    final settingsRepo = ref.read(settingsRepositoryProvider);
    final age = await settingsRepo.getSetting('user_age') ?? '25';
    final weight = await settingsRepo.getSetting('user_weight') ?? '75';
    final height = await settingsRepo.getSetting('user_height') ?? '178';
    final goal = await settingsRepo.getSetting('user_goal') ?? 'Build Muscle';
    final gender = await settingsRepo.getSetting('user_gender') ?? 'Male';
    final aiNotifs = await settingsRepo.getAiNotificationsEnabled();
    final aiSuggestions = await settingsRepo.getAiSuggestionsEnabled();

    if (mounted) {
      setState(() {
        _totalSetsCount = sets.length;
        _totalWorkoutsCount = workouts.length;
        _includeWarmup = warmupPref;
        _userAge = age;
        _userWeight = weight;
        _userHeight = height;
        _userGoal = goal;
        _userGender = gender;
        _aiNotificationsEnabled = aiNotifs;
        _aiSuggestionsEnabled = aiSuggestions;
      });
    }
  }

  Future<void> _backupToPhoneStorage() async {
    AppHaptics.save();
    setState(() => _isBackingUp = true);

    try {
      final db = ref.read(databaseProvider);
      final path = await BackupService.autoBackup(db);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(path != null
                ? 'Backed up to phone storage at:\n$path'
                : 'Progress backed up successfully!'),
            backgroundColor: context.isDark ? const Color(0xFF2B2B2B) : const Color(0xFF3F3F46),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error backing up: $e');
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreFromPhoneStorage() async {
    AppHaptics.save();
    setState(() => _isRestoring = true);

    try {
      final backupInfo = await BackupService.findExistingBackup();
      if (backupInfo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No backup found in phone Download/IronLog or Documents/IronLog'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: context.cardBorder),
            ),
            title: Text('Restore from Persistent Storage?', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
            content: Text(
              'Found backup file in ${backupInfo.displayDirectory}:\n'
              '• Workouts: ${backupInfo.workoutCount}\n'
              '• Logged Sets: ${backupInfo.setCount}'
              '${backupInfo.athleteName != null && backupInfo.athleteName!.isNotEmpty ? '\n• Athlete: ${backupInfo.athleteName}' : ''}\n\n'
              'Restoring will load your progress back into the app.',
              style: TextStyle(color: context.textSecondary, fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: context.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Restore Progress'),
              ),
            ],
          ),
        );

        if (confirm == true && mounted) {
          final db = ref.read(databaseProvider);
          final file = File(backupInfo.path);
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          final count = await BackupService.restoreFromJson(db, data);
          await _loadStats();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully restored $count workouts from phone storage!'),
                backgroundColor: context.isDark ? const Color(0xFF2B2B2B) : const Color(0xFF3F3F46),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error restoring backup: $e');
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _exportBackupFile() async {
    AppHaptics.save();
    try {
      final db = ref.read(databaseProvider);
      await BackupService.exportBackupFile(db);
    } catch (e) {
      debugPrint('Error exporting backup: $e');
    }
  }

  Future<void> _importBackupFile() async {
    AppHaptics.save();
    try {
      final db = ref.read(databaseProvider);
      final count = await BackupService.importBackupFile(db);
      if (count != null) {
        await _loadStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported $count workouts from backup file!'),
              backgroundColor: context.isDark ? const Color(0xFF2B2B2B) : const Color(0xFF3F3F46),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error importing backup: $e');
    }
  }



  void _showClearConfirmationDialog() {
    AppHaptics.warning();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.cardBorder),
        ),
        title: Text('Remove Test Data?', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'This will remove all logged workouts, test sets, and exercise history. Default exercises and routines will remain untouched.',
          style: TextStyle(color: context.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _clearTestData();
            },
            child: const Text('Remove Test Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearTestData() async {
    AppHaptics.warning();
    setState(() => _isClearing = true);

    try {
      final db = ref.read(databaseProvider);
      await db.transaction(() async {
        await db.delete(db.sets).go();
        await db.delete(db.workoutExercises).go();
        await db.delete(db.workouts).go();
        await db.delete(db.prs).go();
      });
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All test data and logged sessions removed successfully!'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing test data: $e');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitNotifierProvider);
    final currentTheme = ref.watch(themeModeProvider);
    final currentPreset = ref.watch(accentPresetProvider);
    final canPop = Navigator.of(context).canPop();

    final content = SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          Row(
            children: [
              if (canPop) ...[
                ScaleTap(
                  onPressed: () {
                    AppHaptics.tap();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.cardBorder),
                    ),
                    child: Icon(Icons.arrow_back_rounded, color: context.textPrimary, size: 20),
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: T.display.copyWith(color: C.text1)),
                    const SizedBox(height: 2),
                    Text('App preferences, units & storage', style: T.body.copyWith(fontSize: 13, color: C.text2)),
                  ],
                ),
              ),
              ScaleTap(
                onPressed: () => AiAssistantSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: context.accent),
                      const SizedBox(width: 4),
                      Text(
                        'AI Coach',
                        style: TextStyle(
                          color: context.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Category 1: AI Coach & Intelligence ──────────────────
          const Text('AI COACH & INTELLIGENCE', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            onTap: () async {
              AppHaptics.tap();
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
              _loadAiConfig();
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.accent,
                        AppColors.accentViolet,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: context.accent.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'AI Assistant & Profiles',
                              style: AppTypography.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: !_aiConfig.requireApiKey
                                  ? AppColors.workingSet.withValues(alpha: 0.16)
                                  : (_aiConfig.apiKey.isNotEmpty
                                      ? context.accent.withValues(alpha: 0.16)
                                      : context.chipBg),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              !_aiConfig.requireApiKey
                                  ? 'Free'
                                  : (_aiConfig.apiKey.isNotEmpty ? 'Active' : 'No Key'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: !_aiConfig.requireApiKey
                                    ? AppColors.workingSet
                                    : (_aiConfig.apiKey.isNotEmpty ? context.accent : context.textTertiary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_aiConfig.name} • ${_aiConfig.modelName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI Coach Chat', style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Launch workout coach & live app controller',
                        style: AppTypography.labelSmall.copyWith(color: context.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: const Text('Open Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accent,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => AiAssistantSheet.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Category: Notifications & AI Alerts ───────────────────
          const Text('NOTIFICATIONS & AI ALERTS', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI Background Alerts', style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Notify when AI finishes responding while app is minimized',
                        style: AppTypography.labelSmall.copyWith(color: context.textTertiary),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _aiNotificationsEnabled,
                  activeTrackColor: context.accent,
                  onChanged: (val) async {
                    AppHaptics.tap();
                    setState(() => _aiNotificationsEnabled = val);
                    await ref.read(settingsRepositoryProvider).setAiNotificationsEnabled(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Automatic AI Suggestions', style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Daily coach tips, streak motivation & workout suggestions',
                        style: AppTypography.labelSmall.copyWith(color: context.textTertiary),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _aiSuggestionsEnabled,
                  activeTrackColor: context.accent,
                  onChanged: (val) async {
                    AppHaptics.tap();
                    setState(() => _aiSuggestionsEnabled = val);
                    await ref.read(settingsRepositoryProvider).setAiSuggestionsEnabled(val);
                    if (val) {
                      await AppNotificationService.instance.scheduleDailyCoachSuggestion();
                    } else {
                      await AppNotificationService.instance.cancelDailyCoachSuggestion();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Test AI Suggestion', style: AppTypography.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Preview an instant AI Coach suggestion notification',
                        style: AppTypography.labelSmall.copyWith(color: context.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.notifications_active_rounded, size: 14),
                  label: const Text('Test Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentViolet,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    AppHaptics.step();
                    await AppNotificationService.instance.sendContextualAiSuggestion(
                      ref.read(workoutRepositoryProvider),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('AI Coaching suggestion notification sent! Check notification shade.'),
                          backgroundColor: context.isDark ? const Color(0xFF2B2B2B) : const Color(0xFF3F3F46),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Category 2: Workout & Training ───────────────────────
          const Text('WORKOUT & TRAINING', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const OnboardingSheet(),
              );
              _loadStats();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Personal Profile', style: AppTypography.titleMedium),
                    Text('Tap to Edit', style: TextStyle(color: context.textTertiary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStatPill('Age', '$_userAge yrs'),
                    const SizedBox(width: AppSpacing.sm),
                    _buildStatPill('Weight', '$_userWeight ${unit.name}'),
                    const SizedBox(width: AppSpacing.sm),
                    _buildStatPill('Height', '$_userHeight cm'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$_userGender • $_userGoal',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          GlassTile(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weight Unit', style: AppTypography.titleMedium),
                      SizedBox(height: 2),
                      Text('Default unit used for logs and metrics', style: AppTypography.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    AppHaptics.step();
                    ref.read(weightUnitNotifierProvider.notifier).toggle();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.cardElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(
                        color: context.cardBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      unit.name.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          GlassTile(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Include Warm-ups in Volume', style: AppTypography.titleMedium),
                      SizedBox(height: 2),
                      Text('Count warm-up sets towards total volume', style: AppTypography.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _includeWarmup,
                  activeThumbColor: context.isDark ? const Color(0xFF171717) : Colors.white,
                  activeTrackColor: context.accent,
                  inactiveThumbColor: context.textTertiary,
                  inactiveTrackColor: context.isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
                  onChanged: (val) async {
                    AppHaptics.step();
                    setState(() => _includeWarmup = val);
                    await ref.read(settingsRepositoryProvider).setIncludeWarmupInVolume(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Category 3: Appearance & Theme ───────────────────────
          const Text('APPEARANCE & THEME', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Appearance Mode', style: AppTypography.titleMedium),
                    Text('Dark / Light', style: AppTypography.labelSmall),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildThemeOption(
                      label: 'Dark',
                      icon: Icons.dark_mode_rounded,
                      isSelected: currentTheme == ThemeMode.dark,
                      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                    ),
                    const SizedBox(width: 8),
                    _buildThemeOption(
                      label: 'Light',
                      icon: Icons.light_mode_rounded,
                      isSelected: currentTheme == ThemeMode.light,
                      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                    ),
                    const SizedBox(width: 8),
                    _buildThemeOption(
                      label: 'System',
                      icon: Icons.brightness_auto_rounded,
                      isSelected: currentTheme == ThemeMode.system,
                      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: context.cardBorder),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Accent Theme', style: AppTypography.titleMedium),
                    Text(
                      AppColors.accentPresets[currentPreset]?.name ?? 'Cobalt Sapphire',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AccentPreset.values.map((preset) {
                    final data = AppColors.accentPresets[preset]!;
                    final isSelected = currentPreset == preset;
                    final previewColor = context.isDark ? data.darkColor : data.lightColor;
                    return GestureDetector(
                      onTap: () {
                        AppHaptics.mediumImpact();
                        ref.read(accentPresetProvider.notifier).setPreset(preset);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? previewColor.withValues(alpha: context.isDark ? 0.20 : 0.12)
                              : context.chipBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? previewColor : context.chipBorder,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: previewColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              data.name,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? context.textPrimary : context.textSecondary,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 5),
                              Icon(Icons.check_rounded, size: 14, color: previewColor),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Database & Debug Seeder
          const Text('DATABASE & PERFORMANCE', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Local SQLite Database', style: AppTypography.titleMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.isDark ? C.surfaceHi : const Color(0xFFF0F0F1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: context.isDark ? C.hairline : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Offline-First',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _buildStatPill('Workouts', '$_totalWorkoutsCount'),
                    const SizedBox(width: AppSpacing.sm),
                    _buildStatPill('Logged Sets', '$_totalSetsCount'),
                    const SizedBox(width: AppSpacing.sm),
                    _buildStatPill('Exercises', '162'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Auto-saves your workouts to persistent storage (Documents/IronLog). Even if you delete and reinstall the app, IronLog will detect your backup and ask to restore your progress.',
                  style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassButton(
                  text: 'Backup Now to Persistent Storage',
                  icon: Icons.save_alt_rounded,
                  style: GlassButtonStyle.primary,
                  isLoading: _isBackingUp,
                  onPressed: _backupToPhoneStorage,
                ),
                const SizedBox(height: 8),
                GlassButton(
                  text: 'Restore from Persistent Storage',
                  icon: Icons.settings_backup_restore_rounded,
                  style: GlassButtonStyle.secondary,
                  isLoading: _isRestoring,
                  onPressed: _restoreFromPhoneStorage,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        text: 'Export Backup',
                        icon: Icons.share_rounded,
                        style: GlassButtonStyle.secondary,
                        onPressed: _exportBackupFile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        text: 'Import File',
                        icon: Icons.file_upload_outlined,
                        style: GlassButtonStyle.secondary,
                        onPressed: _importBackupFile,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassButton(
                  text: 'Remove Test Data / Clear History',
                  icon: Icons.delete_sweep_rounded,
                  style: GlassButtonStyle.danger,
                  isLoading: _isClearing,
                  onPressed: _showClearConfirmationDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          const Text('ABOUT IRONLOG', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('IronLog v1.0.0', style: AppTypography.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '100% Offline-first gym tracker built with Flutter, Drift (SQLite), and glassmorphic UI. Zero internet permission requested for core tracking.',
                  style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                ),
                const SizedBox(height: 10),
                GlassButton(
                  text: 'Replay Onboarding Guide',
                  icon: Icons.school_outlined,
                  style: GlassButtonStyle.secondary,
                  onPressed: () {
                    AppHaptics.tap();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => const OnboardingSheet(),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 120),
        ],
      ),
    );

    if (canPop) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: content,
      );
    }
    return content;
  }

  Widget _buildStatPill(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: ScaleTap(
        onPressed: onTap,
        scaleDown: 0.94,
        enableHaptic: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accent.withValues(alpha: context.isDark ? 0.16 : 0.10)
                : context.chipBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? context.accent : context.chipBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: isSelected ? context.accent : context.textSecondary),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? context.textPrimary : context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
