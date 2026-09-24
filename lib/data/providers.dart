import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/database.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/workout_repository.dart';
import 'repositories/routine_repository.dart';
import 'repositories/settings_repository.dart';
import '../domain/models/exercise_model.dart';
import '../domain/models/routine_model.dart';
import '../domain/services/rest_timer_service.dart';
import '../core/utils/unit_converter.dart';
import '../core/utils/date_utils.dart';
import '../core/theme/app_colors.dart';

final selectedWorkoutDateProvider = StateProvider<DateTime>((ref) {
  return AppDateUtils.normalizeDate(DateTime.now());
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(databaseProvider));
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.watch(databaseProvider));
});

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository(ref.watch(databaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

final restTimerProvider = ChangeNotifierProvider<RestTimerService>((ref) {
  return RestTimerService.instance;
});

final muscleGroupsProvider = StreamProvider<List<MuscleGroupModel>>((ref) {
  return ref.watch(exerciseRepositoryProvider).watchMuscleGroups();
});

final routinesProvider = StreamProvider<List<RoutineModel>>((ref) {
  return ref.watch(routineRepositoryProvider).watchRoutines();
});

final weightUnitNotifierProvider = StateNotifierProvider<WeightUnitNotifier, WeightUnit>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return WeightUnitNotifier(repo);
});

class WeightUnitNotifier extends StateNotifier<WeightUnit> {
  final SettingsRepository _repo;

  WeightUnitNotifier(this._repo) : super(WeightUnit.kg) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.getWeightUnit();
  }

  Future<void> toggle() async {
    final next = state == WeightUnit.kg ? WeightUnit.lb : WeightUnit.kg;
    state = next;
    await _repo.setWeightUnit(next);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return ThemeModeNotifier(repo);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsRepository _repo;

  ThemeModeNotifier(this._repo) : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final mode = await _repo.getThemeMode();
    if (mode == 'light') {
      state = ThemeMode.light;
    } else if (mode == 'system') {
      state = ThemeMode.system;
    } else {
      state = ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final modeStr = mode == ThemeMode.light ? 'light' : (mode == ThemeMode.system ? 'system' : 'dark');
    await _repo.setThemeMode(modeStr);
  }
}

final accentPresetProvider = StateNotifierProvider<AccentPresetNotifier, AccentPreset>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return AccentPresetNotifier(repo);
});

class AccentPresetNotifier extends StateNotifier<AccentPreset> {
  final SettingsRepository _repo;

  AccentPresetNotifier(this._repo) : super(AccentPreset.cobalt) {
    _load();
  }

  Future<void> _load() async {
    final presetName = await _repo.getAccentPreset();
    for (final p in AccentPreset.values) {
      if (p.name == presetName) {
        state = p;
        AppColors.currentPreset = p;
        break;
      }
    }
  }

  Future<void> setPreset(AccentPreset preset) async {
    state = preset;
    AppColors.currentPreset = preset;
    await _repo.setAccentPreset(preset.name);
  }
}

final streakAndWeekProvider = FutureProvider<StreakAndWeekData>((ref) async {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.getStreakAndWeekData();
});

final isWorkoutActiveProvider = StateProvider<bool>((ref) => false);

/// Counter provider incremented when the system back button is pressed
/// while an active workout is underway, requesting TodayScreen to minimize/pause it.
final requestCollapseWorkoutProvider = StateProvider<int>((ref) => 0);
