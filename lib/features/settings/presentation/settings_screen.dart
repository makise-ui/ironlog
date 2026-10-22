import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../data/providers.dart';
import '../../../domain/services/backup_service.dart';
import '../../../domain/services/app_notification_service.dart';
import '../../../domain/models/ai_config_model.dart';
import '../../../domain/services/ai_assistant_service.dart';
import '../../../domain/services/wakelock_service.dart';
import 'csv_import_sheet.dart';
import '../../intro/presentation/onboarding_sheet.dart';
import '../../today/presentation/widgets/ai_assistant_sheet.dart';
import 'ai_settings_screen.dart';
import '../../../domain/services/app_update_service.dart';
import 'whats_new_sheet.dart';
import 'legal_disclaimers_sheet.dart';

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
  int _totalExercisesCount = 0;

  String _userAge = '25';
  String _userWeight = '75';
  String _userHeight = '178';
  String _userGoal = 'Build Muscle';
  String _userGender = 'Male';
  bool _aiNotificationsEnabled = true;
  bool _aiSuggestionsEnabled = true;
  bool _restTimerNotifsEnabled = true;
  bool _autoCheckUpdates = true;
  bool _isCheckingUpdates = false;

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
    final exercises = await ref.read(exerciseRepositoryProvider).getExercises();
    final warmupPref = await ref.read(settingsRepositoryProvider).getIncludeWarmupInVolume();

    final settingsRepo = ref.read(settingsRepositoryProvider);
    final age = await settingsRepo.getSetting('user_age') ?? '25';
    final weight = await settingsRepo.getSetting('user_weight') ?? '75';
    final height = await settingsRepo.getSetting('user_height') ?? '178';
    final goal = await settingsRepo.getSetting('user_goal') ?? 'Build Muscle';
    final gender = await settingsRepo.getSetting('user_gender') ?? 'Male';
    final aiNotifs = await settingsRepo.getAiNotificationsEnabled();
    final aiSuggestions = await settingsRepo.getAiSuggestionsEnabled();
    final restTimerNotifs = await settingsRepo.getRestTimerNotificationsEnabled();
    final autoCheck = await settingsRepo.getAutoCheckUpdates();

    if (mounted) {
      setState(() {
        _totalSetsCount = sets.length;
        _totalWorkoutsCount = workouts.length;
        _totalExercisesCount = exercises.length;
        _includeWarmup = warmupPref;
        _userAge = age;
        _userWeight = weight;
        _userHeight = height;
        _userGoal = goal;
        _userGender = gender;
        _aiNotificationsEnabled = aiNotifs;
        _aiSuggestionsEnabled = aiSuggestions;
        _restTimerNotifsEnabled = restTimerNotifs;
        _autoCheckUpdates = autoCheck;
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
        final bool isDowngrade = backupInfo.workoutCount < _totalWorkoutsCount;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDowngrade ? AppColors.error : context.cardBorder),
            ),
            title: Text(
              isDowngrade ? 'Restore Older Backup?' : 'Restore from Persistent Storage?',
              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found backup file in ${backupInfo.displayDirectory}:\n'
                  '• Workouts in backup: ${backupInfo.workoutCount}\n'
                  '• Logged sets in backup: ${backupInfo.setCount}'
                  '${backupInfo.athleteName != null && backupInfo.athleteName!.isNotEmpty ? '\n• Athlete: ${backupInfo.athleteName}' : ''}',
                  style: TextStyle(color: context.textSecondary, fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDowngrade
                        ? AppColors.error.withValues(alpha: 0.12)
                        : context.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isDowngrade
                        ? 'Warning: Your current app has $_totalWorkoutsCount workouts and $_totalSetsCount sets. Restoring will replace them with this older backup (${backupInfo.workoutCount} workouts).'
                        : 'Active app database has $_totalWorkoutsCount workouts and $_totalSetsCount sets. Restoring will reload your data.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDowngrade ? AppColors.error : context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDowngrade ? AppColors.error : context.accent,
                  foregroundColor: context.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isDowngrade ? 'Restore Anyway' : 'Restore Progress'),
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

  Future<void> _checkAppUpdates() async {
    setState(() => _isCheckingUpdates = true);
    AppHaptics.tap();
    try {
      final res = await ref.read(appUpdateServiceProvider).checkForUpdates(isManual: true);
      if (mounted && context.mounted) {
        if (res.isUpdateAvailable) {
          WhatsNewSheet.show(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('IronLog is up to date (${AppUpdateService.currentVersion})!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdates = false);
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
          _buildSectionCard(
            title: 'AI COACH & INTELLIGENCE',
            children: [
              _buildRowItem(
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.accent,
                        AppColors.accentViolet,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: context.accent.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 18),
                ),
                titleWidget: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'AI Assistant & Profiles',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
                subtitleWidget: Text(
                  '${_aiConfig.name} • ${_aiConfig.modelName}',
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(Icons.chevron_right_rounded, size: 18, color: context.textTertiary),
                onTap: () async {
                  AppHaptics.tap();
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                  );
                  _loadAiConfig();
                },
              ),
              _buildDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCompactActionButton(
                        text: 'Open Chat',
                        icon: Icons.chat_bubble_outline_rounded,
                        isPrimary: true,
                        onPressed: () => AiAssistantSheet.show(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactActionButton(
                        text: 'Test Alert',
                        icon: Icons.notifications_active_outlined,
                        onPressed: () async {
                          AppHaptics.step();
                          await AppNotificationService.instance.sendContextualAiSuggestion(
                            ref.read(workoutRepositoryProvider),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('AI Coaching suggestion sent! Check notification shade.'),
                                backgroundColor: context.isDark ? const Color(0xFF2B2B2B) : const Color(0xFF3F3F46),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              _buildSwitchRow(
                title: 'AI Background Alerts',
                subtitle: 'Notify when AI completes while app is minimized',
                value: _aiNotificationsEnabled,
                onChanged: (val) async {
                  AppHaptics.tap();
                  setState(() => _aiNotificationsEnabled = val);
                  await ref.read(settingsRepositoryProvider).setAiNotificationsEnabled(val);
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                title: 'Automatic AI Suggestions',
                subtitle: 'Daily coach tips, streak motivation & workouts',
                value: _aiSuggestionsEnabled,
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
              _buildDivider(),
              _buildSwitchRow(
                title: 'Rest Timer Notifications',
                subtitle: 'Alert when rest countdown ends in background',
                value: _restTimerNotifsEnabled,
                onChanged: (val) async {
                  AppHaptics.tap();
                  setState(() => _restTimerNotifsEnabled = val);
                  await ref.read(settingsRepositoryProvider).setRestTimerNotificationsEnabled(val);
                },
              ),
            ],
          ),

          // ── Category 2: Workout & Training ───────────────────────
          _buildSectionCard(
            title: 'WORKOUT & TRAINING',
            children: [
              _buildRowItem(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_rounded, size: 18, color: context.accent),
                ),
                titleWidget: const Text(
                  'Personal Profile',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitleWidget: Text(
                  '$_userAge yrs • $_userWeight ${unit.name} • $_userHeight cm • $_userGender • $_userGoal',
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(Icons.chevron_right_rounded, size: 18, color: context.textTertiary),
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => const OnboardingSheet(),
                  );
                  _loadStats();
                },
              ),
              _buildDivider(),
              _buildRowItem(
                titleWidget: const Text(
                  'Weight Unit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitleWidget: Text(
                  'Default unit used for logs and metrics',
                  style: TextStyle(fontSize: 11.5, color: context.textTertiary),
                ),
                trailing: _buildUnitSegment(unit),
              ),
              _buildDivider(),
              _buildSwitchRow(
                title: 'Include Warm-ups in Volume',
                subtitle: 'Count warm-up sets towards total volume',
                value: _includeWarmup,
                onChanged: (val) async {
                  AppHaptics.step();
                  setState(() => _includeWarmup = val);
                  await ref.read(settingsRepositoryProvider).setIncludeWarmupInVolume(val);
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                title: 'Keep Screen Awake',
                subtitle: 'Prevent display from sleeping during workouts',
                value: ref.watch(keepScreenAwakeProvider),
                onChanged: (val) async {
                  AppHaptics.step();
                  await ref.read(keepScreenAwakeProvider.notifier).setEnabled(val);
                },
              ),
            ],
          ),

          // ── Category 3: Appearance & Theme ───────────────────────
          _buildSectionCard(
            title: 'APPEARANCE & THEME',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Theme Mode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          currentTheme == ThemeMode.dark
                              ? 'Dark'
                              : (currentTheme == ThemeMode.light ? 'Light' : 'System'),
                          style: TextStyle(fontSize: 12, color: context.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildThemeSegmentBar(currentTheme),
                  ],
                ),
              ),
              _buildDivider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Accent Theme',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          AppColors.accentPresets[currentPreset]?.name ?? 'Cobalt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? previewColor.withValues(alpha: context.isDark ? 0.22 : 0.14)
                                  : context.chipBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? previewColor : context.chipBorder,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: previewColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  data.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? context.textPrimary : context.textSecondary,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.check_rounded, size: 12, color: previewColor),
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
            ],
          ),

          // ── Category 4: Database & Performance ────────────────────
          _buildSectionCard(
            title: 'DATABASE & PERFORMANCE',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storage_rounded, size: 18, color: context.accent),
                            const SizedBox(width: 8),
                            Text(
                              'Local SQLite Database',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.isDark ? C.surfaceHi : const Color(0xFFF0F0F1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: context.isDark ? C.hairline : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Offline-First',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: context.cardElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.cardBorder),
                      ),
                      child: Row(
                        children: [
                          _buildMiniStat('Workouts', '$_totalWorkoutsCount'),
                          _buildMiniStatDivider(),
                          _buildMiniStat('Logged Sets', '$_totalSetsCount'),
                          _buildMiniStatDivider(),
                          _buildMiniStat('Exercises', '$_totalExercisesCount'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Backup to Phone',
                            icon: Icons.save_alt_rounded,
                            isPrimary: true,
                            isLoading: _isBackingUp,
                            onPressed: _backupToPhoneStorage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Restore Progress',
                            icon: Icons.settings_backup_restore_rounded,
                            isLoading: _isRestoring,
                            onPressed: _restoreFromPhoneStorage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Export Backup',
                            icon: Icons.share_rounded,
                            onPressed: _exportBackupFile,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Import File',
                            icon: Icons.file_upload_outlined,
                            onPressed: _importBackupFile,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Import CSV',
                            icon: Icons.table_chart_outlined,
                            onPressed: () {
                              AppHaptics.tap();
                              CsvImportSheet.show(context).then((_) => _loadStats());
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Load 1.3k Catalog',
                            icon: Icons.library_add_rounded,
                            onPressed: () async {
                              AppHaptics.tap();
                              final added = await ref.read(exerciseRepositoryProvider).seedOpenGymCatalog();
                              await _loadStats();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(added > 0
                                        ? 'Successfully added $added new movements! Total: $_totalExercisesCount'
                                        : 'All 1,324 movements already present in catalog.'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCompactActionButton(
                      text: 'Remove Test Data / Clear History',
                      icon: Icons.delete_sweep_rounded,
                      isDanger: true,
                      isLoading: _isClearing,
                      onPressed: _showClearConfirmationDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Category 5: About IronLog & Updates ───────────────────
          _buildSectionCard(
            title: 'ABOUT IRONLOG & UPDATES',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.fitness_center_rounded, size: 20, color: context.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'IronLog ${AppUpdateService.currentVersion}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: context.accent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Latest',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.onAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Offline-first gym tracker • Drift SQLite',
                            style: TextStyle(fontSize: 11.5, color: context.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCompactActionButton(
                        text: "What's New",
                        icon: Icons.auto_awesome_rounded,
                        isPrimary: true,
                        onPressed: () {
                          AppHaptics.tap();
                          WhatsNewSheet.show(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactActionButton(
                        text: 'Check Update',
                        icon: Icons.refresh_rounded,
                        isLoading: _isCheckingUpdates,
                        onPressed: _checkAppUpdates,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              _buildSwitchRow(
                title: 'Auto-Check Updates',
                subtitle: 'Notify when feature updates and patches land',
                value: _autoCheckUpdates,
                onChanged: (val) async {
                  AppHaptics.selection();
                  setState(() => _autoCheckUpdates = val);
                  await ref.read(settingsRepositoryProvider).setAutoCheckUpdates(val);
                },
              ),
              _buildDivider(),
              _buildRowItem(
                titleWidget: const Text(
                  'Replay Onboarding Guide',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                leading: Icon(Icons.school_outlined, size: 18, color: context.textSecondary),
                trailing: Icon(Icons.chevron_right_rounded, size: 18, color: context.textTertiary),
                onTap: () {
                  AppHaptics.tap();
                  showModalBottomSheet(
                    context: context,
                    useRootNavigator: true,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => const OnboardingSheet(),
                  );
                },
              ),
              _buildDivider(),
              _buildRowItem(
                titleWidget: const Text(
                  'Legal & Safety Disclaimers',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                leading: Icon(Icons.gavel_rounded, size: 18, color: context.textSecondary),
                trailing: Icon(Icons.chevron_right_rounded, size: 18, color: context.textTertiary),
                onTap: () {
                  AppHaptics.tap();
                  LegalDisclaimersSheet.show(context);
                },
              ),
            ],
          ),

          const SizedBox(height: 100),
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

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontSize: 11,
              color: context.textTertiary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.cardBorder),
            boxShadow: context.isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    const BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.cardBorder.withValues(alpha: 0.6),
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildRowItem({
    required Widget titleWidget,
    Widget? subtitleWidget,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  }) {
    final content = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleWidget,
                if (subtitleWidget != null) ...[
                  const SizedBox(height: 2),
                  subtitleWidget,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildSwitchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildRowItem(
      titleWidget: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
      subtitleWidget: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: context.textTertiary,
              ),
            )
          : null,
      trailing: Transform.scale(
        scale: 0.85,
        alignment: Alignment.centerRight,
        child: Switch.adaptive(
          value: value,
          activeTrackColor: context.accent,
          activeThumbColor: context.isDark ? const Color(0xFF171717) : Colors.white,
          inactiveThumbColor: context.textTertiary,
          inactiveTrackColor: context.isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCompactActionButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isPrimary = false,
    bool isDanger = false,
    bool isLoading = false,
  }) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isPrimary) {
      bgColor = context.accent.withValues(alpha: context.isDark ? 0.18 : 0.12);
      borderColor = context.accent.withValues(alpha: 0.35);
      textColor = context.accent;
    } else if (isDanger) {
      bgColor = AppColors.error.withValues(alpha: context.isDark ? 0.12 : 0.08);
      borderColor = AppColors.error.withValues(alpha: 0.3);
      textColor = context.isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    } else {
      bgColor = context.cardElevated;
      borderColor = context.cardBorder;
      textColor = context.textPrimary;
    }

    return ScaleTap(
      onPressed: isLoading ? null : onPressed,
      scaleDown: 0.96,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: textColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildUnitSegment(WeightUnit currentUnit) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.cardBorder),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUnitOption('KG', currentUnit == WeightUnit.kg),
          _buildUnitOption('LB', currentUnit == WeightUnit.lb),
        ],
      ),
    );
  }

  Widget _buildUnitOption(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          AppHaptics.step();
          ref.read(weightUnitNotifierProvider.notifier).toggle();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? context.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? context.onAccent : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSegmentBar(ThemeMode currentTheme) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cardBorder),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _buildThemeSegment('Dark', Icons.dark_mode_rounded, currentTheme == ThemeMode.dark, () {
            ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
          }),
          _buildThemeSegment('Light', Icons.light_mode_rounded, currentTheme == ThemeMode.light, () {
            ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
          }),
          _buildThemeSegment('System', Icons.brightness_auto_rounded, currentTheme == ThemeMode.system, () {
            ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
          }),
        ],
      ),
    );
  }

  Widget _buildThemeSegment(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.step();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? context.accent.withValues(alpha: context.isDark ? 0.22 : 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: isSelected ? Border.all(color: context.accent.withValues(alpha: 0.4), width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? context.accent : context.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
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

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatDivider() {
    return Container(
      height: 22,
      width: 1,
      color: context.cardBorder,
    );
  }
}
