import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_tile.dart';
import '../../../data/providers.dart';
import '../../../data/database/debug_seeder.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _includeWarmup = false;
  bool _isSeeding = false;
  int _totalSetsCount = 0;
  int _totalWorkoutsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = ref.read(databaseProvider);
    final sets = await (db.select(db.sets)..where((t) => t.archived.equals(false))).get();
    final workouts = await (db.select(db.workouts)..where((t) => t.archived.equals(false))).get();
    final warmupPref = await ref.read(settingsRepositoryProvider).getIncludeWarmupInVolume();

    if (mounted) {
      setState(() {
        _totalSetsCount = sets.length;
        _totalWorkoutsCount = workouts.length;
        _includeWarmup = warmupPref;
      });
    }
  }

  Future<void> _runDebugSeeder() async {
    AppHaptics.save();
    setState(() => _isSeeding = true);

    try {
      final db = ref.read(databaseProvider);
      final count = await DebugSeeder.seedSixMonthsRealisticData(db);
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully generated $count sets across 6 months!'),
            backgroundColor: AppColors.accentCyan,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error running seeder: $e');
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitNotifierProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          const Text('Settings', style: AppTypography.displayMedium),
          const SizedBox(height: 2),
          const Text('App preferences, units & storage', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.lg),

          // Unit preference
          const Text('PREFERENCES', style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          GlassTile(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weight Unit', style: AppTypography.titleMedium),
                    SizedBox(height: 2),
                    Text('Default unit used for logs and metrics', style: AppTypography.labelSmall),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    AppHaptics.step();
                    ref.read(weightUnitNotifierProvider.notifier).toggle();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(color: AppColors.accentCyan, width: 1.2),
                    ),
                    child: Text(
                      unit.name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Include warmups in volume
          GlassTile(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Include Warm-ups in Volume', style: AppTypography.titleMedium),
                    SizedBox(height: 2),
                    Text('Count warm-up sets towards total volume', style: AppTypography.labelSmall),
                  ],
                ),
                Switch(
                  value: _includeWarmup,
                  activeThumbColor: AppColors.accentCyan,
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
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Text(
                        'Offline-First',
                        style: TextStyle(
                          color: AppColors.success,
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
                GlassButton(
                  text: 'Generate 6-Month Test Data (~5,000 sets)',
                  icon: Icons.speed_rounded,
                  style: GlassButtonStyle.secondary,
                  isLoading: _isSeeding,
                  onPressed: _runDebugSeeder,
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
                  '100% Offline-first gym tracker built with Flutter, Drift (SQLite), and glassmorphic UI. Zero internet permission requested.',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.glassBorderDim),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
