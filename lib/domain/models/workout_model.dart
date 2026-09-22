import 'exercise_model.dart';
import 'set_model.dart';

class WorkoutExerciseItem {
  final String id; // workoutExerciseId
  final String workoutId;
  final ExerciseModel exercise;
  final int position;
  final String? supersetGroup;
  final String? note;
  final List<SetModel> sets;
  final bool archived;

  const WorkoutExerciseItem({
    required this.id,
    required this.workoutId,
    required this.exercise,
    required this.position,
    this.supersetGroup,
    this.note,
    this.sets = const [],
    this.archived = false,
  });

  double get totalVolume {
    return sets
        .where((s) => !s.isWarmup && !s.archived)
        .fold(0.0, (sum, s) => sum + s.volume);
  }

  double get maxWeight {
    final active = sets.where((s) => !s.archived);
    if (active.isEmpty) return 0.0;
    return active.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
  }

  double get maxE1rm {
    final working = sets.where((s) => !s.isWarmup && !s.archived);
    if (working.isEmpty) return 0.0;
    return working.map((s) => s.e1rm).reduce((a, b) => a > b ? a : b);
  }

  int get completedSetsCount => sets.where((s) => !s.archived).length;

  WorkoutExerciseItem copyWith({
    String? id,
    String? workoutId,
    ExerciseModel? exercise,
    int? position,
    String? supersetGroup,
    String? note,
    List<SetModel>? sets,
    bool? archived,
  }) {
    return WorkoutExerciseItem(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exercise: exercise ?? this.exercise,
      position: position ?? this.position,
      supersetGroup: supersetGroup ?? this.supersetGroup,
      note: note ?? this.note,
      sets: sets ?? this.sets,
      archived: archived ?? this.archived,
    );
  }
}

class WorkoutModel {
  final String id;
  final DateTime date;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String title;
  final String? note;
  final int? feel; // 1-5
  final String? routineId;
  final List<WorkoutExerciseItem> exercises;
  final bool archived;

  const WorkoutModel({
    required this.id,
    required this.date,
    this.startedAt,
    this.endedAt,
    required this.title,
    this.note,
    this.feel,
    this.routineId,
    this.exercises = const [],
    this.archived = false,
  });

  double get totalVolume {
    return exercises
        .where((e) => !e.archived)
        .fold(0.0, (sum, e) => sum + e.totalVolume);
  }

  int get totalSetsCount {
    return exercises
        .where((e) => !e.archived)
        .fold(0, (sum, e) => sum + e.completedSetsCount);
  }

  Duration? get duration {
    if (startedAt == null || endedAt == null) return null;
    return endedAt!.difference(startedAt!);
  }

  WorkoutModel copyWith({
    String? id,
    DateTime? date,
    DateTime? startedAt,
    DateTime? endedAt,
    String? title,
    String? note,
    int? feel,
    String? routineId,
    List<WorkoutExerciseItem>? exercises,
    bool? archived,
  }) {
    return WorkoutModel(
      id: id ?? this.id,
      date: date ?? this.date,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      title: title ?? this.title,
      note: note ?? this.note,
      feel: feel ?? this.feel,
      routineId: routineId ?? this.routineId,
      exercises: exercises ?? this.exercises,
      archived: archived ?? this.archived,
    );
  }
}
