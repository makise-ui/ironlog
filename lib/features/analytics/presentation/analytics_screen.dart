import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../data/providers.dart';
import '../../../domain/models/analytics_model.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedDaysWindow = 7; // 7, 30, or 90
  bool _isLoading = true;
  bool _showAdvanced = false;

  AnalyticsOverviewData? _overview;
  List<DailyVolumeStat> _volumeStats = [];
  Map<String, int> _muscleSplit = {};
  List<PrItemData> _recentPrs = [];

  // Advanced analytics state
  List<WeeklyFrequencyStat> _weeklyFrequency = [];
  List<ExerciseVolumeStat> _topExercises = [];
  List<BestSetStat> _bestSets = [];
  Map<String, double> _avgReps = {};
  List<RepRangeStat> _repRanges = [];
  double _avgWorkoutDuration = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    final repo = ref.read(workoutRepositoryProvider);

    final overview = await repo.getAnalyticsOverview();
    final volumeStats = await repo.getDailyVolumeStats(days: _selectedDaysWindow);
    final muscleSplit = await repo.getMuscleGroupBreakdown(days: _selectedDaysWindow);
    final prs = await repo.getRecentPrs(limit: 8);

    // Advanced analytics queries
    final weeklyFreq = await repo.getWeeklyFrequency(weeks: 8);
    final topExercises = await repo.getTopExercisesByVolume(days: _selectedDaysWindow, limit: 5);
    final bestSets = await repo.getBestSetsPerExercise(days: _selectedDaysWindow);
    final avgReps = await repo.getAvgRepsPerMuscleGroup(days: _selectedDaysWindow);
    final repRanges = await repo.getRepRangeDistribution(days: _selectedDaysWindow);
    final avgDuration = await repo.getAvgWorkoutDurationMinutes(days: _selectedDaysWindow);

    if (mounted) {
      setState(() {
        _overview = overview;
        _volumeStats = volumeStats;
        _muscleSplit = muscleSplit;
        _recentPrs = prs;
        _weeklyFrequency = weeklyFreq;
        _topExercises = topExercises;
        _bestSets = bestSets;
        _avgReps = avgReps;
        _repRanges = repRanges;
        _avgWorkoutDuration = avgDuration;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadAnalytics,
        color: context.accent,
        backgroundColor: context.cardBg,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: S.xl,
                  right: S.xl,
                  top: S.md,
                  bottom: S.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analytics',
                            style: T.display.copyWith(color: C.text1),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Progression, training volume & records',
                            style: T.body.copyWith(fontSize: 13, color: C.text2),
                          ),
                        ],
                      ),
                    ),
                    // Time window filter pills + ADV toggle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: C.surfaceHi,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: C.hairline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildWindowPill(label: '7D', days: 7),
                              _buildWindowPill(label: '30D', days: 30),
                              _buildWindowPill(label: '90D', days: 90),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ScaleTap(
                          onPressed: () {
                            AppHaptics.step();
                            setState(() => _showAdvanced = !_showAdvanced);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: _showAdvanced ? AppColors.accentViolet : C.surfaceHi,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _showAdvanced ? AppColors.accentViolet : C.hairline,
                              ),
                              boxShadow: _showAdvanced
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accentViolet.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  size: 13,
                                  color: _showAdvanced ? Colors.white : C.text2,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ADV',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _showAdvanced ? Colors.white : C.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: context.accent),
                ),
              )
            else ...[
              // 0. Super-Zoomable Growth Timeline Hero Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                  child: ScaleTap(
                    onPressed: () {
                      AppHaptics.mediumImpact();
                      context.push('/analytics/timeline');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF2E1B4E),
                                  const Color(0xFF161F38),
                                ]
                              : [
                                  const Color(0xFFF3E8FF),
                                  const Color(0xFFE0E7FF),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.accentViolet.withValues(alpha: isDark ? 0.4 : 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentViolet.withValues(alpha: isDark ? 0.3 : 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accentViolet.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accentViolet,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_graph_rounded,
                              color: AppColors.accentViolet,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'GROWTH TIMELINE',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentEmerald.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ZOOMABLE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.accentEmerald,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Interactive pinch-to-zoom training journey with PRs, volume curves & inspection.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.accentViolet,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 1. Hero Overview Metrics Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              label: 'TOTAL VOLUME',
                              value: UnitConverter.formatWeight(_overview?.totalVolume ?? 0, unit: unit),
                              icon: Icons.fitness_center_rounded,
                              iconColor: context.accent,
                              context: context,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard(
                              label: 'WORKOUTS',
                              value: '${_overview?.totalWorkouts ?? 0}',
                              icon: Icons.event_available_rounded,
                              iconColor: AppColors.accentViolet,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              label: 'TOTAL SETS',
                              value: '${_overview?.totalSets ?? 0}',
                              icon: Icons.repeat_rounded,
                              iconColor: AppColors.accentEmerald,
                              context: context,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard(
                              label: 'ACTIVE STREAK',
                              value: '${_overview?.currentStreakDays ?? 0} Days',
                              icon: Icons.local_fire_department_rounded,
                              iconColor: AppColors.warning,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // 2. Volume Progression Bar Chart
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0x06000000),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bar_chart_rounded, color: context.textSecondary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'DAILY TRAINING VOLUME',
                              style: AppTypography.labelSmall.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              unit.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 180,
                          child: _buildVolumeBarChart(unit, isDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 3. Muscle Group Split Breakdown
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0x06000000),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pie_chart_rounded, color: context.textSecondary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'MUSCLE GROUP SPLIT',
                              style: AppTypography.labelSmall.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Last $_selectedDaysWindow Days',
                              style: TextStyle(fontSize: 11, color: context.textTertiary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_muscleSplit.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No sets recorded in this timeframe.',
                                style: TextStyle(color: context.textTertiary, fontSize: 12),
                              ),
                            ),
                          )
                        else
                          ..._buildMuscleSplitBars(context),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 4. Personal Records (PR) Hall of Fame
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0x06000000),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.emoji_events_rounded, color: context.textSecondary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'PERSONAL RECORDS',
                              style: AppTypography.labelSmall.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_recentPrs.length} Milestones',
                              style: const TextStyle(fontSize: 11, color: AppColors.prGold, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_recentPrs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Keep lifting! New PR achievements will appear here.',
                                style: TextStyle(color: context.textTertiary, fontSize: 12),
                              ),
                            ),
                          )
                        else
                          ..._recentPrs.map((pr) => _buildPrTile(pr, unit, context)),
                      ],
                    ),
                  ),
                ),
              ),


              // 5. ADVANCED ANALYTICS DRILLDOWN SECTION
              if (_showAdvanced) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                // Section Badge Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.accentViolet.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insights_rounded, size: 14, color: AppColors.accentViolet),
                              SizedBox(width: 6),
                              Text(
                                'ADVANCED DRILLDOWN & REPS',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentViolet,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Quick Advanced Metrics Row: Avg Duration, Active Exercises, Total Reps
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: 'AVG DURATION',
                            value: _avgWorkoutDuration > 0
                                ? '${_avgWorkoutDuration.toStringAsFixed(0)} min'
                                : '--',
                            icon: Icons.timer_outlined,
                            iconColor: AppColors.accentViolet,
                            context: context,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'TOTAL REPS',
                            value: '${_overview?.totalReps ?? 0}',
                            icon: Icons.repeat_one_rounded,
                            iconColor: context.accent,
                            context: context,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'EXERCISES',
                            value: '${_bestSets.length}',
                            icon: Icons.fitness_center_rounded,
                            iconColor: AppColors.accentEmerald,
                            context: context,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Rep Range Distribution (Strength, Hypertrophy, Endurance)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _buildSectionCard(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'REP RANGE DISTRIBUTION',
                      subtitle: 'Last $_selectedDaysWindow Days',
                      context: context,
                      child: _repRanges.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'No set data recorded in this window.',
                                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                                ),
                              ),
                            )
                          : Column(
                              children: _repRanges.map((r) => _buildRepRangeBar(r, context, isDark)).toList(),
                            ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Avg Reps per Muscle Group
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _buildSectionCard(
                      icon: Icons.analytics_rounded,
                      title: 'AVG REPS / MUSCLE GROUP',
                      subtitle: 'Last $_selectedDaysWindow Days',
                      context: context,
                      child: _avgReps.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'No rep data available.',
                                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                                ),
                              ),
                            )
                          : Column(
                              children: (_avgReps.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                                  .map((e) {
                                final color = AppColors.muscleGroupColors[e.key] ?? context.accent;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: context.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${e.value.toStringAsFixed(1)} reps/set',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.textPrimary,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Weekly Training Frequency (Last 8 Weeks)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _buildSectionCard(
                      icon: Icons.calendar_view_week_rounded,
                      title: 'WEEKLY TRAINING FREQUENCY',
                      subtitle: 'Last 8 Weeks',
                      context: context,
                      child: SizedBox(
                        height: 165,
                        child: _buildWeeklyFrequencyChart(isDark),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Top Exercises by Volume
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _buildSectionCard(
                      icon: Icons.leaderboard_rounded,
                      title: 'TOP EXERCISES BY VOLUME',
                      subtitle: 'Last $_selectedDaysWindow Days',
                      context: context,
                      child: _topExercises.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text('No exercises recorded',
                                    style: TextStyle(color: context.textTertiary, fontSize: 12)),
                              ),
                            )
                          : Column(
                              children: _topExercises.asMap().entries.map((e) {
                                final rank = e.key + 1;
                                final ex = e.value;
                                final maxVol = _topExercises.first.totalVolume;
                                final pct = maxVol > 0 ? (ex.totalVolume / maxVol) : 0.0;
                                final colors = [
                                  context.accent,
                                  AppColors.accentViolet,
                                  AppColors.accentEmerald,
                                  AppColors.warning,
                                  AppColors.error,
                                ];
                                final color = colors[e.key % colors.length];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '#$rank',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: color,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              ex.exerciseName,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: context.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            UnitConverter.formatWeight(ex.totalVolume, unit: unit),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: context.textPrimary,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${ex.setsCount}s',
                                            style: TextStyle(fontSize: 11, color: context.textTertiary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Stack(
                                          children: [
                                            Container(
                                              height: 5,
                                              color: isDark ? const Color(0xFF1A2234) : const Color(0xFFE5E5E5),
                                            ),
                                            FractionallySizedBox(
                                              widthFactor: pct.clamp(0.0, 1.0),
                                              child: Container(
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Best Sets (Est. 1RM Milestones)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _buildSectionCard(
                      icon: Icons.bolt_rounded,
                      title: 'BEST SETS & EST. 1RM',
                      subtitle: 'Last $_selectedDaysWindow Days',
                      context: context,
                      child: _bestSets.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text('No weighted sets recorded',
                                    style: TextStyle(color: context.textTertiary, fontSize: 12)),
                              ),
                            )
                          : Column(
                              children: _bestSets.map((s) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4F5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: context.cardBorder.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.exerciseName,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: context.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${DateFormat('MMM d').format(s.date)} • ${UnitConverter.formatWeight(s.weight, unit: unit)} × ${s.reps} reps',
                                              style: TextStyle(fontSize: 11, color: context.textTertiary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: context.accent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '~${UnitConverter.formatWeight(s.e1rm, unit: unit)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: context.accent,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWindowPill({required String label, required int days}) {
    final isSelected = _selectedDaysWindow == days;
    return ScaleTap(
      onPressed: () {
        AppHaptics.step();
        setState(() => _selectedDaysWindow = days);
        _loadAnalytics();
      },
      scaleDown: 0.94,
      enableHaptic: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? C.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? C.onAccent : C.text2,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x06000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeBarChart(WeightUnit unit, bool isDark) {
    if (_volumeStats.isEmpty) {
      return const Center(child: Text('No data for this timeframe'));
    }

    final maxVol = _volumeStats.map((e) => e.volume).reduce((a, b) => a > b ? a : b);
    final maxY = maxVol > 0 ? (maxVol * 1.25) : 1000.0;

    final barGroups = _volumeStats.asMap().entries.map((entry) {
      final idx = entry.key;
      final stat = entry.value;
      final isToday = DateFormat('yyyy-MM-dd').format(stat.date) == DateFormat('yyyy-MM-dd').format(DateTime.now());

      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: stat.volume,
            width: _selectedDaysWindow == 7 ? 22 : 6,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            color: isToday
                ? context.accent
                : context.accent.withValues(alpha: 0.35),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => context.cardElevated,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final stat = _volumeStats[group.x.toInt()];
              final dateStr = DateFormat('EEE, MMM d').format(stat.date);
              final volStr = UnitConverter.formatWeight(stat.volume, unit: unit);
              return BarTooltipItem(
                '$dateStr\n',
                const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                children: [
                  TextSpan(
                    text: '$volStr (${stat.setsCount} sets)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= _volumeStats.length) return const SizedBox.shrink();
                if (_selectedDaysWindow == 7) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('E').format(_volumeStats[idx].date).substring(0, 3),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  );
                } else {
                  if (idx % 5 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('d').format(_volumeStats[idx].date),
                        style: TextStyle(fontSize: 10, color: context.textTertiary),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
            strokeWidth: 0.8,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  List<Widget> _buildMuscleSplitBars(BuildContext context) {
    final totalSets = _muscleSplit.values.fold<int>(0, (a, b) => a + b);
    if (totalSets == 0) return [];

    final sortedEntries = _muscleSplit.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return sortedEntries.map((e) {
      final pct = (e.value / totalSets);
      final color = AppColors.muscleGroupColors[e.key] ?? context.accent;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  e.key,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${e.value} sets',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${(pct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    color: isDark ? const Color(0xFF1A2234) : const Color(0xFFE5E5E5),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPrTile(PrItemData pr, WeightUnit unit, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cardBorder, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF383838) : const Color(0xFFF0F0F1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.emoji_events_rounded, color: context.textSecondary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pr.exerciseName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${pr.formattedKind} • ${DateFormat('MMM d, yyyy').format(pr.achievedAt)}',
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF383838) : const Color(0xFFF0F0F1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF4A4A4A) : const Color(0xFFD4D4D4)),
            ),
            child: Text(
              UnitConverter.formatWeight(pr.value, unit: unit),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required BuildContext context,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.labelSmall.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(subtitle, style: TextStyle(fontSize: 11, color: context.textTertiary)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildRepRangeBar(RepRangeStat stat, BuildContext context, bool isDark) {
    Color barColor;
    if (stat.label == 'Strength') {
      barColor = context.accent;
    } else if (stat.label == 'Hypertrophy') {
      barColor = AppColors.accentEmerald;
    } else {
      barColor = AppColors.accentViolet;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: barColor),
              ),
              const SizedBox(width: 8),
              Text(
                stat.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${stat.rangeDescription})',
                style: TextStyle(fontSize: 11, color: context.textTertiary),
              ),
              const Spacer(),
              Text(
                '${stat.count} sets',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              const SizedBox(width: 6),
              Text(
                '(${(stat.percentage * 100).toStringAsFixed(0)}%)',
                style: TextStyle(fontSize: 11, color: context.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: isDark ? const Color(0xFF1A2234) : const Color(0xFFE5E5E5),
                ),
                FractionallySizedBox(
                  widthFactor: stat.percentage.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyFrequencyChart(bool isDark) {
    if (_weeklyFrequency.isEmpty) return const Center(child: Text('No data'));
    const maxY = 7.0;
    final barGroups = _weeklyFrequency.asMap().entries.map((e) {
      final count = e.value.workoutCount.toDouble();
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: count,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            color: count >= 4
                ? AppColors.accentEmerald
                : count >= 2
                    ? context.accent
                    : count > 0
                        ? context.accent.withValues(alpha: 0.45)
                        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5)),
          ),
        ],
      );
    }).toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
            strokeWidth: 0.8,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 2,
              getTitlesWidget: (val, _) => Text(
                val.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= _weeklyFrequency.length) return const SizedBox.shrink();
                final wk = _weeklyFrequency[idx];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d/M').format(wk.weekStart),
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => context.cardElevated,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final wk = _weeklyFrequency[group.x.toInt()];
              return BarTooltipItem(
                'Week of ${DateFormat('MMM d').format(wk.weekStart)}\n',
                const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                children: [
                  TextSpan(
                    text: '${wk.workoutCount} sessions',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
