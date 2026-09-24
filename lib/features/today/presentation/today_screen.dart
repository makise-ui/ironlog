import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/services/backup_service.dart';
import '../../../domain/services/home_widget_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../domain/models/workout_model.dart';
import '../../../domain/models/routine_model.dart';
import '../../../domain/models/suggestion_model.dart';
import '../../../domain/services/suggestion_engine.dart';
import '../../../domain/services/pr_detector.dart';
import '../../../data/providers.dart';
import 'exercise_picker_sheet.dart';
import 'workout_notes_dialog.dart';
import 'copy_session_sheet.dart';
import '../../routines/presentation/routines_sheet.dart';
import '../../paste_importer/presentation/paste_importer_sheet.dart';
import 'rest_timer_overlay.dart';
import 'widgets/exercise_table_card.dart';
import 'widgets/docked_workout_numpad.dart';
import '../../../domain/models/active_workout_input.dart';
import '../../../domain/models/set_model.dart';
import 'confetti_celebration.dart';
import 'workout_summary_dialog.dart';
import 'suggestion_explain_sheet.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/scale_tap.dart';
import 'widgets/today_hero_session_card.dart';
import 'widgets/this_week_progress_bar.dart';
import 'widgets/section_header.dart';
import 'widgets/routine_card.dart';
import '../../routines/presentation/create_preset_sheet.dart';
import '../../intro/presentation/onboarding_sheet.dart';


class TodayScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  const TodayScreen({super.key, this.initialDate});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  WorkoutModel? _workout;
  bool _isLoading = true;
  bool _sessionLeft = false;
  late DateTime _selectedDate;
  final Set<String> _selectedMuscleGroupIds = {};
  List<Suggestion> _suggestions = [];
  PrResult? _activePr;

  Timer? _elapsedTimer;
  Duration _elapsedDuration = Duration.zero;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? ref.read(selectedWorkoutDateProvider);
    _selectedDate = AppDateUtils.normalizeDate(initial ?? DateTime.now());
    _loadWorkoutForDate(_selectedDate);
    _startElapsedTimer();

    _lifecycleListener = AppLifecycleListener(
      onPause: () {
        BackupService.autoBackup(ref.read(databaseProvider));
      },
      onDetach: () {
        BackupService.autoBackup(ref.read(databaseProvider));
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndPromptBackupRestore();
      if (mounted) {
        OnboardingSheet.showIfNeeded(context, ref);
      }
    });
  }

  Future<void> _checkAndPromptBackupRestore() async {
    try {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final alreadyChecked = await settingsRepo.getSetting('initial_backup_restore_checked');
      if (alreadyChecked == 'true') return;

      final db = ref.read(databaseProvider);
      final totalSetsRow = await db.customSelect('SELECT COUNT(*) as count FROM sets WHERE archived = 0').getSingle();
      final totalSets = totalSetsRow.data['count'] as int? ?? 0;

      // If the user already has real logged sets, this is not an empty installation needing restore
      if (totalSets > 0) {
        await settingsRepo.setSetting('initial_backup_restore_checked', 'true');
        return;
      }

      final backupInfo = await BackupService.findExistingBackup();
      if (backupInfo == null || (backupInfo.workoutCount == 0 && backupInfo.setCount == 0) || !mounted) {
        return;
      }

      final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(backupInfo.modifiedAt);
      final greeting = backupInfo.athleteName != null && backupInfo.athleteName!.isNotEmpty
          ? 'Welcome back, ${backupInfo.athleteName}!'
          : 'Welcome back!';

      final shouldRestore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: context.accent.withValues(alpha: 0.3), width: 1.5),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_download_rounded, color: context.accent, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restore Workouts?',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      greeting,
                      style: TextStyle(
                        color: context.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'We found saved workout history on your device from a previous installation. Would you like to restore your workouts, PRs, and profile?',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.cardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fitness_center_rounded, size: 16, color: context.accent),
                        const SizedBox(width: 8),
                        Text('Workouts:', style: TextStyle(color: context.textSecondary, fontSize: 13)),
                        const Spacer(),
                        Text('${backupInfo.workoutCount}', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.format_list_numbered_rounded, size: 16, color: context.accent),
                        const SizedBox(width: 8),
                        Text('Logged Sets:', style: TextStyle(color: context.textSecondary, fontSize: 13)),
                        const Spacer(),
                        Text('${backupInfo.setCount}', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: context.textTertiary),
                        const SizedBox(width: 8),
                        Text('Last Saved:', style: TextStyle(color: context.textSecondary, fontSize: 13)),
                        const Spacer(),
                        Text(formattedDate, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
              },
              child: Text(
                'Start Fresh',
                style: TextStyle(color: context.textTertiary, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: context.isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restore_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Restore Progress', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );

      // Record that we completed the initial check so we don't prompt on subsequent route changes
      await settingsRepo.setSetting('initial_backup_restore_checked', 'true');

      if (shouldRestore == true && mounted) {
        final count = await BackupService.restoreFromPath(db, backupInfo.path);
        await _refreshWorkout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Restored $count workouts and ${backupInfo.setCount} sets successfully!',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: context.isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking backup: $e');
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Duration _calculateElapsedDuration(WorkoutModel? w) {
    if (w == null) return Duration.zero;
    if (w.endedAt != null && w.startedAt != null) {
      return w.endedAt!.difference(w.startedAt!);
    } else if (w.startedAt != null) {
      if (_sessionLeft) {
        // Workout is paused — preserve the frozen elapsed duration
        return _elapsedDuration > Duration.zero
            ? _elapsedDuration
            : DateTime.now().difference(w.startedAt!);
      }
      return DateTime.now().difference(w.startedAt!);
    }
    return Duration.zero;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    if (_sessionLeft) return; // Do not tick while paused
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionLeft) {
        _elapsedTimer?.cancel();
        _elapsedTimer = null;
        return;
      }
      if (_workout != null && _workout!.startedAt != null) {
        if (_workout!.endedAt != null) {
          // Workout completed; timer stopped
          _elapsedTimer?.cancel();
          _elapsedTimer = null;
          return;
        }
        final diff = DateTime.now().difference(_workout!.startedAt!);
        if (mounted) {
          setState(() {
            _elapsedDuration = diff;
          });
        }
      }
    });
  }

  void _resumeWorkout() {
    if (_workout != null && _workout!.startedAt != null) {
      // Adjust startedAt forward by the duration paused so elapsed time does not jump
      final adjustedStart = DateTime.now().subtract(_elapsedDuration);
      _workout = _workout!.copyWith(startedAt: adjustedStart);
      ref.read(workoutRepositoryProvider).startWorkout(_workout!.id, startedAt: adjustedStart);
    }
    setState(() => _sessionLeft = false);
    _startElapsedTimer();
  }

  Future<void> _loadWorkoutForDate(DateTime date) async {
    setState(() => _isLoading = true);
    final repo = ref.read(workoutRepositoryProvider);
    final isToday = AppDateUtils.isSameDay(date, DateTime.now());

    WorkoutModel? w;
    if (isToday) {
      w = await repo.getOrCreateTodayWorkout();
    } else {
      w = await repo.getWorkoutForDate(date);
    }

    final history = await repo.getRecentWorkouts(limit: 20);
    final suggestions = w != null
        ? SuggestionEngine().evaluateAll(currentWorkout: w, history: history)
        : <Suggestion>[];

    if (mounted) {
      setState(() {
        _selectedDate = AppDateUtils.normalizeDate(date);
        _workout = w;
        _suggestions = suggestions;
        _isLoading = false;
        _elapsedDuration = _calculateElapsedDuration(w);
      });
    }
  }

  Future<void> _refreshWorkout() async {
    if (_workout == null) {
      await _loadWorkoutForDate(_selectedDate);
      return;
    }
    final repo = ref.read(workoutRepositoryProvider);
    final w = await repo.getWorkoutById(_workout!.id);

    final history = await repo.getRecentWorkouts(limit: 20);
    final suggestions = SuggestionEngine().evaluateAll(
      currentWorkout: w,
      history: history,
    );

    if (mounted) {
      setState(() {
        _workout = w;
        _suggestions = suggestions;
        _elapsedDuration = _calculateElapsedDuration(w);
      });
      unawaited(_syncHomeWidgets());
    }
  }

  Future<void> _syncHomeWidgets() async {
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final streakData = await repo.getStreakAndWeekData();
      final hasActive = _workout != null &&
          _workout!.exercises.isNotEmpty &&
          _workout!.endedAt == null &&
          !_sessionLeft;

      final firstActiveEx = _workout?.exercises.where((e) => !e.archived).firstOrNull;
      final activeSets = firstActiveEx?.sets.where((s) => !s.archived).toList() ?? [];

      await HomeWidgetService.syncAllWidgets(
        currentWorkout: _workout,
        streakDays: streakData.streakDays,
        daysTrainedThisWeek: streakData.workoutsThisWeek,
        isSessionActive: hasActive,
        elapsedDuration: _elapsedDuration,
        currentExerciseName: firstActiveEx?.exercise.name,
        currentSetNumber: activeSets.length + 1,
        totalExerciseSets: activeSets.length + 3,
        totalVolumeKg: _workout?.totalVolume,
      );
    } catch (e) {
      debugPrint('Error syncing home widgets: $e');
    }
  }

  Future<void> _ensureWorkoutCreated() async {
    if (_workout == null) {
      final repo = ref.read(workoutRepositoryProvider);
      final w = await repo.getOrCreateWorkoutForDate(_selectedDate);
      _workout = w;
    }
  }

  void _startWorkout() async {
    AppHaptics.tap();
    await _ensureWorkoutCreated();
    if (_workout == null) return;
    final repo = ref.read(workoutRepositoryProvider);
    await repo.startWorkout(_workout!.id);
    await _refreshWorkout();
  }

  void _startNewWorkoutToday() async {
    AppHaptics.tap();
    final repo = ref.read(workoutRepositoryProvider);
    final newW = await repo.createNewWorkoutForDate(_selectedDate);
    setState(() {
      _workout = newW;
      _elapsedDuration = Duration.zero;
      _selectedMuscleGroupIds.clear();
    });
    await _refreshWorkout();
  }

  void _pickDate() async {
    AppHaptics.tap();
    final today = AppDateUtils.normalizeDate(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: today, // STRICT: NEVER ALLOW FUTURE DATE
      builder: (context, child) {
        return Theme(
          data: context.isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
          child: child!,
        );
      },
    );
    if (!mounted) return;
    if (picked != null) {
      final norm = AppDateUtils.normalizeDate(picked);
      ref.read(selectedWorkoutDateProvider.notifier).state = norm;
      _loadWorkoutForDate(norm);
    }
  }

  void _openExercisePicker() async {
    AppHaptics.tap();
    await _ensureWorkoutCreated();
    if (!mounted || _workout == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExercisePickerSheet(
        workoutId: _workout!.id,
        initialMuscleGroupId: _selectedMuscleGroupIds.isNotEmpty ? _selectedMuscleGroupIds.first : null,
        onExerciseSelected: (ex) async {
          final repo = ref.read(workoutRepositoryProvider);
          final weId = await repo.addExerciseToWorkout(
            workoutId: _workout!.id,
            exerciseId: ex.id,
          );
          ExerciseTableCard.setExerciseExpanded(weId, true);
          _selectedMuscleGroupIds.add(ex.muscleGroupId);
          setState(() => _sessionLeft = false);
          _refreshWorkout();
        },
      ),
    );
  }

  void _openRoutines() async {
    AppHaptics.tap();
    await _ensureWorkoutCreated();
    if (!mounted || _workout == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoutinesSheet(
        workoutId: _workout!.id,
        onRoutineApplied: _refreshWorkout,
      ),
    );
  }

  void _openCopySession() async {
    AppHaptics.tap();
    await _ensureWorkoutCreated();
    if (!mounted || _workout == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CopySessionSheet(
        targetWorkoutId: _workout!.id,
        onCopied: _refreshWorkout,
      ),
    );
  }

  void _openPasteImporter() {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PasteImporterSheet(
        onImportCompleted: () => _loadWorkoutForDate(_selectedDate),
      ),
    );
  }

  void _markRestDay({required bool isRest}) async {
    AppHaptics.tap();
    await _ensureWorkoutCreated();
    if (!mounted || _workout == null) return;
    final repo = ref.read(workoutRepositoryProvider);
    await repo.markAsRestDay(_workout!.id, isRest: isRest);
    _refreshWorkout();
  }

  void _openNotesDialog() async {
    await _ensureWorkoutCreated();
    if (!mounted || _workout == null) return;
    AppHaptics.tap();
    showDialog(
      context: context,
      builder: (ctx) => WorkoutNotesDialog(
        currentTitle: _workout!.title,
        currentNote: _workout!.note,
        currentFeel: _workout!.feel,
        onSave: (title, note, feel) async {
          final repo = ref.read(workoutRepositoryProvider);
          await repo.updateWorkoutMeta(
            workoutId: _workout!.id,
            title: title,
            note: note,
            feel: feel,
          );
          _refreshWorkout();
        },
      ),
    );
  }

  void _applySuggestedRoutine() async {
    await _ensureWorkoutCreated();
    if (_workout == null) return;
    AppHaptics.success();
    final nextSug = _suggestions.where((s) => s.type == SuggestionType.nextWorkout).firstOrNull;
    final routineKey = nextSug?.payload['routineKey'] as String? ?? 'push_a';

    final routineRepo = ref.read(routineRepositoryProvider);
    final allRoutines = await routineRepo.getRoutines();
    final targetRoutine = allRoutines.where((r) => r.id == routineKey).firstOrNull ?? allRoutines.first;

    final repo = ref.read(workoutRepositoryProvider);
    await repo.applyRoutineToWorkout(_workout!.id, targetRoutine.id);
    // Note: Do NOT call repo.startWorkout here; workout timer only starts on Start or set log.
    setState(() => _sessionLeft = false);
    _refreshWorkout();
  }

  void _applySpecificRoutine(String routineId) async {
    await _ensureWorkoutCreated();
    if (_workout == null) return;
    AppHaptics.success();
    final repo = ref.read(workoutRepositoryProvider);
    await repo.applyRoutineToWorkout(_workout!.id, routineId);
    // Note: Do NOT call repo.startWorkout here; workout timer only starts on Start or set log.
    setState(() => _sessionLeft = false);
    _refreshWorkout();
  }

  void _confirmApplySpecificRoutine(RoutineModel routine) async {
    await _ensureWorkoutCreated();
    if (_workout == null || !mounted) return;
    AppHaptics.tap();

    final activeExercises = _workout!.exercises.where((e) => !e.archived).toList();
    if (activeExercises.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.cardBorder),
          ),
          title: Text(
            'Load "${routine.name}"?',
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Text(
            'Your session already has ${activeExercises.length} active exercise(s). Would you like to append these ${routine.items.length} exercises or replace the current session?',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text('Cancel', style: TextStyle(color: context.textTertiary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('Replace Existing', style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: context.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, 'append'),
              child: const Text('Add to Workout'),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel' || !mounted) return;

      if (choice == 'replace') {
        final repo = ref.read(workoutRepositoryProvider);
        for (final ex in activeExercises) {
          await repo.removeExerciseFromWorkout(ex.id);
        }
      }
      _applySpecificRoutine(routine.id);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.cardBorder),
          ),
          title: Text(
            'Load "${routine.name}"?',
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Text(
            'Load ${routine.items.length} exercise(s) into today\'s session:\n• ${routine.items.map((i) => i.exercise.name).join('\n• ')}\n\nThe timer will only start when you tap Start or log a set.',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
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
              child: const Text('Load Routine'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        _applySpecificRoutine(routine.id);
      }
    }
  }

  void _finishWorkout() {
    if (_workout == null) return;
    AppHaptics.tap();
    final unit = ref.read(weightUnitNotifierProvider);

    showDialog(
      context: context,
      builder: (ctx) => WorkoutSummaryDialog(
        workout: _workout!,
        elapsed: _elapsedDuration,
        unit: unit,
        onFinish: (feel, note) async {
          final repo = ref.read(workoutRepositoryProvider);
          final end = DateTime.now();
          final start = _workout!.startedAt ??
              end.subtract(_elapsedDuration > Duration.zero ? _elapsedDuration : const Duration(minutes: 45));

          _elapsedTimer?.cancel();
          _elapsedTimer = null;
          setState(() {
            _sessionLeft = false;
            _workout = _workout?.copyWith(
              startedAt: start,
              endedAt: end,
              feel: feel,
              note: note,
            );
          });
          ref.read(isWorkoutActiveProvider.notifier).state = false;

          await repo.updateWorkoutMeta(
            workoutId: _workout!.id,
            endedAt: end,
            feel: feel,
            note: note,
          );
          if (_workout!.startedAt == null) {
            await repo.startWorkout(_workout!.id, startedAt: start);
          }
          await _refreshWorkout();
          unawaited(BackupService.autoBackup(ref.read(databaseProvider)));
          if (mounted) {
            ConfettiCelebration.show(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Workout finished, saved & backed up to phone storage!',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: context.isDark ? const Color(0xFF2B2B2B) : const Color(0xFF3F3F46),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
      ),
    );
  }

  void _reopenWorkout() async {
    if (_workout == null) return;
    AppHaptics.tap();
    final repo = ref.read(workoutRepositoryProvider);
    await repo.reopenWorkout(_workout!.id);
    setState(() {
      _sessionLeft = false;
      _workout = _workout?.copyWith(endedAt: null);
    });
    _startElapsedTimer();
    await _refreshWorkout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.replay_rounded, color: context.accent, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Workout reopened! You can continue logging sets.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: context.isDark ? const Color(0xFF2B2B2B) : const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleNumpadLogSet(ActiveWorkoutInput input) async {
    final repo = ref.read(workoutRepositoryProvider);
    final targetItem = _workout?.exercises.where((e) => e.id == input.workoutExerciseId).firstOrNull;
    if (targetItem == null) return;

    final newSetId = await repo.logSet(
      workoutExerciseId: input.workoutExerciseId,
      exerciseId: input.exerciseId,
      muscleGroupId: targetItem.exercise.muscleGroupId,
      date: DateTime.now(),
      weight: input.effectiveWeight,
      reps: input.effectiveReps,
      setType: input.setType,
    );

    // Rest timer
    ref.read(restTimerProvider).start(
      seconds: targetItem.exercise.restSeconds,
      exerciseName: targetItem.exercise.name,
    );

    // PR Check
    final allHistory = await repo.getAllHistoricalSetsForExercise(input.exerciseId);
    final newlyCreatedSet = SetModel(
      id: newSetId,
      workoutExerciseId: input.workoutExerciseId,
      exerciseId: input.exerciseId,
      muscleGroupId: targetItem.exercise.muscleGroupId,
      date: DateTime.now(),
      setIndex: input.setIndex,
      weight: input.effectiveWeight,
      reps: input.effectiveReps,
      setType: input.setType,
      completedAt: DateTime.now(),
    );

    final prCheck = PrDetector.checkSetPr(
      newSet: newlyCreatedSet,
      historicalSets: allHistory,
      weightUnit: input.unit.label,
    );

    if (prCheck.isPr) {
      AppHaptics.pr();
      setState(() => _activePr = prCheck);
    } else {
      AppHaptics.success();
    }

    await _refreshWorkout();

    // Auto-advance to next set
    ref.read(activeWorkoutInputProvider.notifier).startEditing(
      workoutExerciseId: input.workoutExerciseId,
      exerciseId: input.exerciseId,
      exerciseName: input.exerciseName,
      equipment: input.equipment,
      setIndex: input.setIndex + 1,
      existingSetId: null,
      setType: SetType.working,
      field: WorkoutInputField.weight,
      initialWeight: input.effectiveWeight,
      initialReps: input.effectiveReps,
      unit: input.unit,
      isCompleted: false,
    );
  }

  Future<void> _handleNumpadUpdateSet(ActiveWorkoutInput input) async {
    if (input.existingSetId == null) return;
    final repo = ref.read(workoutRepositoryProvider);
    await repo.updateSet(
      setId: input.existingSetId!,
      weight: input.effectiveWeight,
      reps: input.effectiveReps,
      setType: input.setType,
    );
    await _refreshWorkout();
    ref.read(activeWorkoutInputProvider.notifier).close();
  }

  void _leaveSession() {
    ref.read(activeWorkoutInputProvider.notifier).close();
    AppHaptics.tap();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1118) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.07),
            width: 1.2,
          ),
        ),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.pause_circle_outline_rounded, color: context.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave Workout Session?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Save draft or discard session',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'You can leave this session saved as a draft to resume later, or discard it completely.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ScaleTap(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _discardWorkout();
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181B24) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Discard',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ScaleTap(
                  onPressed: () => Navigator.pop(ctx),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181B24) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ScaleTap(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _elapsedTimer?.cancel();
                    _elapsedTimer = null;
                    setState(() {
                      _sessionLeft = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Session saved as draft. You can continue anytime!'),
                        backgroundColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFF1A1A1A),
                      ),
                    );
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Save & Leave',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF171717) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _discardWorkout() {
    AppHaptics.warning();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1118) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.07),
            width: 1.2,
          ),
        ),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discard Workout?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Today\'s workout log will be cleared',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to discard this workout? All exercises and sets logged today will be removed.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ScaleTap(
                  onPressed: () => Navigator.pop(ctx),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181B24) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ScaleTap(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (_workout != null) {
                      final repo = ref.read(workoutRepositoryProvider);
                      await repo.discardWorkout(_workout!.id);
                      _elapsedTimer?.cancel();
                      _elapsedDuration = Duration.zero;
                      setState(() {
                        _sessionLeft = false;
                      });
                      await _loadWorkoutForDate(_selectedDate);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Workout discarded.'),
                            backgroundColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFF1A1A1A),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Discard',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _removeExercise(WorkoutExerciseItem item) async {
    final repo = ref.read(workoutRepositoryProvider);
    await repo.removeExerciseFromWorkout(item.id);
    _refreshWorkout();

    if (mounted) {
      UndoSnackbar.show(
        context,
        message: '${item.exercise.name} removed',
        onUndo: () async {
          await repo.restoreWorkoutExercise(item.id);
          _refreshWorkout();
        },
      );
    }
  }

  String _formatTimer(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildCompletedHeroCard(BuildContext context, WeightUnit unit) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder, width: 1.0),
        boxShadow: context.isDark
            ? null
            : [
                const BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Session Completed',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamilyDisplay,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        if (_workout?.feel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: C.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ['Tough', 'Fatigued', 'Okay', 'Good', 'Crushed'][(_workout!.feel! - 1).clamp(0, 4)],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: C.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Finished at ${_workout?.endedAt != null ? DateFormat.jm().format(_workout!.endedAt!) : 'Today'} • Saved to History',
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Metrics summary row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF262626) : const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCol('TIME', _formatTimer(_elapsedDuration), context),
                Container(width: 1, height: 24, color: context.cardBorder),
                _buildStatCol('SETS', '${_workout?.totalSetsCount ?? 0} sets', context),
                Container(width: 1, height: 24, color: context.cardBorder),
                _buildStatCol('VOLUME', UnitConverter.formatWeight(_workout?.totalVolume ?? 0, unit: unit), context),
              ],
            ),
          ),
          if (_workout?.note != null && _workout!.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Note: ${_workout!.note}',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: context.textTertiary),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reopenWorkout,
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Reopen Session'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPrimary,
                    side: BorderSide(color: context.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startNewWorkoutToday,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accent,
                    foregroundColor: context.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9.5, color: context.textTertiary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  void _openCreatePreset() {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreatePresetSheet(),
    ).then((_) => ref.invalidate(routinesProvider));
  }

  Widget _buildQuietPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ScaleTap(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: C.text2),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: C.text2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    C.isDark = Theme.of(context).brightness == Brightness.dark;
    final unit = ref.watch(weightUnitNotifierProvider);
    final streakAsync = ref.watch(streakAndWeekProvider);
    final streakData = streakAsync.valueOrNull;
    final routinesAsync = ref.watch(routinesProvider);
    final allRoutines = routinesAsync.valueOrNull ?? [];

    final activeExercises = _workout?.exercises.where((e) => !e.archived).toList() ?? [];
    final nextWorkoutSug = _suggestions.where((s) => s.type == SuggestionType.nextWorkout).firstOrNull;
    ref.listen<DateTime>(selectedWorkoutDateProvider, (prev, next) {
      if (prev != next && !AppDateUtils.isSameDay(_selectedDate, next)) {
        _loadWorkoutForDate(next);
      }
    });

    final isToday = AppDateUtils.isSameDay(_selectedDate, DateTime.now());
    final isPastDate = !isToday;
    final isRestDay = _workout?.isRestDay == true && activeExercises.isEmpty;
    final isFinished = !isRestDay && _workout?.endedAt != null;
    final hasActiveWorkout = activeExercises.isNotEmpty && !isFinished && !_sessionLeft;

    // Keep navigation shell in sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(isWorkoutActiveProvider) != hasActiveWorkout) {
        ref.read(isWorkoutActiveProvider.notifier).state = hasActiveWorkout;
      }
    });

    // Listen for back gesture collapse signal from root navigation shell
    ref.listen<int>(requestCollapseWorkoutProvider, (prev, next) {
      if (next > (prev ?? 0)) {
        if (ref.read(activeWorkoutInputProvider) != null) {
          ref.read(activeWorkoutInputProvider.notifier).close();
          return;
        }
        if (hasActiveWorkout) {
          AppHaptics.tap();
          setState(() => _sessionLeft = true);
        }
      }
    });

    // Determine Hero Card details
    String suggestedTitle = 'Full Body Blast';
    String suggestedSubtitle = 'Comprehensive strength & hypertrophy stimulus';
    int suggestedExCount = 4;
    int suggestedMinutes = 45;

    if (nextWorkoutSug != null) {
      suggestedTitle = nextWorkoutSug.title;
      suggestedSubtitle = nextWorkoutSug.body;
      final pMin = nextWorkoutSug.payload['estimatedMinutes'] as num?;
      if (pMin != null) {
        suggestedMinutes = pMin.toInt();
      }
      final exList = nextWorkoutSug.payload['exercises'] as List?;
      if (exList != null && exList.isNotEmpty) {
        suggestedExCount = exList.length;
        suggestedMinutes = (suggestedExCount * 9).clamp(25, 75);
      }
    } else if (allRoutines.isNotEmpty) {
      final r = allRoutines.first;
      suggestedTitle = r.name;
      suggestedExCount = r.items.length;
      suggestedMinutes = (suggestedExCount * 9).clamp(25, 75);
      suggestedSubtitle = 'Targeted Routine · Progressive Overload';
    }

    // MODE 1: COACH HOME SCREEN
    Widget homeContent = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        // 1. Slim header, edge-to-edge
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(S.xl, S.sm, S.xl, S.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScaleTap(
                  onPressed: _pickDate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('EEE, MMM d').format(_selectedDate),
                        style: T.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: C.text2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.calendar_today_rounded, size: 14, color: C.text2),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTap(
                      onPressed: () {
                        AppHaptics.tap();
                        context.push('/nutrition');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.accent.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant_rounded, size: 14, color: C.accent),
                            const SizedBox(width: 5),
                            Text(
                              'Fuel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: C.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 15, color: Color(0xFFF97316)),
                          const SizedBox(width: 4),
                          Text(
                            '${streakData?.streakDays ?? 0}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: C.text1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Past Date Banner
        if (isPastDate)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(S.xl, S.xs, S.xl, S.sm),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: C.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: C.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Viewing: ${DateFormat('EEE, MMM d, yyyy').format(_selectedDate)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: C.text1,
                      ),
                    ),
                  ),
                  ScaleTap(
                    onPressed: () {
                      AppHaptics.tap();
                      final today = AppDateUtils.normalizeDate(DateTime.now());
                      ref.read(selectedWorkoutDateProvider.notifier).state = today;
                      _loadWorkoutForDate(today);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Back to Today',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: C.onAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 2. Greeting
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(S.xl, S.md, S.xl, S.lg),
            child: Text(
              isRestDay
                  ? 'Rest & Recovery Day'
                  : (isFinished
                      ? (isToday ? 'Great work today!' : 'Workout Completed!')
                      : (isToday ? 'Ready to train today?' : 'Logging for ${DateFormat('EEE, MMM d').format(_selectedDate)}')),
              style: T.display.copyWith(color: C.text1),
            ),
          ),
        ),

        // 3. THE HERO SESSION CARD
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.xl),
            child: TodayHeroSessionCard(
              title: isRestDay
                  ? 'Rest & Recovery Day'
                  : (isFinished
                      ? (_workout?.title ?? 'Completed Workout')
                      : (_sessionLeft && activeExercises.isNotEmpty
                          ? (_workout?.title ?? 'Paused Workout')
                          : (isPastDate
                              ? (_workout?.title ?? 'Workout - ${DateFormat('MMM d').format(_selectedDate)}')
                              : suggestedTitle))),
              subtitle: isRestDay
                  ? (isToday
                      ? 'Muscle tissue repairs and streak is preserved.'
                      : 'Marked as Rest & Recovery on ${DateFormat('EEE, MMM d').format(_selectedDate)}')
                  : (isFinished
                      ? 'Completed on ${DateFormat('EEE, MMM d').format(_selectedDate)} • ${activeExercises.length} exercises • ${_workout?.totalSetsCount ?? 0} sets'
                      : (_sessionLeft && activeExercises.isNotEmpty
                          ? '${activeExercises.length} exercises • ${_workout?.totalSetsCount ?? 0} sets'
                          : (isPastDate
                              ? 'Tap to select movements and log sets for this date'
                              : suggestedSubtitle))),
              exerciseCount: isFinished
                  ? activeExercises.length
                  : (_sessionLeft && activeExercises.isNotEmpty ? activeExercises.length : (isPastDate ? activeExercises.length : suggestedExCount)),
              estimatedMinutes: isFinished ? _elapsedDuration.inMinutes.clamp(15, 120) : suggestedMinutes,
              isActive: isFinished || (_sessionLeft && activeExercises.isNotEmpty),
              isPaused: !isFinished && _sessionLeft && activeExercises.isNotEmpty,
              isRestDay: isRestDay,
              isFinished: isFinished,
              elapsedText: isFinished
                  ? _formatTimer(_elapsedDuration)
                  : (_sessionLeft ? _formatTimer(_elapsedDuration) : null),
              onStartWorkout: () {
                if (isRestDay) {
                  _markRestDay(isRest: false);
                } else if (isFinished) {
                  _reopenWorkout();
                } else if (_sessionLeft && activeExercises.isNotEmpty) {
                  _resumeWorkout();
                } else if (activeExercises.isEmpty) {
                  _openExercisePicker();
                } else if (allRoutines.isNotEmpty || nextWorkoutSug != null) {
                  _applySuggestedRoutine();
                } else {
                  _startWorkout();
                }
              },
              onDiscardWorkout: !isFinished && _sessionLeft && activeExercises.isNotEmpty ? _discardWorkout : null,
              onExplainAI: !isFinished && nextWorkoutSug != null
                  ? () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useRootNavigator: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => SuggestionExplainSheet(
                          suggestion: nextWorkoutSug,
                          onApply: _applySuggestedRoutine,
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: S.xl)),

        // 4. THIS WEEK PROGRESS BAR (Streak / completion dots)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.xl),
            child: ThisWeekProgressBar(
              completedWeekdays: streakData?.completedWeekdays ?? {},
              todayWeekday: DateTime.now().weekday,
              workoutsCount: streakData?.workoutsThisWeek ?? 0,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: S.md)),
        

        // Daily Fuel & Nutrition Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.xl),
            child: ScaleTap(
              onPressed: () {
                AppHaptics.tap();
                context.push('/nutrition');
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: C.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.restaurant_rounded, size: 18, color: C.accent),
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
                                  'Daily Fuel & Nutrition',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: C.text1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI Calibrated →',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: C.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isRestDay
                                ? 'Rest Day Recovery • High Protein • Tissue Repair'
                                : (activeExercises.isNotEmpty
                                    ? 'Calibrated to today\'s session • Log meals & track protein'
                                    : 'Track post-workout protein, macros & hydration'),
                            style: TextStyle(fontSize: 11.5, color: C.text2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: S.lg)),

        // 5. YOUR ROUTINES HEADER
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.xl),
            child: SectionHeader(
              'YOUR ROUTINES',
              action: 'See all',
              onAction: _openRoutines,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: S.md)),

        // 6. YOUR ROUTINES HORIZONTAL CAROUSEL
        SliverToBoxAdapter(
          child: SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: S.xl),
              itemCount: allRoutines.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: S.md),
              itemBuilder: (context, index) {
                if (index < allRoutines.length) {
                  final r = allRoutines[index];
                  final exCount = r.items.length;
                  final estMins = (exCount * 9).clamp(25, 75);
                  return RoutineCard(
                    r.name,
                    '$exCount ex · ~${estMins}m',
                    onTap: () => _confirmApplySpecificRoutine(r),
                  );
                } else {
                  return RoutineCard(
                    'New Preset',
                    'Custom routine',
                    icon: Icons.add_rounded,
                    onTap: _openCreatePreset,
                  );
                }
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: S.xxl)),

        // 7. QUIET UTILITIES ROW (Hairline pills)
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: S.xl),
            child: Row(
              children: [
                _buildQuietPill(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add Exercise',
                  onTap: _openExercisePicker,
                ),
                const SizedBox(width: S.sm),
                _buildQuietPill(
                  icon: Icons.content_paste_rounded,
                  label: 'Paste Import',
                  onTap: _openPasteImporter,
                ),
                const SizedBox(width: S.sm),
                _buildQuietPill(
                  icon: Icons.copy_all_rounded,
                  label: 'Copy Last',
                  onTap: _openCopySession,
                ),
                const SizedBox(width: S.sm),
                _buildQuietPill(
                  icon: Icons.self_improvement_rounded,
                  label: isRestDay ? 'Unmark Rest' : 'Rest Day',
                  onTap: () => _markRestDay(isRest: !isRestDay),
                ),
                const SizedBox(width: S.sm),
                _buildQuietPill(
                  icon: Icons.restaurant_rounded,
                  label: 'Fuel & Food',
                  onTap: () {
                    AppHaptics.tap();
                    context.push('/nutrition');
                  },
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );

    // MODE 2: ACTIVE WORKOUT SCREEN
    Widget activeWorkoutContent = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        // Completed Hero Card if finished
        if (isFinished && _workout?.endedAt != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.xl, vertical: S.sm),
              child: _buildCompletedHeroCard(context, unit),
            ),
          ),

        // 1. Slim Active Workout Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(S.xl, S.sm, S.xl, S.md),
            child: Row(
              children: [
                ScaleTap(
                  onPressed: _leaveSession,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: C.surfaceHi,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: C.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 16, color: C.text2),
                        const SizedBox(width: 4),
                        Text(
                          'Pause',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: C.text2,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: S.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _workout?.title ?? 'Active Workout',
                        style: T.title.copyWith(fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _workout?.startedAt != null
                                  ? C.accent.withValues(alpha: 0.14)
                                  : C.surfaceHi,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _workout?.startedAt != null ? Icons.timer_outlined : Icons.play_circle_outline_rounded,
                                  size: 12,
                                  color: _workout?.startedAt != null ? C.accent : C.text2,
                                ),
                                const SizedBox(width: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _workout?.startedAt != null ? _formatTimer(_elapsedDuration) : 'Ready',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: _workout?.startedAt != null ? C.accent : C.text2,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${activeExercises.length} ex • ${_workout?.totalSetsCount ?? 0} sets',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                color: C.text2,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (_workout?.startedAt == null && !isFinished)
                  ScaleTap(
                    onPressed: _startWorkout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            C.positive,
                            const Color(0xFF10B981),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: C.positive.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 17, color: Colors.black),
                          SizedBox(width: 3),
                          Text(
                            'Start',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ScaleTap(
                    onPressed: isFinished ? _reopenWorkout : _finishWorkout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isFinished ? C.surfaceHi : C.positive,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFinished ? Icons.replay_rounded : Icons.check_circle_rounded,
                            size: 15,
                            color: isFinished ? C.text1 : Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isFinished ? 'Reopen' : 'Finish',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isFinished ? C.text1 : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                ScaleTap(
                  onPressed: _openNotesDialog,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: C.surfaceHi,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: C.hairline),
                    ),
                    child: Icon(Icons.edit_note_rounded, color: C.text2, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Start Callout Banner if session entered but not yet started
        if (_workout?.startedAt == null && !isFinished)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.xl, 0, S.xl, S.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.accent.withValues(alpha: 0.12),
                      const Color(0xFF10B981).withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.accent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow_rounded, size: 18, color: context.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Ready',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            'Tap Start to begin tracking workout time and sets',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ScaleTap(
                      onPressed: _startWorkout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: C.positive,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 16, color: Colors.black),
                            SizedBox(width: 2),
                            Text(
                              'Start',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 2. Active Exercises List
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: S.xl),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = activeExercises[index];
                final exSug = _suggestions.where((s) => s.payload['exerciseId'] == item.exercise.id).firstOrNull;

                return Padding(
                  padding: const EdgeInsets.only(bottom: S.md),
                  child: ExerciseTableCard(
                    key: ValueKey(item.id),
                    item: item,
                    unit: unit,
                    suggestion: exSug,
                    onRefresh: _refreshWorkout,
                    onPrAchieved: (pr) {
                      setState(() => _activePr = pr);
                    },
                    onRemoveExercise: () => _removeExercise(item),
                  ),
                );
              },
              childCount: activeExercises.length,
            ),
          ),
        ),

        // 3. "+ Add Exercise" Button (Renamed from "Movement" to "Exercise")
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.xl, vertical: S.sm),
            child: ScaleTap(
              onPressed: _openExercisePicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(R.button),
                  border: Border.all(color: C.hairline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: C.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add Exercise',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: C.text1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 4. "Finish Workout" Primary CTA at bottom of session
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.xl, vertical: S.xs),
            child: ScaleTap(
              onPressed: _finishWorkout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: C.positive,
                  borderRadius: BorderRadius.circular(R.button),
                  boxShadow: [
                    BoxShadow(
                      color: C.positive.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Finish Workout',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: SizedBox(height: ref.watch(activeWorkoutInputProvider) != null ? 310 : 120),
        ),
      ],
    );

    final hasActiveInput = ref.watch(activeWorkoutInputProvider) != null;

    return PopScope(
      canPop: false, // Today is always a root tab — never pop (would exit the app)
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (ref.read(activeWorkoutInputProvider) != null) {
          ref.read(activeWorkoutInputProvider.notifier).close();
          return;
        }
        if (hasActiveWorkout) {
          // Collapse active session back to the today summary view
          ref.read(activeWorkoutInputProvider.notifier).close();
          AppHaptics.tap();
          setState(() => _sessionLeft = true);
        }
      },
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: hasActiveWorkout
                ? activeWorkoutContent
                : Skeletonizer(
                    enabled: _isLoading,
                    child: homeContent,
                  ),
          ),

          // Floating Rest Timer Dynamic Capsule (glides above numpad when active!)
          if (hasActiveWorkout)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: hasActiveInput ? 280 : 24,
              child: const RestTimerOverlay(),
            ),

          // PR Confetti Celebration Overlay
          if (_activePr != null)
            ConfettiOverlay(
              prResult: _activePr!,
              onDismiss: () => setState(() => _activePr = null),
            ),

          // Docked Fast-Entry Workout Numpad
          if (hasActiveWorkout)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DockedWorkoutNumpad(
                onLogSet: _handleNumpadLogSet,
                onUpdateSet: _handleNumpadUpdateSet,
              ),
            ),
        ],
      ),
    );
  }
}
