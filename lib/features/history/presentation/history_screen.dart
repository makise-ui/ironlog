import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
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
  HistoryViewMode _viewMode = HistoryViewMode.list;
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

  void _openWorkoutDetail(WorkoutModel workout) {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkoutDetailSheet(
        workout: workout,
        onWorkoutModified: _loadHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.md),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('History', style: AppTypography.displayMedium),
                      SizedBox(height: 2),
                      Text('Logged workouts & training logs', style: AppTypography.labelSmall),
                    ],
                  ),
                  const Spacer(),
                  // Toggle Calendar / List view
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.glassTileFill,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(color: AppColors.glassBorderDim),
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
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
            )
          else if (_workouts.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No workouts logged for this filter.',
                  style: TextStyle(color: AppColors.textTertiary),
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
    return GestureDetector(
      onTap: () {
        AppHaptics.step();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.25) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.accentCyan : AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? id) {
    final isSelected = _selectedMuscleGroupId == id;
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentCyan.withValues(alpha: 0.2) : AppColors.glassTileFill,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(
              color: isSelected ? AppColors.accentCyan : AppColors.glassBorderDim,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarWidget() {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final workoutDays = _workouts.map((w) => w.date.day).toSet();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.glassTileFill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.glassBorderDim),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                  });
                },
              ),
              Text(
                '${DateFormat('MMMM yyyy').format(_selectedMonth)} (${workoutDays.length} sessions)',
                style: AppTypography.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
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

              return Container(
                decoration: BoxDecoration(
                  color: hasWorkout ? AppColors.accentCyan.withValues(alpha: 0.25) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasWorkout ? AppColors.accentCyan : AppColors.glassBorderDim,
                    width: hasWorkout ? 1.5 : 0.5,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: hasWorkout ? FontWeight.w700 : FontWeight.w400,
                          color: hasWorkout ? AppColors.accentCyan : AppColors.textSecondary,
                        ),
                      ),
                      if (hasWorkout)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentCyan,
                          ),
                        ),
                    ],
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
              color: AppColors.accentCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Center(
              child: w.feel != null
                  ? Text(
                      ['😫', '😕', '😐', '🙂', '🔥'][(w.feel! - 1).clamp(0, 4)],
                      style: const TextStyle(fontSize: 20),
                    )
                  : const Icon(Icons.fitness_center_rounded, color: AppColors.accentCyan, size: 20),
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
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      AppDateUtils.formatRelativeDate(w.date),
                      style: AppTypography.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${activeExercises.length} exercises • ${w.totalSetsCount} sets • ${UnitConverter.formatWeight(w.totalVolume, unit: unit)}',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.accentCyan),
                ),
                if (exercisesSummary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    exercisesSummary + (activeExercises.length > 3 ? '...' : ''),
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
        ],
      ),
    );
  }
}
