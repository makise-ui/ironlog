import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/database.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/workout_repository.dart';
import 'repositories/routine_repository.dart';
import 'repositories/settings_repository.dart';
import '../domain/models/exercise_model.dart';
import '../domain/services/rest_timer_service.dart';
import '../core/utils/unit_converter.dart';

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
