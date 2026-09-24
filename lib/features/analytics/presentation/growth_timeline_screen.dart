import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../data/providers.dart';
import '../../../domain/models/analytics_model.dart';
import '../../../domain/models/set_model.dart';
import '../../../domain/models/workout_model.dart';
import '../../../domain/services/sample_timeline_service.dart';

enum TimelineFilter { all, prsOnly, highVolume, push, pull, legs }
enum TimelineOrientation { verticalBranch, horizontal }

class GrowthTimelineScreen extends ConsumerStatefulWidget {
  const GrowthTimelineScreen({super.key});

  @override
  ConsumerState<GrowthTimelineScreen> createState() => _GrowthTimelineScreenState();
}

class _GrowthTimelineScreenState extends ConsumerState<GrowthTimelineScreen>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformCtrl;
  AnimationController? _animCtrl;
  Animation<Matrix4>? _animMatrix;

  List<WorkoutModel> _allWorkouts = [];
  List<PrItemData> _allPrs = [];
  bool _isLoading = true;
  double _currentScale = 0.85;
  TimelineFilter _selectedFilter = TimelineFilter.all;
  TimelineOrientation _orientation = TimelineOrientation.verticalBranch;

  @override
  void initState() {
    super.initState();
    _transformCtrl = TransformationController();
    _transformCtrl.value = Matrix4.diagonal3Values(0.85, 0.85, 1.0);
    _transformCtrl.addListener(_onTransformChanged);
    _loadData();
  }

  @override
  void dispose() {
    _transformCtrl.removeListener(_onTransformChanged);
    _transformCtrl.dispose();
    _animCtrl?.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.04) {
      setState(() => _currentScale = scale);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final workouts = await repo.getHistoryWorkouts(limit: 400);
      final prs = await repo.getRecentPrs(limit: 100);

      // Chronological order: oldest at top, progressing down to newest
      workouts.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _allWorkouts = workouts;
          _allPrs = prs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _animateToScale(double targetScale) {
    AppHaptics.step();
    _animCtrl?.dispose();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    final current = _transformCtrl.value;
    final target = Matrix4.diagonal3Values(targetScale, targetScale, 1.0);

    _animMatrix = Matrix4Tween(begin: current, end: target).animate(
      CurvedAnimation(parent: _animCtrl!, curve: Curves.easeOutCubic),
    )..addListener(() {
        _transformCtrl.value = _animMatrix!.value;
      });

    _animCtrl!.forward();
  }

  void _resetZoom() {
    _animateToScale(_orientation == TimelineOrientation.verticalBranch ? 0.85 : 1.0);
  }

  Future<void> _importJsonFile() async {
    AppHaptics.tap();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        final db = ref.read(databaseProvider);
        final count = await SampleTimelineService.importJourneyFromJson(db, jsonStr);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported $count sessions from ${result.files.single.name}!'),
              backgroundColor: AppColors.accentEmerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing JSON: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }



  List<WorkoutModel> get _filteredWorkouts {
    switch (_selectedFilter) {
      case TimelineFilter.all:
        return _allWorkouts;
      case TimelineFilter.prsOnly:
        return _allWorkouts.where((w) {
          return _allPrs.any((pr) =>
              pr.achievedAt.year == w.date.year &&
              pr.achievedAt.month == w.date.month &&
              pr.achievedAt.day == w.date.day);
        }).toList();
      case TimelineFilter.highVolume:
        return _allWorkouts.where((w) => w.totalVolume >= 6000).toList();
      case TimelineFilter.push:
        return _allWorkouts.where((w) => w.title.toLowerCase().contains('push')).toList();
      case TimelineFilter.pull:
        return _allWorkouts.where((w) => w.title.toLowerCase().contains('pull')).toList();
      case TimelineFilter.legs:
        return _allWorkouts.where((w) => w.title.toLowerCase().contains('leg')).toList();
    }
  }

  void _showWorkoutInspector(WorkoutModel workout) {
    AppHaptics.mediumImpact();
    final prsForDay = _allPrs.where((pr) =>
        pr.achievedAt.year == workout.date.year &&
        pr.achievedAt.month == workout.date.month &&
        pr.achievedAt.day == workout.date.day).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => _WorkoutInspectionSheet(
        workout: workout,
        prs: prsForDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unit = ref.watch(weightUnitNotifierProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'GROWTH TIMELINE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${_currentScale.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentViolet,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${_filteredWorkouts.length} sessions • Branch Tree • Pinch to Zoom',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          // Orientation toggle button (Branch Tree vs Horizontal)
          IconButton(
            tooltip: _orientation == TimelineOrientation.verticalBranch
                ? 'Switch to Horizontal Track'
                : 'Switch to Vertical Branch Tree',
            icon: Icon(
              _orientation == TimelineOrientation.verticalBranch
                  ? Icons.alt_route_rounded
                  : Icons.view_timeline_rounded,
              color: AppColors.accentViolet,
            ),
            onPressed: () {
              AppHaptics.step();
              setState(() {
                _orientation = _orientation == TimelineOrientation.verticalBranch
                    ? TimelineOrientation.horizontal
                    : TimelineOrientation.verticalBranch;
              });
              _resetZoom();
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Timeline Options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'import') _importJsonFile();
              if (val == 'reset') _resetZoom();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_open_rounded, color: AppColors.accentViolet, size: 18),
                    SizedBox(width: 10),
                    Text('Import JSON File'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.center_focus_strong_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Reset Zoom & Center'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Zoom Presets and Filter Bar
                _buildControlToolbar(isDark),

                // Main Interactive Timeline Canvas
                Expanded(
                  child: _allWorkouts.isEmpty
                      ? _buildEmptyState(isDark)
                      : (_orientation == TimelineOrientation.verticalBranch
                          ? _buildVerticalBranchCanvas(isDark, unit)
                          : _buildHorizontalCanvas(isDark, unit)),
                ),
              ],
            ),
    );
  }

  Widget _buildControlToolbar(bool isDark) {
    final isBranch = _orientation == TimelineOrientation.verticalBranch;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131822) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          // Row 1: Zoom scale buttons + Orientation badge
          Row(
            children: [
              Text(
                'ZOOM:',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(width: 8),
              if (isBranch) ...[
                _buildZoomPill('0.35x Tree', 0.35, isDark),
                const SizedBox(width: 6),
                _buildZoomPill('0.7x', 0.7, isDark),
                const SizedBox(width: 6),
                _buildZoomPill('1.0x', 1.0, isDark),
                const SizedBox(width: 6),
                _buildZoomPill('1.8x', 1.8, isDark),
              ] else ...[
                _buildZoomPill('0.4x', 0.4, isDark),
                const SizedBox(width: 6),
                _buildZoomPill('1.0x', 1.0, isDark),
                const SizedBox(width: 6),
                _buildZoomPill('2.0x', 2.0, isDark),
                const SizedBox(width: 6),
                _buildZoomPill('3.2x', 3.2, isDark),
              ],
              const Spacer(),
              // Mode Indicator
              GestureDetector(
                onTap: () {
                  AppHaptics.step();
                  setState(() {
                    _orientation = _orientation == TimelineOrientation.verticalBranch
                        ? TimelineOrientation.horizontal
                        : TimelineOrientation.verticalBranch;
                  });
                  _resetZoom();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isBranch ? Icons.alt_route_rounded : Icons.view_timeline_rounded,
                        size: 13,
                        color: AppColors.accentViolet,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBranch ? 'BRANCH' : 'TRACK',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentViolet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _resetZoom,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.fit_screen_rounded, size: 13, color: isDark ? Colors.white70 : Colors.black87),
                      const SizedBox(width: 4),
                      Text(
                        'FIT',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', TimelineFilter.all, isDark),
                const SizedBox(width: 6),
                _buildFilterChip('PRs Only', TimelineFilter.prsOnly, isDark, activeColor: const Color(0xFFF59E0B), icon: Icons.emoji_events_rounded),
                const SizedBox(width: 6),
                _buildFilterChip('High Volume', TimelineFilter.highVolume, isDark, activeColor: AppColors.accentEmerald, icon: Icons.bolt_rounded),
                const SizedBox(width: 6),
                _buildFilterChip('Push', TimelineFilter.push, isDark),
                const SizedBox(width: 6),
                _buildFilterChip('Pull', TimelineFilter.pull, isDark),
                const SizedBox(width: 6),
                _buildFilterChip('Legs', TimelineFilter.legs, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomPill(String label, double scale, bool isDark) {
    final isActive = (_currentScale - scale).abs() < 0.2;
    return GestureDetector(
      onTap: () => _animateToScale(scale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accentViolet
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, TimelineFilter filter, bool isDark, {Color? activeColor, IconData? icon}) {
    final isSelected = _selectedFilter == filter;
    final color = activeColor ?? context.accent;
    return GestureDetector(
      onTap: () {
        AppHaptics.tap();
        setState(() => _selectedFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white24 : Colors.black26),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── VERTICAL UP-TO-DOWN BRANCH TREE ───────────────────

  Widget _buildVerticalBranchCanvas(bool isDark, WeightUnit unit) {
    final workouts = _filteredWorkouts;
    if (workouts.isEmpty) {
      return _buildEmptyFilterState(isDark);
    }

    const double canvasWidth = 840.0;
    const double centerX = canvasWidth / 2;
    const double cardWidth = 310.0;
    const double branchGap = 44.0;
    const double rowHeight = 158.0;
    const double monthBannerHeight = 65.0;

    // Calculate item Y positions and month dividers
    final items = <_BranchTimelineItem>[];
    double yCursor = 50.0;
    int? currentMonth;
    int? currentYear;

    for (int i = 0; i < workouts.length; i++) {
      final w = workouts[i];
      if (currentMonth == null || w.date.month != currentMonth || w.date.year != currentYear) {
        currentMonth = w.date.month;
        currentYear = w.date.year;
        items.add(_BranchTimelineItem.monthDivider(
          monthName: DateFormat('MMMM yyyy').format(w.date).toUpperCase(),
          yPos: yCursor,
        ));
        yCursor += monthBannerHeight;
      }

      final isLeft = (items.where((it) => it.isWorkout).length % 2 == 0);
      final isPR = _allPrs.any((pr) =>
          pr.achievedAt.year == w.date.year &&
          pr.achievedAt.month == w.date.month &&
          pr.achievedAt.day == w.date.day);
      final isHighVolume = w.totalVolume >= 6000;

      items.add(_BranchTimelineItem.workout(
        workout: w,
        index: i + 1,
        isLeft: isLeft,
        isPR: isPR,
        isHighVolume: isHighVolume,
        yPos: yCursor,
      ));

      yCursor += rowHeight;
    }

    final double totalHeight = yCursor + 80.0;

    return InteractiveViewer(
      transformationController: _transformCtrl,
      minScale: 0.25,
      maxScale: 3.5,
      boundaryMargin: const EdgeInsets.symmetric(horizontal: 300, vertical: 300),
      constrained: false,
      child: Container(
        width: canvasWidth,
        height: totalHeight,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0C1019) : const Color(0xFFF8FAFC),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background grid
            CustomPaint(
              size: Size(canvasWidth, totalHeight),
              painter: _TimelineGridPainter(isDark: isDark),
            ),

            // Continuous vertical luminous trunk & curved branch connectors
            CustomPaint(
              size: Size(canvasWidth, totalHeight),
              painter: _VerticalBranchPainter(
                items: items,
                centerX: centerX,
                cardWidth: cardWidth,
                branchGap: branchGap,
                isDark: isDark,
              ),
            ),

            // Start beacon at top of trunk
            Positioned(
              left: centerX - 65,
              top: 14,
              child: Container(
                width: 130,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentViolet.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentViolet, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentViolet.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flag_rounded, size: 13, color: AppColors.accentViolet),
                    SizedBox(width: 5),
                    Text(
                      'START JOURNEY',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Workout Cards and Month Dividers
            ...items.map((item) {
              if (item.isDivider) {
                return Positioned(
                  left: centerX - 105,
                  top: item.yPos,
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFF1E293B),
                                const Color(0xFF334155),
                                const Color(0xFF1E293B),
                              ]
                            : [
                                const Color(0xFFE2E8F0),
                                const Color(0xFFF1F5F9),
                                const Color(0xFFE2E8F0),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black45 : const Color(0x0A000000),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (item.monthName ?? '').toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                );
              }

              // Workout Node Card
              final isLeft = item.isLeft;
              final posX = isLeft
                  ? (centerX - branchGap - cardWidth)
                  : (centerX + branchGap);

              return Positioned(
                left: posX,
                top: item.yPos,
                width: cardWidth,
                child: _TimelineBranchCard(
                  workout: item.workout!,
                  index: item.index,
                  isLeft: isLeft,
                  isPR: item.isPR,
                  isHighVolume: item.isHighVolume,
                  unit: unit,
                  isDark: isDark,
                  onTap: () => _showWorkoutInspector(item.workout!),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─────────────────── HORIZONTAL TRACK CANVAS ───────────────────

  Widget _buildHorizontalCanvas(bool isDark, WeightUnit unit) {
    final workouts = _filteredWorkouts;
    if (workouts.isEmpty) {
      return _buildEmptyFilterState(isDark);
    }

    const double nodeWidth = 230.0;
    const double nodeSpacing = 36.0;
    final double totalWidth = math.max(
      MediaQuery.of(context).size.width * 1.5,
      workouts.length * (nodeWidth + nodeSpacing) + 200,
    );
    const double totalHeight = 650.0;
    final maxVol = workouts.map((w) => w.totalVolume).fold(1.0, math.max);

    return InteractiveViewer(
      transformationController: _transformCtrl,
      minScale: 0.35,
      maxScale: 3.8,
      boundaryMargin: const EdgeInsets.all(500),
      constrained: false,
      child: Container(
        width: totalWidth,
        height: totalHeight,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F141C) : const Color(0xFFF8FAFC),
        ),
        child: Stack(
          children: [
            CustomPaint(
              size: Size(totalWidth, totalHeight),
              painter: _TimelineGridPainter(isDark: isDark),
            ),
            CustomPaint(
              size: Size(totalWidth, totalHeight),
              painter: _VolumeSplinePainter(
                workouts: workouts,
                nodeWidth: nodeWidth,
                nodeSpacing: nodeSpacing,
                maxVolume: maxVol,
                isDark: isDark,
              ),
            ),
            Positioned(
              top: 260,
              left: 40,
              right: 40,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF38BDF8),
                      Color(0xFF818CF8),
                      Color(0xFFA855F7),
                      Color(0xFF10B981),
                    ],
                  ),
                ),
              ),
            ),
            ...workouts.asMap().entries.map((entry) {
              final idx = entry.key;
              final workout = entry.value;
              final posX = 60.0 + idx * (nodeWidth + nodeSpacing);
              final isPR = _allPrs.any((pr) =>
                  pr.achievedAt.year == workout.date.year &&
                  pr.achievedAt.month == workout.date.month &&
                  pr.achievedAt.day == workout.date.day);
              final isHighVolume = workout.totalVolume >= 6000;

              return Positioned(
                left: posX,
                top: 80,
                width: nodeWidth,
                child: _TimelineNodeCard(
                  workout: workout,
                  index: idx + 1,
                  isPR: isPR,
                  isHighVolume: isHighVolume,
                  unit: unit,
                  isDark: isDark,
                  onTap: () => _showWorkoutInspector(workout),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.filter_alt_off_rounded, size: 48, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            'No workouts match the current filter',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _selectedFilter = TimelineFilter.all),
            child: const Text('Clear Filter'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.4), width: 2),
              ),
              child: const Icon(
                Icons.auto_graph_rounded,
                size: 56,
                color: AppColors.accentViolet,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Journey Timeline',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Explore your training evolution on an up-to-down vertical branching timeline. Inspect progressive overload, sets, volume, and PR records across months.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => context.go('/today'),
              icon: const Icon(Icons.fitness_center_rounded),
              label: const Text('Start Logging Workouts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: context.isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _importJsonFile,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import JSON File'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper model for vertical branch timeline layout items
class _BranchTimelineItem {
  final bool isDivider;
  final String? monthName;
  final WorkoutModel? workout;
  final int index;
  final bool isLeft;
  final bool isPR;
  final bool isHighVolume;
  final double yPos;

  bool get isWorkout => !isDivider;
  double get junctionY => yPos + 60.0;

  const _BranchTimelineItem._({
    required this.isDivider,
    this.monthName,
    this.workout,
    this.index = 0,
    this.isLeft = true,
    this.isPR = false,
    this.isHighVolume = false,
    required this.yPos,
  });

  factory _BranchTimelineItem.monthDivider({
    required String monthName,
    required double yPos,
  }) {
    return _BranchTimelineItem._(
      isDivider: true,
      monthName: monthName,
      yPos: yPos,
    );
  }

  factory _BranchTimelineItem.workout({
    required WorkoutModel workout,
    required int index,
    required bool isLeft,
    required bool isPR,
    required bool isHighVolume,
    required double yPos,
  }) {
    return _BranchTimelineItem._(
      isDivider: false,
      workout: workout,
      index: index,
      isLeft: isLeft,
      isPR: isPR,
      isHighVolume: isHighVolume,
      yPos: yPos,
    );
  }
}

/// Vertical Branch Painter drawing the luminous central trunk and curved branching lines
class _VerticalBranchPainter extends CustomPainter {
  final List<_BranchTimelineItem> items;
  final double centerX;
  final double cardWidth;
  final double branchGap;
  final bool isDark;

  _VerticalBranchPainter({
    required this.items,
    required this.centerX,
    required this.cardWidth,
    required this.branchGap,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    // 1. Draw glowing vertical central trunk line
    final trunkTop = 38.0;
    final trunkBottom = size.height - 30.0;

    final trunkPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF38BDF8),
          Color(0xFF818CF8),
          Color(0xFFA855F7),
          Color(0xFF10B981),
        ],
      ).createShader(Rect.fromLTWH(centerX - 3, trunkTop, 6, trunkBottom - trunkTop))
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Glowing blur on trunk
    final trunkGlowPaint = Paint()
      ..color = AppColors.accentViolet.withValues(alpha: isDark ? 0.35 : 0.2)
      ..strokeWidth = 10.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawLine(Offset(centerX, trunkTop), Offset(centerX, trunkBottom), trunkGlowPaint);
    canvas.drawLine(Offset(centerX, trunkTop), Offset(centerX, trunkBottom), trunkPaint);

    // 2. Draw curved branch connectors and glowing junction nodes
    for (final item in items) {
      if (item.isDivider) continue;

      final junctionY = item.junctionY;
      final isLeft = item.isLeft;
      final targetX = isLeft ? (centerX - branchGap) : (centerX + branchGap);

      Color branchColor = isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
      if (item.isPR) {
        branchColor = const Color(0xFFF59E0B);
      } else if (item.isHighVolume) {
        branchColor = AppColors.accentEmerald;
      }

      // Smooth curved branch line
      final path = Path()..moveTo(centerX, junctionY);
      final controlX = isLeft ? (centerX - branchGap * 0.5) : (centerX + branchGap * 0.5);
      path.cubicTo(
        controlX,
        junctionY,
        controlX,
        junctionY,
        targetX,
        junctionY,
      );

      final branchPaint = Paint()
        ..color = branchColor
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Glow on branch
      final branchGlowPaint = Paint()
        ..color = branchColor.withValues(alpha: 0.3)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawPath(path, branchGlowPaint);
      canvas.drawPath(path, branchPaint);

      // Junction node on central trunk
      final outerRingPaint = Paint()
        ..color = branchColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, junctionY), 9.0, outerRingPaint);

      final nodePaint = Paint()
        ..color = branchColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, junctionY), 5.5, nodePaint);

      final centerDotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, junctionY), 2.2, centerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalBranchPainter oldDelegate) =>
      oldDelegate.items != items || oldDelegate.isDark != isDark;
}

/// Node Card used in Vertical Branch Tree
class _TimelineBranchCard extends StatelessWidget {
  final WorkoutModel workout;
  final int index;
  final bool isLeft;
  final bool isPR;
  final bool isHighVolume;
  final WeightUnit unit;
  final bool isDark;
  final VoidCallback onTap;

  const _TimelineBranchCard({
    required this.workout,
    required this.index,
    required this.isLeft,
    required this.isPR,
    required this.isHighVolume,
    required this.unit,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d').format(workout.date);
    final volumeStr = UnitConverter.formatWeight(workout.totalVolume, unit: unit);

    Color borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    Color glowColor = Colors.transparent;

    if (isPR) {
      borderColor = const Color(0xFFF59E0B);
      glowColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
    } else if (isHighVolume) {
      borderColor = AppColors.accentEmerald;
      glowColor = AppColors.accentEmerald.withValues(alpha: 0.3);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161C27) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isPR ? 1.8 : 1.2),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.4) : const Color(0x0C000000),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
            if (glowColor != Colors.transparent)
              BoxShadow(
                color: glowColor,
                blurRadius: 14,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Date & Session index + PR/HighVol badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222B3D) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '#$index',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const Spacer(),
                if (isPR) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 12),
                        SizedBox(width: 3),
                        Text(
                          'PR',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isHighVolume) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: AppColors.accentEmerald, size: 12),
                        SizedBox(width: 3),
                        Text(
                          'HIGH VOL',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),

            // Workout Title
            Text(
              workout.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),

            // Metrics row: Volume + Sets
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  volumeStr,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isPR
                        ? const Color(0xFFF59E0B)
                        : (isHighVolume ? AppColors.accentEmerald : context.accent),
                  ),
                ),
                Text(
                  '${workout.totalSetsCount} sets completed',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Exercises pills
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: workout.exercises.take(3).map((e) {
                final mgColor = AppColors.muscleGroupColors[e.exercise.muscleGroupId] ?? context.accent;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: mgColor)),
                      const SizedBox(width: 4),
                      Text(
                        e.exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 8),
            // Inspect link
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Inspect',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 9,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Node Card used in Horizontal Track view
class _TimelineNodeCard extends StatelessWidget {
  final WorkoutModel workout;
  final int index;
  final bool isPR;
  final bool isHighVolume;
  final WeightUnit unit;
  final bool isDark;
  final VoidCallback onTap;

  const _TimelineNodeCard({
    required this.workout,
    required this.index,
    required this.isPR,
    required this.isHighVolume,
    required this.unit,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d').format(workout.date);
    final volumeStr = UnitConverter.formatWeight(workout.totalVolume, unit: unit);

    Color borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1);
    Color glowColor = Colors.transparent;

    if (isPR) {
      borderColor = const Color(0xFFF59E0B);
      glowColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
    } else if (isHighVolume) {
      borderColor = AppColors.accentEmerald;
      glowColor = AppColors.accentEmerald.withValues(alpha: 0.3);
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              dateStr,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 2,
            height: 14,
            color: borderColor,
          ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isPR ? const Color(0xFFF59E0B) : (isHighVolume ? AppColors.accentEmerald : AppColors.accentViolet),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161C26) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: isPR ? 2.0 : 1.2),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.4) : const Color(0x0F000000),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      volumeStr,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPR
                            ? const Color(0xFFF59E0B)
                            : (isHighVolume ? AppColors.accentEmerald : context.accent),
                      ),
                    ),
                    Text(
                      '${workout.totalSetsCount} sets',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inspection Modal Bottom Sheet showing detailed sets, exercises, and PRs
class _WorkoutInspectionSheet extends ConsumerWidget {
  final WorkoutModel workout;
  final List<PrItemData> prs;

  const _WorkoutInspectionSheet({
    required this.workout,
    required this.prs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unit = ref.watch(weightUnitNotifierProvider);
    final dateFormatted = DateFormat('EEEE, MMMM d, y').format(workout.date);
    final durationStr = workout.duration != null
        ? '${workout.duration!.inMinutes} min'
        : 'Completed';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151922) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        math.max(MediaQuery.of(context).viewPadding.bottom, 16.0),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateFormatted • $durationStr',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2533) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInspectionStat(
                  'VOLUME',
                  UnitConverter.formatWeight(workout.totalVolume, unit: unit),
                  context.accent,
                ),
                _buildInspectionStat(
                  'SETS',
                  '${workout.totalSetsCount}',
                  AppColors.accentEmerald,
                ),
                _buildInspectionStat(
                  'EXERCISES',
                  '${workout.exercises.length}',
                  AppColors.accentViolet,
                ),
                if (prs.isNotEmpty)
                  _buildInspectionStat(
                    'PRS HIT',
                    '${prs.length}',
                    const Color(0xFFF59E0B),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (prs.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PRs: ${prs.map((p) => '${p.exerciseName} (${UnitConverter.formatWeight(p.value, unit: unit)})').join(', ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Expanded(
            child: ListView.separated(
              itemCount: workout.exercises.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final we = workout.exercises[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B222E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.muscleGroupColors[we.exercise.muscleGroupId] ?? context.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              we.exercise.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            we.exercise.muscleGroupId.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: we.sets.where((s) => !s.archived).map((s) {
                          final weightStr = UnitConverter.formatWeight(s.weight, unit: unit);
                          final isWarm = s.setType == SetType.warmup;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isWarm
                                  ? (isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0))
                                  : (isDark ? const Color(0xFF2B3648) : Colors.white),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: Text(
                              isWarm
                                  ? 'W: $weightStr × ${s.reps}'
                                  : '${s.setIndex + 1}: $weightStr × ${s.reps}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isWarm
                                    ? (isDark ? Colors.white54 : Colors.black45)
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                final dateParam = DateFormat('yyyy-MM-dd').format(workout.date);
                context.go('/today?date=$dateParam');
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: const Text('Open Workout in Today Log'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

/// Canvas Grid Painter
class _TimelineGridPainter extends CustomPainter {
  final bool isDark;

  _TimelineGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.025)
      ..strokeWidth = 1.0;

    for (double y = 40; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 40; x < size.width; x += 120) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter drawing the continuous progressive overload volume curve (for horizontal mode)
class _VolumeSplinePainter extends CustomPainter {
  final List<WorkoutModel> workouts;
  final double nodeWidth;
  final double nodeSpacing;
  final double maxVolume;
  final bool isDark;

  _VolumeSplinePainter({
    required this.workouts,
    required this.nodeWidth,
    required this.nodeSpacing,
    required this.maxVolume,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (workouts.length < 2) return;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < workouts.length; i++) {
      final x = 60.0 + i * (nodeWidth + nodeSpacing) + (nodeWidth / 2);
      final vol = workouts[i].totalVolume;
      final pct = (vol / (maxVolume > 0 ? maxVolume : 1.0)).clamp(0.05, 1.0);
      final y = 340.0 + (pct * 200.0);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, 600)
      ..lineTo(points.first.dx, 600)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accentViolet.withValues(alpha: isDark ? 0.25 : 0.12),
          AppColors.accentViolet.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 300, size.width, 300));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF38BDF8),
          Color(0xFF818CF8),
          Color(0xFFA855F7),
          Color(0xFF10B981),
        ],
      ).createShader(Rect.fromLTWH(0, 300, size.width, 300))
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _VolumeSplinePainter oldDelegate) =>
      oldDelegate.workouts != workouts || oldDelegate.maxVolume != maxVolume;
}
