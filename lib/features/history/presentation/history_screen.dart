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
import '../../../core/widgets/glass_tile.dart';
import '../../../domain/models/workout_model.dart';
import '../../../data/providers.dart';
import 'workout_detail_sheet.dart';

enum HistoryViewMode { list, calendar }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryViewMode _viewMode = HistoryViewMode.calendar;
  String? _selectedMuscleGroupId;
  List<WorkoutModel> _workouts = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final repo = ref.read(workoutRepositoryProvider);
    final list = await repo.getHistoryWorkouts(
      muscleGroupId: _selectedMuscleGroupId,
      limit: 100,
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
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 24),
        decoration: BoxDecoration(
          color: context.sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const Spacer(),
                if (existing != null && existing.isRestDay)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF383838) : const Color(0xFFF0F0F1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Rest Day', style: TextStyle(fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (existing != null && !existing.isRestDay) ...[
              Text(
                existing.title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '${existing.exercises.length} movements • ${existing.totalSetsCount} sets',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              const SizedBox(height: 16),
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
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(selectedWorkoutDateProvider.notifier).state =
                            AppDateUtils.normalizeDate(targetDate);
                        context.go('/today');
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Edit / Add Sets'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accent,
                        foregroundColor: context.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (existing != null && existing.isRestDay) ...[
              Text(
                'Marked as Rest & Recovery. Muscle tissue repairs and streak is preserved.',
                style: TextStyle(fontSize: 12.5, color: context.textSecondary),
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
                'No activity recorded for this day yet.',
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

  @override
  Widget build(BuildContext context) {
    C.isDark = Theme.of(context).brightness == Brightness.dark;
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);
    final unit = ref.watch(weightUnitNotifierProvider);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Header & View Mode Switch
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
                          'Logged workouts & logs',
                          style: T.body.copyWith(fontSize: 13, color: C.text2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Action button: + Rest Day
                  ScaleTap(
                    onPressed: _pickAndSetRestDay,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: C.surfaceHi,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.self_improvement_rounded, size: 12, color: C.text2),
                          const SizedBox(width: 4),
                          Text(
                            '+ Rest Day',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: C.text1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                          icon: Icons.view_agenda_outlined,
                          isSelected: _viewMode == HistoryViewMode.list,
                          onTap: () => setState(() => _viewMode = HistoryViewMode.list),
                        ),
                        _buildViewModeButton(
                          icon: Icons.calendar_month_rounded,
                          isSelected: _viewMode == HistoryViewMode.calendar,
                          onTap: () => setState(() => _viewMode = HistoryViewMode.calendar),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Muscle Group Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: muscleGroupsAsync.when(
                data: (groups) {
                  return SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      children: [
                        _buildFilterChip('All Muscle Groups', null),
                        ...groups.map((g) => _buildFilterChip(g.name, g.id)),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 38),
                error: (_, _) => const SizedBox(height: 38),
              ),
            ),
          ),

          // Calendar View Header if Calendar Mode
          if (_viewMode == HistoryViewMode.calendar)
            SliverToBoxAdapter(
              child: _buildCalendarWidget(),
            ),

          // Workouts List
          if (_isLoading)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: context.accent)),
            )
          else if (_workouts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No workouts logged for this filter.',
                  style: TextStyle(color: context.textTertiary),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final w = _workouts[index];
                    return _buildWorkoutCard(w, unit);
                  },
                  childCount: _workouts.length,
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
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? C.accent.withValues(alpha: 0.18) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? C.accent : C.text3,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? id) {
    final isSelected = _selectedMuscleGroupId == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: GestureDetector(
        onTap: () {
          AppHaptics.step();
          setState(() {
            _selectedMuscleGroupId = id;
            _isLoading = true;
          });
          _loadHistory();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accent.withValues(alpha: isDark ? 0.20 : 0.12)
                : context.chipBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? context.accent : context.chipBorder,
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? context.accent
                  : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarWidget() {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final monthWorkouts = _workouts.where((w) => w.date.year == _selectedMonth.year && w.date.month == _selectedMonth.month).toList();
    final workoutDays = monthWorkouts.where((w) => !w.isRestDay).map((w) => w.date.day).toSet();
    final restDays = monthWorkouts.where((w) => w.isRestDay).map((w) => w.date.day).toSet();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder, width: 0.8),
        boxShadow: context.isDark ? null : [
          const BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: context.textPrimary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                  });
                },
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${workoutDays.length} workouts • ${restDays.length} rest',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: context.textPrimary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final day = index + 1;
              final hasWorkout = workoutDays.contains(day);
              final hasRest = restDays.contains(day);
              final existingW = monthWorkouts.where((w) => w.date.day == day).firstOrNull;

              Color bg = Colors.transparent;
              Color border = context.isDark ? const Color(0x18FFFFFF) : context.cardBorder;
              if (hasWorkout) {
                bg = context.accent.withValues(alpha: context.isDark ? 0.20 : 0.12);
                border = context.accent;
              } else if (hasRest) {
                bg = context.isDark ? const Color(0xFF383838) : const Color(0xFFF0F0F1);
                border = context.isDark ? const Color(0xFF505050) : const Color(0xFFCCCCCC);
              }

              return GestureDetector(
                onTap: () => _onCalendarDayTap(DateTime(_selectedMonth.year, _selectedMonth.month, day), existingW),
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: border,
                      width: (hasWorkout || hasRest) ? 1.2 : 0.6,
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
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12,
                                fontWeight: (hasWorkout || hasRest) ? FontWeight.w700 : FontWeight.w500,
                                color: hasWorkout
                                    ? context.accent
                                    : (hasRest ? context.textPrimary : context.textSecondary),
                              ),
                            ),
                            if (hasRest) ...[
                              const SizedBox(width: 3),
                              Icon(Icons.self_improvement_rounded, size: 10, color: context.textSecondary),
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
                              color: context.accent,
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

  Widget _buildWorkoutCard(WorkoutModel w, WeightUnit unit) {
    if (w.isRestDay) {
      return GlassTile(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        onTap: () => _openWorkoutDetail(w),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFF383838) : const Color(0xFFF0F0F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.self_improvement_rounded, color: Color(0xFF9E9E9E), size: 22),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
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
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        AppDateUtils.formatRelativeDate(w.date),
                        style: AppTypography.labelSmall.copyWith(color: context.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active Recovery • Streak Protected',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (w.note != null && w.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      w.note!,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: context.textTertiary, size: 20),
          ],
        ),
      );
    }

    final activeExercises = w.exercises.where((e) => !e.archived).toList();
    final exercisesSummary = activeExercises.map((e) => e.exercise.name).take(3).join(', ');

    return GlassTile(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: () => _openWorkoutDetail(w),
      child: Row(
        children: [
          // Feel emoji or icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.isDark ? C.surfaceHi : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.isDark ? C.hairline : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: w.feel != null
                  ? Icon(
                      const [
                        Icons.sentiment_very_dissatisfied_rounded,
                        Icons.sentiment_dissatisfied_rounded,
                        Icons.sentiment_neutral_rounded,
                        Icons.sentiment_satisfied_rounded,
                        Icons.local_fire_department_rounded,
                      ][(w.feel! - 1).clamp(0, 4)],
                      size: 20,
                      color: C.text2,
                    )
                  : Icon(Icons.fitness_center_rounded, color: C.text2, size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
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
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: C.text1,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      AppDateUtils.formatRelativeDate(w.date),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: C.text3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${activeExercises.length} exercises • ${w.totalSetsCount} sets • ${UnitConverter.formatWeight(w.totalVolume, unit: unit)}',
                  style: AppTypography.labelSmall.copyWith(color: context.textSecondary),
                ),
                if (exercisesSummary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    exercisesSummary + (activeExercises.length > 3 ? '...' : ''),
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11,
                      color: context.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, color: context.textTertiary, size: 20),
        ],
      ),
    );
  }
}
