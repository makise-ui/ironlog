import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../domain/models/workout_model.dart';
import '../../../data/providers.dart';
import 'workout_detail_sheet.dart';
import '../../today/presentation/widgets/workout_telemetry_dial.dart';

enum HistoryViewMode { list, calendar }

/// Ultra-Luxury History Screen featuring:
/// 1. Biometric Monthly Telemetry Horizon Dock (volume, workouts, consistency, PRs)
/// 2. Stepped Obsidian Workout Cards with micro-telemetry chronograph dials
/// 3. Interactive Calendar with volume heat markers & day-synchronized scrubbing
/// 4. Smart Search & Multi-Filter Bar across workout titles & exercises
/// 5. Purposeful Active Neuromuscular Regeneration Rest Day cards
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryViewMode _viewMode = HistoryViewMode.calendar;
  String? _selectedMuscleGroupId;
  String _activePresetFilter = 'all'; // 'all', 'heavy', 'rest'
  List<WorkoutModel> _workouts = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedCalendarDay;

  // Search capabilities
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final repo = ref.read(workoutRepositoryProvider);
    final list = await repo.getHistoryWorkouts(
      muscleGroupId: _selectedMuscleGroupId,
      limit: 150,
    );
    if (mounted) {
      setState(() {
        _workouts = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndSetRestDay() async {
    AppHaptics.tap();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
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

    if (picked != null) {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.markDateAsRestDay(picked, isRest: true);
      if (!mounted) return;
      AppHaptics.success();
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateFormat('MMM d').format(picked)} marked as Rest & Recovery Day',
            ),
          ),
        );
      }
    }
  }

  void _onCalendarDayTap(DateTime targetDate, WorkoutModel? existing) {
    AppHaptics.tap();
    setState(() {
      if (_selectedCalendarDay != null && AppDateUtils.isSameDay(_selectedCalendarDay!, targetDate)) {
        // Deselect if already selected
        _selectedCalendarDay = null;
      } else {
        _selectedCalendarDay = targetDate;
      }
    });

    // If day is empty or rest, provide instant quick sheet option
    if (existing == null || existing.isRestDay) {
      _showDayActionSheet(targetDate, existing);
    }
  }

  void _showDayActionSheet(DateTime targetDate, WorkoutModel? existing) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 24),
        decoration: BoxDecoration(
          color: context.sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: context.sheetBorder, width: 0.8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(targetDate),
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const Spacer(),
                if (existing != null && existing.isRestDay)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Rest Day',
                      style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF), fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (existing != null && !existing.isRestDay) ...[
              Text(
                existing.title,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '${existing.exercises.length} movements • ${existing.totalSetsCount} sets',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  AppHaptics.save();
                  final today = AppDateUtils.normalizeDate(DateTime.now());
                  final repo = ref.read(workoutRepositoryProvider);
                  final todayWorkout = await repo.getOrCreateTodayWorkout();
                  await repo.copyLastSession(todayWorkout.id, existing.id);
                  ref.read(selectedWorkoutDateProvider.notifier).state = today;
                  if (mounted) {
                    context.go('/today');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied "${existing.title}" to today\'s workout!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.today_rounded, size: 16),
                label: const Text('Repeat in Today\'s Workout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: context.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openWorkoutDetail(existing);
                      },
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: const Text('View Summary'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textPrimary,
                        side: BorderSide(color: context.chipBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(selectedWorkoutDateProvider.notifier).state =
                            AppDateUtils.normalizeDate(targetDate);
                        context.go('/today');
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Edit Sets'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textPrimary,
                        side: BorderSide(color: context.chipBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (existing != null && existing.isRestDay) ...[
              Text(
                'Marked as Rest & Active Recovery. Neuromuscular tissue repairs and streak is preserved.',
                style: TextStyle(fontSize: 12.5, color: context.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final repo = ref.read(workoutRepositoryProvider);
                  await repo.markDateAsRestDay(targetDate, isRest: false);
                  if (!mounted) return;
                  AppHaptics.mediumImpact();
                  _loadHistory();
                },
                icon: const Icon(Icons.fitness_center_rounded, size: 16),
                label: const Text('Unmark Rest Day'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ] else ...[
              Text(
                'No workout recorded for this date yet.',
                style: TextStyle(fontSize: 12.5, color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final repo = ref.read(workoutRepositoryProvider);
                  await repo.markDateAsRestDay(targetDate, isRest: true);
                  if (!mounted) return;
                  AppHaptics.success();
                  _loadHistory();
                },
                icon: const Icon(Icons.self_improvement_rounded, size: 18),
                label: const Text('Mark as Rest Day'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.chipSelectedBg,
                  foregroundColor: context.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(selectedWorkoutDateProvider.notifier).state =
                      AppDateUtils.normalizeDate(targetDate);
                  context.go('/today');
                },
                icon: Icon(Icons.add_rounded, size: 18, color: context.accent),
                label: Text('Log Workout on this Date', style: TextStyle(color: context.accent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.chipBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openWorkoutDetail(WorkoutModel workout) {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkoutDetailSheet(
        workout: workout,
        onWorkoutModified: _loadHistory,
      ),
    );
  }

  /// Extracts target muscle group tags for clean visual telemetry chips
  List<String> _extractMuscleTags(WorkoutModel workout) {
    final groups = <String>{};
    for (final e in workout.exercises) {
      if (e.archived) continue;
      final name = e.exercise.name.toLowerCase();
      if (name.contains('bench') || name.contains('chest') || name.contains('fly')) {
        groups.add('Chest');
      } else if (name.contains('squat') || name.contains('leg') || name.contains('quad') || name.contains('calf')) {
        groups.add('Legs');
      } else if (name.contains('row') || name.contains('pull') || name.contains('lat') || name.contains('deadlift')) {
        groups.add('Back');
      } else if (name.contains('shoulder') || name.contains('press') || name.contains('delt')) {
        groups.add('Delts');
      } else if (name.contains('curl') || name.contains('tricep') || name.contains('bicep')) {
        groups.add('Arms');
      }
    }

    if (groups.isNotEmpty) return groups.take(3).toList();

    // Fallback to title matching
    final lower = workout.title.toLowerCase();
    if (lower.contains('push')) return ['Chest', 'Delts', 'Triceps'];
    if (lower.contains('pull')) return ['Back', 'Biceps', 'Lats'];
    if (lower.contains('leg') || lower.contains('lower')) return ['Quads', 'Hamstrings'];
    if (lower.contains('upper')) return ['Chest', 'Back'];
    if (lower.contains('arm')) return ['Arms'];
    return ['Full Body'];
  }

  /// Filters workouts by search query, muscle groups, preset filters, and selected calendar date
  List<WorkoutModel> get _filteredWorkouts {
    return _workouts.where((w) {
      // 1. Muscle group filter
      if (_selectedMuscleGroupId != null) {
        final matchesGroup = w.exercises.any((e) =>
            e.exercise.muscleGroupId == _selectedMuscleGroupId ||
            e.exercise.secondaryGroups.contains(_selectedMuscleGroupId));
        if (!matchesGroup) return false;
      }

      // 2. Preset filter: 'heavy'
      if (_activePresetFilter == 'heavy' && w.totalVolume < 8000) {
        return false;
      }

      // 3. Preset filter: 'rest'
      if (_activePresetFilter == 'rest' && !w.isRestDay) {
        return false;
      }

      // 4. Calendar selected day filter (if user selected a specific day from calendar)
      if (_selectedCalendarDay != null) {
        if (!AppDateUtils.isSameDay(w.date, _selectedCalendarDay!)) {
          return false;
        }
      }

      // 5. Search query (title, exercise names, notes)
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final titleMatch = w.title.toLowerCase().contains(q);
        final exerciseMatch = w.exercises.any((e) => e.exercise.name.toLowerCase().contains(q));
        final noteMatch = w.note?.toLowerCase().contains(q) ?? false;
        if (!titleMatch && !exerciseMatch && !noteMatch) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    C.isDark = isDark;
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);
    final unit = ref.watch(weightUnitNotifierProvider);
    final filtered = _filteredWorkouts;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // 1. Luxury Header Bar with View Toggle & Search Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: S.xl, right: S.xl, top: S.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('History', style: T.display.copyWith(color: C.text1)),
                        const SizedBox(height: 2),
                        Text(
                          'Telemetry archives & training logs',
                          style: T.body.copyWith(fontSize: 12.5, color: C.text2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Search toggle button
                  ScaleTap(
                    onPressed: () {
                      AppHaptics.tap();
                      setState(() {
                        _isSearchOpen = !_isSearchOpen;
                        if (!_isSearchOpen) {
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7.5),
                      decoration: BoxDecoration(
                        color: _isSearchOpen ? C.accent.withValues(alpha: 0.18) : C.surfaceHi,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isSearchOpen ? C.accent : C.hairline,
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                        size: 17,
                        color: _isSearchOpen ? C.accent : C.text2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Action button: + Rest Day
                  ScaleTap(
                    onPressed: _pickAndSetRestDay,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      decoration: BoxDecoration(
                        color: C.surfaceHi,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.self_improvement_rounded, size: 13, color: const Color(0xFF00E5FF)),
                          const SizedBox(width: 4.5),
                          Text(
                            '+ Rest',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: C.text1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Toggle Calendar / List view
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: C.surfaceHi,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: C.hairline),
                    ),
                    child: Row(
                      children: [
                        _buildViewModeButton(
                          icon: Icons.calendar_month_rounded,
                          isSelected: _viewMode == HistoryViewMode.calendar,
                          onTap: () => setState(() => _viewMode = HistoryViewMode.calendar),
                        ),
                        _buildViewModeButton(
                          icon: Icons.view_agenda_outlined,
                          isSelected: _viewMode == HistoryViewMode.list,
                          onTap: () => setState(() => _viewMode = HistoryViewMode.list),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Collapsible Smart Search Bar
          if (_isSearchOpen)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(S.xl, S.md, S.xl, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161925) : const Color(0xFFF1F4FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: C.accent.withValues(alpha: isDark ? 0.35 : 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      color: context.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search workouts, movements (e.g. Bench, Push)...',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: context.textTertiary,
                      ),
                      border: InputBorder.none,
                      icon: Icon(Icons.search_rounded, size: 18, color: C.accent),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                  ),
                ),
              ),
            ),

          // 3. Biometric Monthly Telemetry Horizon Dock
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.xl, S.md, S.xl, S.xs),
              child: _buildMonthlyHorizonDock(isDark, unit),
            ),
          ),

          // 4. Preset & Muscle Group Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: S.xl),
                  children: [
                    _buildPresetPill('All Sessions', 'all'),
                    _buildPresetPill('🏆 Heavy Volume', 'heavy'),
                    _buildPresetPill('🧘 Active Rest', 'rest'),
                    Container(
                      height: 18,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      color: isDark ? const Color(0xFF282E40) : const Color(0xFFD6DBE5),
                    ),
                    muscleGroupsAsync.when(
                      data: (groups) => Row(
                        children: groups.map((g) => _buildMuscleFilterChip(g.name, g.id)).toList(),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Interactive Calendar View Widget (if Calendar Mode)
          if (_viewMode == HistoryViewMode.calendar)
            SliverToBoxAdapter(
              child: _buildCalendarWidget(isDark),
            ),

          // 6. Day Selection Spotlight Banner (if a day is selected)
          if (_selectedCalendarDay != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(S.xl, S.xs, S.xl, S.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: C.accent.withValues(alpha: isDark ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: C.accent.withValues(alpha: isDark ? 0.35 : 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded, size: 15, color: C.accent),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Filtered by: ${DateFormat('EEEE, MMM d').format(_selectedCalendarDay!)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ScaleTap(
                        onPressed: () {
                          AppHaptics.tap();
                          setState(() => _selectedCalendarDay = null);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: C.surfaceHi,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Show All',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: C.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. Workouts List (Filtered & Stepped Obsidian Cards)
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: context.accent, strokeWidth: 2.5),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 38, color: context.textTertiary),
                    const SizedBox(height: 10),
                    Text(
                      _selectedCalendarDay != null
                          ? 'No session recorded on ${DateFormat('MMM d').format(_selectedCalendarDay!)}'
                          : 'No workouts match the active filter.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                      ),
                    ),
                    if (_selectedCalendarDay != null || _searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ScaleTap(
                        onPressed: () {
                          setState(() {
                            _selectedCalendarDay = null;
                            _searchController.clear();
                            _searchQuery = '';
                            _activePresetFilter = 'all';
                            _selectedMuscleGroupId = null;
                          });
                        },
                        child: Text(
                          'Reset all filters',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: C.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: S.xl, vertical: AppSpacing.xs),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final w = filtered[index];
                    return _buildSteppedWorkoutCard(w, unit, isDark);
                  },
                  childCount: filtered.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }

  // ── Monthly Horizon Biometric Dock ──
  Widget _buildMonthlyHorizonDock(bool isDark, WeightUnit unit) {
    final monthWorkouts = _workouts
        .where((w) => w.date.year == _selectedMonth.year && w.date.month == _selectedMonth.month)
        .toList();
    final activeWorkouts = monthWorkouts.where((w) => !w.isRestDay).toList();
    final monthVolume = activeWorkouts.fold(0.0, (sum, w) => sum + w.totalVolume);
    final monthSets = activeWorkouts.fold(0, (sum, w) => sum + w.totalSetsCount);
    final workoutDays = activeWorkouts.map((w) => w.date.day).toSet();
    final restDays = monthWorkouts.where((w) => w.isRestDay).map((w) => w.date.day).toSet();

    // Consistency rate calculation
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final targetSessions = (daysInMonth * (4.0 / 7.0)).round(); // approx 4 workouts / week
    final consistency = targetSessions > 0
        ? (workoutDays.length / targetSessions).clamp(0.0, 1.0)
        : 0.85;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF161925),
                  Color(0xFF0F1118),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF6F8FC),
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF282D3D) : const Color(0xFFDFE3EC),
          width: 1.0,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          // Horizon Header Row: Month title & switcher + consistency badge
          Row(
            children: [
              ScaleTap(
                onPressed: () {
                  AppHaptics.tap();
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                    _selectedCalendarDay = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1E2B) : const Color(0xFFEEF1F8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.chevron_left_rounded, size: 18, color: context.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth).toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      '${workoutDays.length} sessions logged • ${restDays.length} active recovery',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ScaleTap(
                onPressed: () {
                  AppHaptics.tap();
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                    _selectedCalendarDay = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1E2B) : const Color(0xFFEEF1F8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.chevron_right_rounded, size: 18, color: context.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizon Telemetry Metrics Cells (Volume, Sets, Adherence)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF12141E) : const Color(0xFFF3F5FA),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isDark ? const Color(0xFF222635) : const Color(0xFFE2E6EF),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                _buildHorizonCell(
                  context,
                  Icons.fitness_center_rounded,
                  UnitConverter.formatWeight(monthVolume, unit: unit),
                  'MONTH LOAD',
                  C.accent,
                ),
                _buildHorizonDivider(isDark),
                _buildHorizonCell(
                  context,
                  Icons.layers_rounded,
                  '$monthSets',
                  'SETS COMPLETED',
                  context.textPrimary,
                ),
                _buildHorizonDivider(isDark),
                _buildHorizonCell(
                  context,
                  Icons.speed_rounded,
                  '${(consistency * 100).toInt()}%',
                  'SPLIT ADHERENCE',
                  const Color(0xFF00E5FF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonCell(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color accent,
  ) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: accent),
          const SizedBox(width: 5.5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: context.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 7.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: context.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonDivider(bool isDark) {
    return Container(
      height: 16,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? const Color(0xFF262C3E) : const Color(0xFFD6DBE5),
    );
  }

  // ── Stepped Obsidian Workout Card ──
  Widget _buildSteppedWorkoutCard(WorkoutModel w, WeightUnit unit, bool isDark) {
    final weekday = DateFormat('EEE').format(w.date).toUpperCase();
    final dayMonth = DateFormat('MMM d').format(w.date);
    final isToday = AppDateUtils.isSameDay(w.date, DateTime.now());
    final isYesterday = AppDateUtils.isSameDay(w.date, DateTime.now().subtract(const Duration(days: 1)));
    final dateBadge = isToday ? 'TODAY • $weekday' : (isYesterday ? 'YESTERDAY • $weekday' : '$weekday, $dayMonth');

    // ── Dedicated Rest Day Representation (Active Neuromuscular Regeneration) ──
    if (w.isRestDay) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F1B24),
                    Color(0xFF0A1218),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF2F8FA),
                    Color(0xFFEAF3F7),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.30 : 0.22),
            width: 1.0,
          ),
        ),
        child: ScaleTap(
          onPressed: () => _openWorkoutDetail(w),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Cyan restorative halo icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.28 : 0.20),
                      width: 0.8,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.self_improvement_rounded, color: Color(0xFF00E5FF), size: 21),
                  ),
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
                              w.title,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.5,
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
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              dateBadge,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2.5),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Active Neuromuscular Regeneration • Streak Preserved',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.0,
                                color: context.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (w.note != null && w.note!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          w.note!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            color: context.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: context.textTertiary, size: 18),
              ],
            ),
          ),
        ),
      );
    }

    final activeExercises = w.exercises.where((e) => !e.archived).toList();
    final exercisesSummary = activeExercises.map((e) => e.exercise.name).take(3).join(' • ');
    final targetMuscles = _extractMuscleTags(w);

    // Compute volume score (0.60 to 0.98)
    final volumeScore = ((activeExercises.length * 8.0) + (w.totalSetsCount * 2.5)) / 100.0;
    final clampedScore = volumeScore.clamp(0.55, 0.98);
    final isHeavyVolume = w.totalVolume >= 8000;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF161925),
                  Color(0xFF0F1118),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF7F8FC),
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF262B3A) : const Color(0xFFDFE3EC),
          width: 1.0,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: ScaleTap(
        onPressed: () => _openWorkoutDetail(w),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Column: Details & Muscle Tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Title, Date Badge, and High Volume Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            w.title,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isToday
                                ? context.accent.withValues(alpha: isDark ? 0.20 : 0.12)
                                : (isDark ? const Color(0xFF1B1E2B) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isToday
                                  ? context.accent.withValues(alpha: 0.45)
                                  : (isDark ? const Color(0xFF282E40) : const Color(0xFFDFE3EC)),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            dateBadge,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9.5,
                              color: isToday ? context.accent : context.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Muscle Group Chips & High Volume Callout
                    Wrap(
                      spacing: 4.5,
                      runSpacing: 4.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...targetMuscles.map((m) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141724) : const Color(0xFFF1F4FA),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: C.accent.withValues(alpha: isDark ? 0.22 : 0.15),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 3.5,
                                  height: 3.5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: C.accent,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  m.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (isHeavyVolume)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.10),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.35),
                                width: 0.6,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.emoji_events_rounded, size: 10, color: Colors.amber),
                                SizedBox(width: 3),
                                Text(
                                  'HEAVY LOAD',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Metrics Strip: Movements, Sets, Volume
                    Text(
                      '${activeExercises.length} movements • ${w.totalSetsCount} sets • ${UnitConverter.formatWeight(w.totalVolume, unit: unit)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),

                    if (exercisesSummary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        exercisesSummary + (activeExercises.length > 3 ? '...' : ''),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          color: context.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Right Column: Micro-Telemetry Chronograph Dial
              WorkoutTelemetryDial.compact(
                progress: clampedScore,
                valueText: '${(clampedScore * 100).toInt()}%',
                size: 38.0,
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: context.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── View Mode Toggle Button ──
  Widget _buildViewModeButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ScaleTap(
      onPressed: onTap,
      scaleDown: 0.90,
      enableHaptic: true,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isSelected ? C.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? C.accent : C.text3,
        ),
      ),
    );
  }

  // ── Filter Pills ──
  Widget _buildPresetPill(String label, String key) {
    final isSelected = _activePresetFilter == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: GestureDetector(
        onTap: () {
          AppHaptics.step();
          setState(() {
            _activePresetFilter = key;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accent.withValues(alpha: isDark ? 0.20 : 0.12)
                : (isDark ? const Color(0xFF161925) : const Color(0xFFF1F4FA)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? context.accent : (isDark ? const Color(0xFF262C3E) : const Color(0xFFDFE3EC)),
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? context.accent : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMuscleFilterChip(String label, String id) {
    final isSelected = _selectedMuscleGroupId == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: GestureDetector(
        onTap: () {
          AppHaptics.step();
          setState(() {
            _selectedMuscleGroupId = isSelected ? null : id;
            _isLoading = true;
          });
          _loadHistory();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accent.withValues(alpha: isDark ? 0.20 : 0.12)
                : (isDark ? const Color(0xFF161925) : const Color(0xFFF1F4FA)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? context.accent : (isDark ? const Color(0xFF262C3E) : const Color(0xFFDFE3EC)),
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? context.accent : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Interactive Calendar with Volume Heat Markers ──
  Widget _buildCalendarWidget(bool isDark) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final monthWorkouts = _workouts
        .where((w) => w.date.year == _selectedMonth.year && w.date.month == _selectedMonth.month)
        .toList();

    // Map days to workouts
    final workoutDaysMap = <int, WorkoutModel>{};
    for (final w in monthWorkouts) {
      workoutDaysMap[w.date.day] = w;
    }

    // Monday-first offset
    final firstWeekdayOffset = (DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday - 1) % 7;
    final totalGridSlots = firstWeekdayOffset + daysInMonth;

    const weekdayHeaders = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: S.xl, vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF242838) : context.cardBorder,
          width: 0.8,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                const BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
      ),
      child: Column(
        children: [
          // Weekday Header Row (MON - SUN)
          Row(
            children: weekdayHeaders.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: context.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Day Grid with Volume Heat Markers
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.12,
            ),
            itemCount: totalGridSlots,
            itemBuilder: (context, index) {
              if (index < firstWeekdayOffset) {
                return const SizedBox.shrink();
              }

              final day = index - firstWeekdayOffset + 1;
              final existingW = workoutDaysMap[day];
              final hasWorkout = existingW != null && !existingW.isRestDay;
              final hasRest = existingW != null && existingW.isRestDay;
              final isToday = now.year == _selectedMonth.year && now.month == _selectedMonth.month && now.day == day;
              final isSelected = _selectedCalendarDay != null &&
                  _selectedCalendarDay!.year == _selectedMonth.year &&
                  _selectedCalendarDay!.month == _selectedMonth.month &&
                  _selectedCalendarDay!.day == day;

              final isHeavy = hasWorkout && existingW.totalVolume >= 8000;

              Color bg = Colors.transparent;
              Color border = isDark ? const Color(0x18FFFFFF) : context.cardBorder;

              if (isSelected) {
                border = Colors.amber;
                bg = Colors.amber.withValues(alpha: isDark ? 0.22 : 0.14);
              } else if (hasWorkout) {
                bg = context.accent.withValues(alpha: isDark ? (isHeavy ? 0.25 : 0.16) : 0.12);
                border = isHeavy ? context.accent : context.accent.withValues(alpha: 0.7);
              } else if (hasRest) {
                bg = const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.12 : 0.08);
                border = const Color(0xFF00E5FF).withValues(alpha: 0.35);
              } else if (isToday) {
                border = context.accent.withValues(alpha: 0.65);
              }

              return GestureDetector(
                onTap: () => _onCalendarDayTap(DateTime(_selectedMonth.year, _selectedMonth.month, day), existingW),
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: border,
                      width: isSelected ? 1.6 : (isToday ? 1.4 : ((hasWorkout || hasRest) ? 1.1 : 0.6)),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: (hasWorkout || hasRest || isToday || isSelected)
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.amber
                                    : (hasWorkout
                                        ? context.accent
                                        : (isToday
                                            ? context.accent
                                            : (hasRest ? const Color(0xFF00E5FF) : context.textSecondary))),
                              ),
                            ),
                            if (hasRest) ...[
                              const SizedBox(width: 2.5),
                              const Icon(Icons.self_improvement_rounded, size: 9.5, color: Color(0xFF00E5FF)),
                            ],
                          ],
                        ),
                        if (hasWorkout)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isHeavy ? Colors.amber : context.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: (isHeavy ? Colors.amber : context.accent).withValues(alpha: 0.6),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          )
                        else if (isToday)
                          Container(
                            width: 3.5,
                            height: 3.5,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.accent.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
